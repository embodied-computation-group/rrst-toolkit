"""Stimulus levels -> confirmed device moves, for the task. Port of rrst.Stimulator.

    stim = Stimulator(device, record, unit="percent", rest_range=(20, 80))
    stim.calibrate()           # motion settings, 'c' + 'e', checked against the record
    stim.present(level)        # move to a stimulus level
    stim.null()                # level 0: wedge just touching the tube
    level, mv = stim.rest()    # random level in rest_range (between trials)
    stim.park()                # wedge well open, at park_step

Levels are in unit: "percent" (0-100 between the record's anchors) or "mm" (wedge
travel past the zero anchor, steps_per_mm steps per mm). A level outside
[0, scale_max] is an error, never clipped. Every move waits for the firmware's
confirmation (Device.move_to) and is logged with its duration.

motion={"speed": s, "acceleration": a, "chopperMode": m} makes every calibrate() set
and check these first (Device.apply_motion), so a session never runs on whatever tuning
the device loaded from EEPROM. None (default): the device's settings are left alone and
only logged.
"""
import dataclasses
import math
import time

import numpy as np

from . import errors
from .mapping import anchors_from_calibration, obstruction_to_steps


class Stimulator:
    def __init__(self, device, record, unit="percent", rest_range=(20, 80), park_step=1600,
                 calibration_tolerance=300, steps_per_mm=1600, seed=None, motion=None,
                 clock=time.monotonic):
        if unit not in ("percent", "mm"):
            raise ValueError(f'unit must be "percent" or "mm", got {unit!r}')
        if not (len(rest_range) == 2 and rest_range[0] <= rest_range[1]):
            raise ValueError(f"rest_range must be (low, high) with low <= high, got {rest_range!r}")
        self.device = device
        self.record = record
        self.unit = unit
        self.park_step = park_step                     # 1 mm from the min endstop: wedge well open
        self.calibration_tolerance = calibration_tolerance   # steps; tube in/out is about 1150
        self.steps_per_mm = steps_per_mm               # TR8x2 leadscrew, 1.8 deg motor, 16 microsteps
        self.motion = motion
        self.device_status = None                      # 's' read at the last calibration, after motion
        a = record["anchors"]
        self.scale_max = 100 if unit == "percent" else (a["zeroOffset"] - a["fullOffset"]) / steps_per_mm
        self.rest_range = tuple(rest_range)
        self.validate_levels(self.rest_range)
        self.zero_step = math.nan
        self.full_step = math.nan
        self.calibrations = []
        self.log = []
        self._rng = np.random.default_rng(seed)
        self._clock = clock
        self._t0 = clock()

    def validate_levels(self, levels):
        """Raise LevelOutOfRange unless every level is inside [0, scale_max]."""
        levels = np.atleast_1d(np.asarray(levels, dtype=float))
        bad = levels[~((levels >= 0) & (levels <= self.scale_max))]
        if bad.size:
            raise errors.LevelOutOfRange(
                f"Levels outside this device's scale [0, {self.scale_max:g}] {self.unit}: "
                f"{np.round(bad, 4).tolist()}. Change the configuration; levels are never clipped.")

    def calibrate(self):
        """Motion settings, 'c' then 'e'; checks device ID and MaxPosition against the record."""
        st = self.device.status()
        if st.device_id != self.record["deviceId"]:
            raise errors.WrongDevice(
                f"Connected device is {st.device_id}, but the record is for {self.record['deviceId']}.")
        if self.motion is not None:
            st = self.device.apply_motion(self.motion, st)
        self.device_status = _status_record(st)
        self.zero_step = self.full_step = math.nan
        cal = self.device.calibrate()
        self.device.enable()
        a = self.record["anchors"]
        d = cal.max_position - a["maxPositionAtMeasurement"]
        if abs(d) > self.calibration_tolerance:
            raise errors.CalibrationMismatch(
                f"MaxPosition {cal.max_position} is {d:+d} steps from the "
                f"{a['maxPositionAtMeasurement']} measured with the anchors (tolerance "
                f"{self.calibration_tolerance}). Calibrate in the same condition as the record "
                f"({a.get('calibrationCondition', 'unknown')}) and check the tube is seated.")
        self.zero_step, self.full_step = anchors_from_calibration(
            cal.max_position, a["zeroOffset"], a["fullOffset"])
        self.calibrations.append({"t": self._now(), "maxPosition": cal.max_position,
                                  "zeroStep": self.zero_step, "fullStep": self.full_step})
        return cal

    def level_to_steps(self, level):
        if math.isnan(self.zero_step):
            raise errors.NotCalibrated("Calibrate before converting levels to steps.")
        return obstruction_to_steps(level, self.scale_max, self.zero_step, self.full_step)

    def present(self, level, kind="stim"):
        steps = self.level_to_steps(level)
        mv = self.device.move_to(steps)
        self._add_log(kind, level, steps, mv.elapsed)
        return mv

    def null(self):
        return self.present(0, "null")

    def rest(self):
        lo, hi = self.rest_range
        level = float(lo + (hi - lo) * self._rng.random())
        return level, self.present(level, "rest")

    def park(self):
        mv = self.device.move_to(self.park_step)
        self._add_log("park", math.nan, self.park_step, mv.elapsed)
        return mv

    def summary(self):
        """Everything needed to audit the session, for saving with the data."""
        return {"deviceId": self.record["deviceId"], "record": self.record, "unit": self.unit,
                "scaleMax": self.scale_max, "restRange": list(self.rest_range),
                "parkStep": self.park_step, "motion": self.motion,
                "deviceStatus": self.device_status, "calibrations": self.calibrations,
                "moves": self.log, "transcript": self.device.transcript}

    def _now(self):
        return self._clock() - self._t0

    def _add_log(self, kind, level, steps, elapsed):
        self.log.append({"t": self._now(), "kind": kind, "level": level, "steps": steps, "elapsed": elapsed})


def _status_record(st):
    """The parsed status without its raw fields, keyed as in the MATLAB summary (camelCase)."""
    d = dataclasses.asdict(st)
    d.pop("fields")
    return {k.split("_")[0] + "".join(w.title() for w in k.split("_")[1:]): v for k, v in d.items()}
