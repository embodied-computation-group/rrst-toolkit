"""Parser tests on the firmware transcripts in tests/fixtures (see tests/fixtures/README.md).
Port of tests/TestReplyParsing.m: same fixtures, same expected values."""
import math

import pytest

from conftest import FIXTURES, read_fixture
from rrst import errors
from rrst.replies import parse_calibration_reply, parse_move_reply, parse_status, split_reply


def lines_of(name):
    return split_reply(read_fixture(name))[0]


# --- framing -----------------------------------------------------------------

def test_split_strips_cr_prompt_and_blank_lines():
    lines, complete = split_reply(read_fixture("calibrate_ok.txt"))
    assert complete
    assert lines == [
        "Starting calibration...",
        "Min Endstop found. Position set to 0.",
        "Max Endstop found. Max Position: 45123 (previous saved: 45100, diff: +23)",
        "First-contact position (retract 15.000 mm): 21123",
    ]


def test_reply_without_prompt_is_incomplete():
    lines, complete = split_reply("\nEnter absolute target position (steps):\r\n")
    assert not complete
    assert lines == ["Enter absolute target position (steps):"]


def test_empty_text_is_incomplete_with_no_lines():
    assert split_reply("") == ([], False)


# --- calibration ---------------------------------------------------------------

def test_calibration_success():
    cal = parse_calibration_reply(lines_of("calibrate_ok.txt"))
    assert cal.ok
    assert cal.max_position == 45123
    assert cal.first_contact == 21123
    assert cal.retract_mm == 15
    assert cal.previous_saved == 45100
    assert cal.error_text == ""


def test_calibration_success_without_saved_value():
    cal = parse_calibration_reply(lines_of("calibrate_ok_first.txt"))
    assert cal.ok
    assert cal.max_position == 44987
    assert cal.first_contact == 20987
    assert math.isnan(cal.previous_saved)


def test_calibration_captured_from_device():
    # Real reply from device 2E4441D76D5F2996, 2026-10-28 (no tube fitted).
    lines, complete = split_reply(read_fixture("calibrate_ok__device_2E4441D76D5F2996__2026-10-28.txt"))
    assert complete
    cal = parse_calibration_reply(lines)
    assert cal.ok
    assert cal.max_position == 40079
    assert cal.first_contact == 16079
    assert cal.previous_saved == 39963
    assert cal.retract_mm == 15


def test_enable_captured_from_device():
    lines, complete = split_reply(read_fixture("enable__device_2E4441D76D5F2996__2026-10-28.txt"))
    assert complete
    assert any(line.startswith("Stepper enabled") for line in lines)


def test_calibration_failures():
    cal = parse_calibration_reply(lines_of("calibrate_fail_min.txt"))
    assert not cal.ok
    assert cal.error_text == "ERROR: Min endstop not found - calibration aborted."
    assert math.isnan(cal.max_position)

    cal = parse_calibration_reply(lines_of("calibrate_fail_max.txt"))
    assert not cal.ok
    assert cal.error_text == "ERROR: Max endstop not found - calibration aborted."


def test_calibration_with_error_line_is_not_ok():
    # A success line alongside any ERROR line must not count as success.
    lines = lines_of("calibrate_ok.txt") + [
        "ERROR: Driver fault detected - stepper disabled. (overtemperature shutdown ) "
        "Investigate before re-enabling (e)."
    ]
    assert not parse_calibration_reply(lines).ok


# --- moves -----------------------------------------------------------------------

def test_move_success():
    mv = parse_move_reply(lines_of("move_ok.txt"))
    assert mv.ok
    assert mv.target == 32500
    assert mv.warnings == []
    assert mv.error_text == ""


def test_move_success_keeps_warnings():
    mv = parse_move_reply(lines_of("move_ok_with_warning.txt"))
    assert mv.ok
    assert mv.warnings == ["WARNING: Unexpected MAX endstop hit! Position auto-corrected to 45123."]


def test_move_refusals():
    mv = parse_move_reply(lines_of("move_out_of_bounds.txt"))
    assert not mv.ok
    assert mv.error_text == "Error: Target out of calibrated bounds!"
    assert math.isnan(mv.target)

    mv = parse_move_reply(lines_of("move_not_calibrated.txt"))
    assert not mv.ok
    assert mv.error_text == "Error: Must calibrate ('c') before moving."


