"""Known-answer tests for obstruction_to_steps and anchors_from_calibration.
Port of tests/TestObstructionToSteps.m. All step values are FICTIONAL, worked out by hand:
  zeroStep 21000, fullStep 44000, scaleMax 17 (mm):
    8.5 mm -> 21000 + 8.5/17 * 23000 = 32500
    1 mm   -> 21000 + 23000/17 = 22352.94 -> 22353
  scaleMax 100 (percent): 25 % -> 21000 + 0.25 * 23000 = 26750
  scaleMax 18, zeroStep 20000, fullStep 44000:
    12.5 mm -> 20000 + 12.5/18 * 24000 = 36666.67 -> 36667
  anchors: MaxPosition 45123, zeroOffset 24000, fullOffset 1000 -> zeroStep 21123, fullStep 44123
"""
import math

import pytest

from rrst import errors
from rrst.mapping import anchors_from_calibration, obstruction_to_steps


def test_midpoint_mm():
    assert obstruction_to_steps(8.5, 17, 21000, 44000) == 32500


def test_endpoints_mm():
    assert obstruction_to_steps(0, 17, 21000, 44000) == 21000
    assert obstruction_to_steps(17, 17, 21000, 44000) == 44000


def test_rounds_to_nearest_step():
    assert obstruction_to_steps(1, 17, 21000, 44000) == 22353
    assert obstruction_to_steps(12.5, 18, 20000, 44000) == 36667


def test_returns_a_python_int():
    assert type(obstruction_to_steps(8.5, 17, 21000, 44000)) is int


def test_percent_scale():
    assert obstruction_to_steps(25, 100, 21000, 44000) == 26750


def test_above_scale_is_an_error_not_clipped():
    # The original scale2motorstep clipped, which sent the ITI rest (20-80 on a
    # 0-17 mm scale) to full obstruction. Out-of-range input must raise.
    for value in (20, 50):
        with pytest.raises(errors.OutOfRange):
            obstruction_to_steps(value, 17, 21000, 44000)


def test_below_zero_is_an_error():
    with pytest.raises(errors.OutOfRange):
        obstruction_to_steps(-1, 17, 21000, 44000)


@pytest.mark.parametrize("value", [math.nan, math.inf, [1, 2], None, "5"])
def test_non_finite_or_non_scalar_is_an_error(value):
    with pytest.raises(errors.OutOfRange):
        obstruction_to_steps(value, 17, 21000, 44000)


@pytest.mark.parametrize("scale_max, zero, full", [
    (17, 44000, 21000), (17, 21000, 21000), (0, 21000, 44000), (17, math.nan, 44000)])
def test_invalid_map_is_an_error(scale_max, zero, full):
    with pytest.raises(errors.BadMap):
        obstruction_to_steps(5, scale_max, zero, full)


def test_anchors_follow_max_position():
    assert anchors_from_calibration(45123, 24000, 1000) == (21123, 44123)


def test_full_scale_at_endstop_is_allowed():
    assert anchors_from_calibration(45123, 24000, 0)[1] == 45123


@pytest.mark.parametrize("max_pos, zero_off, full_off", [
    (45123, 1000, 24000),   # zero must lie further from the max endstop than full scale
    (45123, 1000, 1000),
    (45123, 50000, 1000),   # zero cannot lie behind the min endstop
    (45123, 24000, -5),
    (math.nan, 24000, 1000)])
def test_invalid_anchors_are_errors(max_pos, zero_off, full_off):
    with pytest.raises(errors.BadAnchors):
        anchors_from_calibration(max_pos, zero_off, full_off)
