"""Obstruction levels <-> motor steps. Port of rrst.obstructionToSteps and
rrst.anchorsFromCalibration."""
import math
from numbers import Real

from . import errors


def _finite(x):
    return isinstance(x, Real) and not isinstance(x, bool) and math.isfinite(x)


def obstruction_to_steps(value, scale_max, zero_step, full_step):
    """Map an obstruction value in [0, scale_max] (mm or percent) linearly onto the
    step positions of the 0 anchor (wedge just touching the tube) and the full-scale
    anchor (barely possible to inhale), rounded to the nearest step.

    A value outside [0, scale_max] raises OutOfRange instead of being clipped: the
    original scale2motorstep clipped silently, which sent the ITI rest (20-80 on a
    0-17 mm scale) to full obstruction.
    """
    if not (_finite(scale_max) and scale_max > 0 and _finite(zero_step) and _finite(full_step)
            and zero_step < full_step):
        raise errors.BadMap(
            f"Invalid step map: need scale_max > 0 and finite zero_step < full_step "
            f"(got {scale_max}, {zero_step}, {full_step}).")
    if not (_finite(value) and 0 <= value <= scale_max):
        raise errors.OutOfRange(
            f"Obstruction value must be a finite scalar in [0, {scale_max}]; got {value!r}.")
    # MATLAB round(): halves away from zero (Python's round() goes to even).
    return int(math.floor(zero_step + (value / scale_max) * (full_step - zero_step) + 0.5))


def anchors_from_calibration(max_position, zero_offset, full_offset):
    """Step positions (zero_step, full_step) of the stimulus anchors for this
    calibration. The offsets are measured once per device at the bench and stored
    relative to the max endstop, so the anchors stay at the same physical place when
    MaxPosition drifts between calibrations."""
    if not (_finite(max_position) and max_position > 0 and _finite(zero_offset)
            and _finite(full_offset) and 0 <= full_offset < zero_offset <= max_position):
        raise errors.BadAnchors(
            f"Invalid anchors: need 0 <= full_offset < zero_offset <= max_position "
            f"(got max_position {max_position}, zero_offset {zero_offset}, full_offset {full_offset}).")
    return max_position - zero_offset, max_position - full_offset