def test_move_safety_disable():
    mv = parse_move_reply(lines_of("move_safety_disable.txt"))
    assert not mv.ok
    assert len(mv.warnings) == 3
    assert mv.error_text.startswith("ERROR: Repeated unexpected endstop hits")


def test_move_without_completion_is_not_ok():
    # The connection-lost path prints no ERROR line, so only the missing
    # "Move complete." shows the move did not finish.
    mv = parse_move_reply(lines_of("move_connection_lost.txt"))
    assert not mv.ok
    assert mv.target == 32500
    assert mv.error_text != ""


# --- status ----------------------------------------------------------------------

def test_status_calibrated():
    st = parse_status(lines_of("status_calibrated.txt"))
    assert st.software_version == "Patient-Regulator (Oct  7 2026 08:45:06)"
    assert st.device_id == "0123456789ABCDEF"
    assert st.stepper_enabled
    assert st.calibrated
    assert st.current_position == 32500
    assert st.max_position == 45123
    assert st.first_contact == 21123
    assert st.retract_steps == 24000
    assert st.retract_mm == 15
    assert st.speed == 16000
    assert st.acceleration == 10000
    assert st.run_current == 800
    assert st.hold_percent == 50
    assert st.microsteps == 16
    assert st.chopper_mode == "SpreadCycle"


def test_status_uncalibrated_does_not_trust_stale_max():
    st = parse_status(lines_of("status_uncalibrated.txt"))
    assert not st.calibrated
    assert not st.stepper_enabled
    assert math.isnan(st.max_position)
    assert math.isnan(st.first_contact)
    assert st.current_position == 20000


def test_status_captured_from_vigilant_piston():
    # Real reply from the first 2.0 unit at the bench, 2026-10-28 (no device ID line).
    st = parse_status(lines_of("status_uncalibrated__fw_Vigilant-Piston__2026-10-28.txt"))
    assert st.software_version == "Vigilant-Piston (Oct  1 2026 11:30:50)"
    assert st.device_id == ""
    assert not st.calibrated
    assert not st.stepper_enabled
    assert st.current_position == 0
    assert math.isnan(st.max_position)
    assert math.isnan(st.first_contact)
    assert st.retract_steps == 24000
    assert st.acceleration == 10000
    assert st.run_current == 795
    assert st.chopper_mode == "SpreadCycle"


def test_status_captured_after_flash():
    # Same unit after flashing Patient-Regulator, 2026-10-28: settings and saved max kept.
    st = parse_status(lines_of("status_uncalibrated__device_2E4441D76D5F2996__2026-10-28.txt"))
    assert st.software_version == "Patient-Regulator (Oct  7 2026 08:45:06)"
    assert st.device_id == "2E4441D76D5F2996"
    assert not st.calibrated
    assert math.isnan(st.max_position)
    assert st.run_current == 795


def test_status_without_header_is_an_error():
    with pytest.raises(errors.BadStatus):
        parse_status(["Move complete."])


def test_status_raw_bytes_capture_decodes_as_utf8():
    # Byte-exact capture (pyserial, no re-encoding), device 2E4441D76D5F2996, 2026-10-28.
    # The firmware sends "²" as UTF-8 (C2 B2).
    raw = (FIXTURES / "status_uncalibrated_raw_bytes__device_2E4441D76D5F2996__2026-10-28.txt").read_bytes()
    assert b"steps/s\xc2\xb2" in raw
    lines, complete = split_reply(raw.decode("utf-8"))
    assert complete
    st = parse_status(lines)
    assert st.device_id == "2E4441D76D5F2996"
    assert not st.calibrated
    assert st.acceleration == 10000
    assert st.fields["SavedMaxPos"] == "41296 steps"
    assert st.fields["MinEndstop"] == "ok"


def test_status_reports_git_commit():
    # Precise-Piston (Msnejbjerg/RRST 766809f on) prints "Git Commit:" after the version.
    st = parse_status(lines_of("status_calibrated__fw_Precise-Piston.txt"))
    assert st.software_version == "Precise-Piston (Oct 28 2026 12:07:57)"
    assert st.git_commit == "aa8dd72"
    assert st.retract_steps == 25600
    assert st.first_contact == 19523
    assert st.chopper_mode == "StealthChop"


def test_status_without_git_commit_line_gives_empty():
    assert parse_status(lines_of("status_calibrated.txt")).git_commit == ""
