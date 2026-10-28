"""Stimulator: stimulus levels -> checked device moves, using a device record.
Port of tests/TestStimulator.m. Known answers use the fictional mock record
(devices/0123456789ABCDEF.json): MaxPosition 45000, zeroOffset 25600, fullOffset 800
  -> zeroStep 19400, fullStep 44200, range 24800 steps = 15.5 mm."""
import json

import numpy as np
import pytest

from rrst import errors
from rrst.device import Device
from rrst.mock import MockPort
from rrst.records import load_device_record
from rrst.stimulator import Stimulator

MOCK_ID = "0123456789ABCDEF"


def make(devices_dir, max_position=45000, unit="percent", rest_range=(20, 80), record=None):
    port = MockPort(max_position=max_position)
    rec = record or load_device_record(MOCK_ID, devices_dir)
    return port, Stimulator(Device(port), rec, unit=unit, rest_range=rest_range, seed=1)


def test_calibration_sets_anchors_from_record(devices_dir):
    port, stim = make(devices_dir)
    stim.calibrate()
    assert stim.zero_step == 19400
    assert stim.full_step == 44200
    assert port.enabled                      # 'e' sent after 'c'


def test_percent_levels_map_linearly(devices_dir):
    _, stim = make(devices_dir)
    stim.calibrate()
    assert stim.level_to_steps(0) == 19400
    assert stim.level_to_steps(100) == 44200
    assert stim.level_to_steps(50) == 31800
    assert stim.level_to_steps(25) == 25600


def test_mm_levels_are_1600_steps_per_mm(devices_dir):
    _, stim = make(devices_dir, unit="mm", rest_range=(2, 10))
    assert stim.scale_max == 15.5
    stim.calibrate()
    assert stim.level_to_steps(1) == 19400 + 1600
    assert stim.level_to_steps(15.5) == 44200


def test_levels_beyond_scale_are_errors_not_clipped(devices_dir):
    _, stim = make(devices_dir)
    stim.calibrate()
    for level in (100.5, -1):
        with pytest.raises(errors.OutOfRange):
            stim.level_to_steps(level)


def test_grid_beyond_device_range_is_rejected_up_front(devices_dir):
    _, stim = make(devices_dir, unit="mm", rest_range=(2, 10))
    with pytest.raises(errors.LevelOutOfRange):
        stim.validate_levels(np.linspace(0, 17, 36))
    stim.validate_levels(np.linspace(0, 15.5, 32))   # fits: no error


def test_rest_range_outside_scale_is_rejected(devices_dir):
    with pytest.raises(errors.LevelOutOfRange):
        make(devices_dir, rest_range=(20, 120))


def test_moving_before_calibration_is_an_error(devices_dir):
    _, stim = make(devices_dir)
    with pytest.raises(errors.NotCalibrated):
        stim.present(50)


def test_present_moves_and_logs(devices_dir):
    port, stim = make(devices_dir)
    stim.calibrate()
    stim.present(50)
    assert port.position == 31800
    stim.null()
    assert port.position == 19400
    assert [m["steps"] for m in stim.log] == [31800, 19400]
    assert [m["kind"] for m in stim.log] == ["stim", "null"]
    assert [m["level"] for m in stim.log] == [50, 0]


def test_rest_stays_inside_rest_range(devices_dir):
    port, stim = make(devices_dir)
    stim.calibrate()
    for _ in range(20):
        level, _ = stim.rest()
        assert 20 <= level <= 80
        assert port.position == stim.level_to_steps(level)


def test_park_goes_to_park_step_open(devices_dir):
    port, stim = make(devices_dir)
    stim.calibrate()
    stim.present(80)
    stim.park()
    assert port.position == 1600
    assert stim.log[-1]["kind"] == "park"


def test_calibration_far_from_record_is_an_error(devices_dir):
    # Tube condition differs from the record: MaxPosition about 1150 steps off.
    _, stim = make(devices_dir, max_position=43850)
    with pytest.raises(errors.CalibrationMismatch):
        stim.calibrate()


def test_calibration_within_tolerance_is_accepted(devices_dir):
    _, stim = make(devices_dir, max_position=45076)
    stim.calibrate()
    assert stim.zero_step == 45076 - 25600
    assert len(stim.calibrations) == 1


def test_wrong_device_record_is_rejected(devices_dir):
    rec = load_device_record(MOCK_ID, devices_dir)
    rec["deviceId"] = "FFFFFFFFFFFFFFFF"
    _, stim = make(devices_dir, record=rec)
    with pytest.raises(errors.WrongDevice):
        stim.calibrate()


def test_summary_keeps_everything_needed_to_audit(devices_dir):
    _, stim = make(devices_dir)
    stim.calibrate()
    stim.present(10)
    sm = stim.summary()
    assert sm["deviceId"] == MOCK_ID
    assert sm["unit"] == "percent"
    assert len(sm["moves"]) == 1
    assert len(sm["calibrations"]) == 1
    assert sm["transcript"]


def test_calibration_without_motion_leaves_settings_alone(devices_dir):
    port, stim = make(devices_dir)
    stim.calibrate()
    assert port.written == ["s", "c", "e"]


def test_calibration_applies_motion_before_c(devices_dir):
    port = MockPort(max_position=45000, chopper_mode="SpreadCycle")
    motion = {"speed": 16000, "acceleration": 20000, "chopperMode": "StealthChop"}
    stim = Stimulator(Device(port), load_device_record(MOCK_ID, devices_dir), motion=motion, seed=1)
    stim.calibrate()
    assert port.written == ["s", "g", "20000", "t", "s", "c", "e"]
    s = stim.summary()
    assert s["motion"] == motion
    assert s["deviceStatus"]["chopperMode"] == "StealthChop"


def test_summary_records_firmware_identity(devices_dir):
    port, stim = make(devices_dir)
    port.git_commit = "aa8dd72"
    stim.calibrate()
    s = stim.summary()
    assert s["deviceStatus"]["gitCommit"] == "aa8dd72"
    assert s["deviceStatus"]["softwareVersion"] == port.software_version
    json.dumps(s)
