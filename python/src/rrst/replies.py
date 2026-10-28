"""Framing and parsing of the firmware's replies. Port of rrst.splitReply,
rrst.parseCalibrationReply, rrst.parseMoveReply and rrst.parseStatus."""
import math
import re
from dataclasses import dataclass, field

from . import errors

PROMPT = "Valve>"


def split_reply(text):
    """Split raw firmware output into lines and detect the command prompt.

    The firmware ends every reply with giveCmdPrompt(): CRLF, then "Valve>" with no
    line terminator. Returns (lines, complete): complete is True when the text ends
    with the prompt; lines have carriage returns, blank lines and the prompt removed.
    """
    if not text:
        return [], False
    trimmed = text.rstrip()
    complete = trimmed.endswith(PROMPT)
    if complete:
        trimmed = trimmed[: -len(PROMPT)]
    lines = [line.rstrip() for line in trimmed.replace("\r", "").split("\n")]
    return [line for line in lines if line], complete


def _errors(lines):
    return [line for line in lines if line.lower().startswith("error")]


def _first_match(pattern, lines):
    for line in lines:
        m = re.match(pattern, line)
        if m:
            return m
    return None


@dataclass
class CalibrationReply:
    ok: bool = False
    max_position: float = math.nan
    first_contact: float = math.nan
    retract_mm: float = math.nan
    previous_saved: float = math.nan
    error_text: str = ""


def parse_calibration_reply(lines):
    """ok only when the max endstop and first-contact lines are present and no line
    starts with ERROR. Positions are NaN unless ok."""
    cal = CalibrationReply()
    m = _first_match(r"Max Endstop found\. Max Position: (-?\d+)", lines)
    if m:
        cal.max_position = int(m.group(1))
        prev = re.search(r"previous saved: (-?\d+)", m.string)
        if prev:
            cal.previous_saved = int(prev.group(1))
    m = _first_match(r"First-contact position \(retract ([\d.]+) mm\): (-?\d+)", lines)
    if m:
        cal.retract_mm = float(m.group(1))
        cal.first_contact = int(m.group(2))

    errs = _errors(lines)
    if errs:
        cal.error_text = errs[0]
    elif math.isnan(cal.max_position) or math.isnan(cal.first_contact):
        cal.error_text = "No 'Max Endstop found' / 'First-contact position' line in the reply."
    else:
        cal.ok = True
    if not cal.ok:
        cal.max_position = cal.first_contact = math.nan
    return cal


@dataclass
class MoveReply:
    ok: bool = False
    target: float = math.nan
    warnings: list = field(default_factory=list)
    error_text: str = ""
    requested: float = math.nan
    elapsed: float = math.nan


def parse_move_reply(lines):
    """ok only when "Move complete." is present and no line starts with Error/ERROR.
    WARNING lines are kept even on success."""
    mv = MoveReply()
    mv.warnings = [line for line in lines if line.lower().startswith("warning")]
    m = _first_match(r"Moving to absolute position: (-?\d+)", lines)
    if m:
        mv.target = int(m.group(1))
    errs = _errors(lines)
    if errs:
        mv.error_text = errs[-1]
    elif "Move complete." not in lines:
        mv.error_text = "No 'Move complete.' line in the reply."
    else:
        mv.ok = True
    return mv


@dataclass
class Status:
    fields: dict
    software_version: str
    git_commit: str          # "" before Precise-Piston; "-dirty"/"unknown" possible
    device_id: str
    stepper_enabled: bool
    calibrated: bool
    current_position: float
    max_position: float
    first_contact: float
    retract_steps: float
    retract_mm: float
    speed: float
    acceleration: float
    run_current: float
    hold_percent: float
    microsteps: float
    chopper_mode: str


def _leading_number(s):
    m = re.match(r"(-?\d+(\.\d+)?)", s)
    if not m:
        return math.nan
    return float(m.group(1)) if m.group(2) else int(m.group(1))


def _valid_name(key):
    """MATLAB's makeValidName: drop whitespace, capitalising the next letter, and
    replace any other invalid character with "_"."""
    key = re.sub(r"\s+(\w)", lambda m: m.group(1).upper(), key.strip())
    return re.sub(r"\W", "_", key)


def parse_status(lines):
    """Typed fields for the values the task relies on, plus every "Key: value" line in
    .fields (keys as MATLAB's makeValidName gives them, e.g. "First_Contact").
    max_position and first_contact are NaN unless the device reports itself
    calibrated: an uncalibrated device still prints a stale value, which must not be
    used."""
    if "--- SYSTEM STATUS ---" not in lines:
        raise errors.BadStatus('Reply does not contain a "--- SYSTEM STATUS ---" block.')
    raw = {}
    for line in lines:
        m = re.match(r"([^:]+):\s*(.*)$", line)
        if m:
            raw[_valid_name(m.group(1))] = m.group(2).strip()

    def text(name):
        return raw.get(name, "")

    calibrated = text("Calibrated") == "YES"
    retract = re.match(r"(\d+) steps \(([\d.]+) mm\)", text("RetractDistance"))
    return Status(
        fields=raw,
        software_version=text("SoftwareVersion"),
        git_commit=text("GitCommit"),
        device_id=text("DeviceID"),
        stepper_enabled=text("StepperEnabled") == "YES",
        calibrated=calibrated,
        current_position=_leading_number(text("CurrentPosition")),
        max_position=_leading_number(text("MaxRangeLimit")) if calibrated else math.nan,
        first_contact=_leading_number(text("First_Contact")) if calibrated else math.nan,
        retract_steps=int(retract.group(1)) if retract else math.nan,
        retract_mm=float(retract.group(2)) if retract else math.nan,
        speed=_leading_number(text("CurrentSpeed")),
        acceleration=_leading_number(text("Acceleration")),
        run_current=_leading_number(text("RunCurrent")),
        hold_percent=_leading_number(text("HoldCurrent")),
        microsteps=_leading_number(text("Microsteps")),
        chopper_mode=text("ChopperMode"),
    )
