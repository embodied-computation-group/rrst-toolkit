"""Device driven against MockPort (a simulated firmware). No hardware.
Port of tests/TestDevice.m."""
import math
import time

import pytest

from conftest import read_fixture
from rrst import errors
from rrst.device import Device
from rrst.mock import MockPort


def drain(port):
    return port.read(port.in_waiting).decode("utf-8")


def calibrated(**kw):
    port = MockPort(max_position=45123, **kw)
    dev = Device(port)
    dev.calibrate()
    return port, dev


# --- the simulator matches the constructed transcripts ---------------------------

def test_mock_calibrate_matches_fixture():
    port = MockPort(max_position=45123, saved_max_position=45100)
    port.write(b"c\n")
    assert drain(port) == read_fixture("calibrate_ok.txt")


def test_mock_move_matches_fixture():
    port = MockPort(max_position=45123)
    port.write(b"c\n")
    drain(port)
    port.write(b"a\n")
    port.write(b"32500\n")
    assert drain(port) == read_fixture("move_ok.txt")



# --- normal session ----------------------------------------------------------------

def test_calibrate_enable_move():
    port = MockPort(max_position=45123)
    dev = Device(port)
    cal = dev.calibrate()
    assert cal.max_position == 45123
    assert dev.max_position == 45123
    assert dev.first_contact == 21123
    dev.enable()
    mv = dev.move_to(32500)
    assert mv.ok
    assert mv.target == 32500
    assert port.position == 32500
    assert port.written == ["c", "e", "a", "32500"]


def test_status_is_parsed():
    dev = Device(MockPort(max_position=45123, device_id="00AA11BB22CC33DD"))
    st = dev.status()
    assert st.device_id == "00AA11BB22CC33DD"
    assert not st.calibrated


def test_transcript_records_both_directions():
    _, dev = calibrated()
    assert [e["direction"] for e in dev.transcript] == ["tx", "rx"]
    assert dev.transcript[0]["text"] == "c"
    assert "Max Endstop found" in dev.transcript[1]["text"]


# --- refusals before anything is sent ----------------------------------------------

def test_move_before_calibration_sends_nothing():
    port = MockPort(max_position=45123)
    dev = Device(port)
    with pytest.raises(errors.NotCalibrated):
        dev.move_to(32500)
    assert port.written == []


@pytest.mark.parametrize("target", [45124, -1, 100.5, math.nan, True])
def test_move_outside_calibrated_range_sends_nothing(target):
    port, dev = calibrated()
    with pytest.raises(errors.OutOfRange):
        dev.move_to(target)
    assert port.written == ["c"]


# --- firmware-reported failures ----------------------------------------------------

def test_calibration_failure_raises():
    dev = Device(MockPort(max_position=45123, fault="calibrateMinMissing"))
    with pytest.raises(errors.CalibrationFailed):
        dev.calibrate()
    assert not dev.calibrated
    assert math.isnan(dev.max_position)


def test_calibration_without_dtr_raises_with_hint():
    dev = Device(MockPort(max_position=45123, dtr=False))
    with pytest.raises(errors.CalibrationFailed, match="DTR"):
        dev.calibrate()


def test_firmware_safety_disable_raises():
    port, dev = calibrated()
    port.fault = "moveSafetyDisable"
    with pytest.raises(errors.MoveFailed):
        dev.move_to(32500)


def test_connection_lost_mid_move_raises():
    port, dev = calibrated()
    port.dtr = False
    with pytest.raises(errors.MoveFailed):
        dev.move_to(32500)
    assert not dev.calibrated


def test_auto_corrected_hit_succeeds_with_warning():
    port, dev = calibrated()
    port.fault = "moveWarning"
    mv = dev.move_to(32500)
    assert mv.ok
    assert len(mv.warnings) == 1


def test_no_reply_times_out():
    port, dev = calibrated()
    port.fault = "silent"
    t0 = time.monotonic()
    with pytest.raises(errors.Timeout):
        dev.move_to(32500, timeout=0.3)
    assert time.monotonic() - t0 < 2


def test_reply_arriving_in_pieces_is_framed_on_the_prompt():
    # A real port delivers bytes in chunks; the reply is complete only at "Valve>".
    port, dev = calibrated()
    port.chunk_size = 7
    assert dev.move_to(32500).ok


def test_multibyte_character_split_across_reads_is_decoded():
    # The status block contains "²" (2 bytes in UTF-8); a read may split it.
    port = MockPort(max_position=45123, chunk_size=1)
    assert Device(port).status().acceleration == 10000


# --- unsolicited output --------------------------------------------------------------

def test_unsolicited_driver_fault_stops_next_command():
    port, dev = calibrated()
    port.queue_unsolicited("\nERROR: Driver fault detected - stepper disabled. "
                           "(overtemperature shutdown ) Investigate before re-enabling (e).\r\n")
    n_before = len(port.written)
    with pytest.raises(errors.DeviceFault):
        dev.move_to(32500)
    assert len(port.written) == n_before          # the move was not sent
    assert any(e["direction"] == "unsolicited" for e in dev.transcript)


def test_unsolicited_non_error_text_is_logged_not_fatal():
    port, dev = calibrated()
    port.queue_unsolicited("\r\nValve>")           # e.g. a stray prompt
    assert dev.move_to(32500).ok
    assert any(e["direction"] == "unsolicited" for e in dev.transcript)


# --- motion settings (speed, acceleration, chopper mode) -------------------------

MOTION = {"speed": 16000, "acceleration": 10000, "chopperMode": "SpreadCycle"}


def test_mock_speed_matches_fixture():
    port = MockPort()
    port.write(b"f\n12000\n")
    assert drain(port) == read_fixture("speed_set.txt")


def test_mock_acceleration_matches_fixture():
    port = MockPort()
    port.write(b"g\n20000\n")
    assert drain(port) == read_fixture("acceleration_set.txt")


def test_mock_chopper_toggle_matches_fixture():
    port = MockPort(chopper_mode="SpreadCycle")
    port.write(b"t\n")
    assert drain(port) == read_fixture("chopper_toggle_to_stealthchop.txt")


def test_calibration_failure_disables_the_driver():
    # A failed 'c' leaves the driver energised; the toolkit sends 'd' before raising.
    port = MockPort(max_position=45123, fault="calibrateMinMissing")
    dev = Device(port)
    with pytest.raises(errors.CalibrationFailed):
        dev.calibrate()
    assert port.written == ["c", "d"]
    assert not port.enabled and not dev.enabled


def test_apply_motion_sends_only_what_differs_and_never_saves():
    port = MockPort(speed=16000, acceleration=10000, chopper_mode="SpreadCycle")
    st = Device(port).apply_motion({"speed": 16000, "acceleration": 20000, "chopperMode": "StealthChop"})
    assert port.written == ["s", "g", "20000", "t", "s"]          # no 'f', no 'v'
    assert (port.speed, port.acceleration, port.chopper_mode) == (16000, 20000, "StealthChop")
    assert (st.acceleration, st.chopper_mode) == (20000, "StealthChop")


def test_apply_motion_already_matching_only_reads_status():
    port = MockPort()
    Device(port).apply_motion(MOTION)
    assert port.written == ["s"]


def test_apply_motion_sets_speed():
    port = MockPort(speed=16000)
    Device(port).apply_motion({**MOTION, "speed": 12000})
    assert port.written == ["s", "f", "12000", "s"]
    assert port.speed == 12000


@pytest.mark.parametrize("bad", [
    {**MOTION, "speed": 0}, {**MOTION, "acceleration": 1.5}, {**MOTION, "speed": True},
    {**MOTION, "chopperMode": "Silent"}, {k: v for k, v in MOTION.items() if k != "speed"},
])
def test_invalid_motion_sends_nothing(bad):
    port = MockPort()
    with pytest.raises(errors.BadSetting):
        Device(port).apply_motion(bad)
    assert port.written == []


def test_unconfirmed_setting_raises():
    port = MockPort(fault="settingIgnored")
    with pytest.raises(errors.SettingFailed):
        Device(port).apply_motion({**MOTION, "speed": 12000})


def test_chopper_toggle_with_driver_link_down_raises():
    port = MockPort(chopper_mode="SpreadCycle", fault="uartDown")
    with pytest.raises(errors.SettingFailed):
        Device(port).apply_motion({**MOTION, "chopperMode": "StealthChop"})
