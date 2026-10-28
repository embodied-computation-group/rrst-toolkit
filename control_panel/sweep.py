"""Speed/acceleration limit sweep test: drives the device's existing
serial CLI (f, g, i, t, c, a, e) to empirically find the max reliable
speed and acceleration for a matrix of run currents x chopper modes.
Calibration always runs at the firmware's fixed, dedicated homing
speed now (see the fixed-homing-speed design spec), so it's no longer
useful as a stress test on its own - each candidate speed/acceleration
is instead exercised by a real move-then-verify cycle: a round-trip
absolute move at the candidate value, then one calibration compared
against a baseline established once per combo."""

import re
import time

DEFAULT_TOLERANCE_STEPS = 20
CONFIRMATION_TIMEOUT_S = 3.0
# Only needs to cover incidental serial/processing latency - the
# actual worst-case motion time is computed explicitly in
# calibration_timeout()/move_timeout() below, not folded into this
# constant.
CALIBRATION_TIMEOUT_MARGIN_S = 5.0
MOVE_TIMEOUT_MARGIN_S = 3.0
# SeekEndstopPrecise's fast-approach phase searches up to this many steps
# per endstop before giving up - the worst-case bound a calibration wait
# has to cover.
CALIBRATION_SEARCH_STEPS = 100000

# Mirrors the firmware's monitored-endstop-backoff and fixed-homing-speed
# constants (see RRST_Teensy_4_version_TMC2209.ino and those design
# specs) - the worst case a calibration wait has to cover per endstop
# seek isn't just the fast-approach search above, it's also the
# back-off (which can run all the way to this safety cap before finding
# release) and the slow re-approach traveling back that same worst-case
# distance plus the overtravel margin. Calibration always runs at the
# fixed HomingSpeed/HomingSlowSpeed now rather than whatever's being
# swept, so this is a single computed constant, not a per-call function
# of a swept speed. Assumes the firmware's default 16-microstep
# setting: the sweep test doesn't itself change microsteps, so this
# doesn't need to track a live value, but would need updating here if
# that default ever changes.
FIRMWARE_DEFAULT_MICROSTEPS = 16
FIRMWARE_STEPS_PER_MM = 100 * FIRMWARE_DEFAULT_MICROSTEPS
FIRMWARE_HOMING_BACKOFF_MAX_DISTANCE_MM = 10.0
FIRMWARE_HOMING_BACKOFF_MAX_STEPS = int(FIRMWARE_HOMING_BACKOFF_MAX_DISTANCE_MM * FIRMWARE_STEPS_PER_MM)
FIRMWARE_HOMING_OVERTRAVEL_MARGIN_STEPS = 200
FIRMWARE_HOMING_SPEED = 8000
FIRMWARE_HOMING_SLOW_SPEED = 1000

# Sweep-specific safety margin for the round-trip test move's near-endstop
# targets - deliberately much smaller than the calibration-only
# RetractDistanceMm (16mm default / 25600 steps). That margin is sized for
# calibration's own purposes, not for leaving enough travel for a stress
# test: on a short-travel device it can consume most or all of the usable
# range between the two endstops, starving the test move of distance to
# ever actually reach the speed/acceleration being tested (see the
# speed-accel-sweep-move-distance design notes). Mirrors the firmware's
# HomingBackoffMinDistanceMm (3mm) - plenty of clearance from a switch,
# not a margin sized for anything else.
SWEEP_TEST_MARGIN_MM = 3.0
SWEEP_TEST_MARGIN_STEPS = int(SWEEP_TEST_MARGIN_MM * FIRMWARE_STEPS_PER_MM)

SPEED_SET_RE = re.compile(r"^Speed set to (\d+)$")
ACCEL_SET_RE = re.compile(r"^Acceleration set to (\d+)$")
CURRENT_SET_RE = re.compile(r"^Run current set to (\d+) mA$")
CHOPPER_ANY_RE = re.compile(r"^Chopper mode set to (SpreadCycle|StealthChop)")
CHOPPER_SPREAD_RE = re.compile(r"^Chopper mode set to SpreadCycle")
CHOPPER_STEALTH_RE = re.compile(r"^Chopper mode set to StealthChop")
CALIBRATION_RESULT_RE = re.compile(
    r"^(?:Max Endstop found\. Max Position: (-?\d+)|(ERROR: (?:Min|Max) endstop not found.*))"
)
# MaxPosition - RetractSteps() directly - already the near-max-end test
# move target, not a raw margin (see fixed-homing-speed design spec).
FIRST_CONTACT_RE = re.compile(r"^First-contact position \(retract [\d.]+ mm\): (-?\d+)$")
MOVE_RESULT_RE = re.compile(
    r"^(?:(Move complete\.)|(ERROR: Repeated unexpected endstop hits - stepper disabled\.))"
)
# cmd21_VerifyPosition ('k') - an unanchored max-endstop reseek from wherever
# the carriage currently is, with no min-endstop re-zero first (unlike 'c').
# See _verify_position() below for why this is the per-step check now,
# instead of a full recalibration.
VERIFY_POSITION_RESULT_RE = re.compile(
    r"^(?:Position verified against Max endstop: (-?\d+)|(ERROR: Max endstop not found - position verify aborted\.))"
)
ENABLE_RE = re.compile(r"^Stepper enabled in normal mode$")
DRIVER_FAULT_RE = re.compile(r"^ERROR: Driver fault detected")
# cmd15_DriverDiagnostics ('x') prints several lines - this only needs the
# live Temperature one (t120/t143/t150/t157/ot are real-time comparators,
# not latched - see the firmware's own comment on that line). A genuine
# SHUTDOWN would already have aborted the whole sweep via DRIVER_FAULT_RE
# before a step ever got this far, so in practice this only ever
# distinguishes OK from a pre-warning/warning tier.
TEMPERATURE_RESULT_RE = re.compile(r"^Temperature:\s+(OK|PRE-WARNING|WARNING|SHUTDOWN)\b")


class Aborted(Exception):
    """Raised inside the sweep coroutine to unwind out of the whole run -
    a driver fault, a dead link, or a user-requested abort. Distinct from
    a normal per-step failure, which never raises this."""

    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


class WaitFor:
    """Yielded by the sweep coroutine: what pattern to match against
    incoming lines, and how long to wait before giving up."""

    def __init__(self, pattern, timeout_s):
        self.pattern = pattern
        self.timeout_s = timeout_s


class ComboResult:
    def __init__(self, current_ma, mode):
        self.current_ma = current_ma
        self.mode = mode
        self.speed_limit = None
        self.accel_limit = None
        # True if the corresponding axis never failed, all the way up to
        # the configured range end - i.e. speed_limit/accel_limit is
        # where testing *stopped*, not a real, found limit. False means
        # a real failure was found and the reported limit is genuine.
        self.speed_reached_end = False
        self.accel_reached_end = False
        # The largest drift (steps) seen at any *passing* step of that
        # axis - 0 doesn't necessarily mean perfect repeatability, it
        # means no passing step happened yet either (check *_limit first).
        # A limit found with drift close to tolerance_steps was closer to
        # failing than one found with drift near zero, even though both
        # count as "passed" - see recommended_value().
        self.speed_max_drift = 0
        self.accel_max_drift = 0
        self.tolerance_steps = None
        # True if the driver's live temperature comparator read anything
        # above OK (t120 or higher) right after this combo's testing - see
        # _check_temperature(). A combo can pass every step-loss check and
        # still run warm; that's a real reliability concern for sustained
        # real-world duty cycles that a brief bench sweep wouldn't
        # otherwise surface.
        self.ran_warm = False
        self.note = ""


# A found limit is the LAST PASSING value - one step away from where it
# broke. Recommending that exact edge for real operation leaves no margin
# for thermal drift, mechanical wear, or load variation the bench sweep
# didn't see. Discount by this fraction instead.
RECOMMENDED_MARGIN_FRACTION = 0.8


def recommended_value(limit, reached_end):
    """A conservative operating point derived from a sweep axis's result.
    When reached_end is True, `limit` is just wherever the configured
    sweep range ran out, not a real, observed failure edge - discounting
    an already-arbitrary cutoff would understate the device's real
    headroom, so it's returned unchanged. When a real failure was found
    (reached_end=False), the margin above is applied."""
    if limit is None:
        return None
    if reached_end:
        return limit
    return int(limit * RECOMMENDED_MARGIN_FRACTION)


def best_combo_per_mode(results):
    """Given the ComboResults from a finished sweep, returns {mode: best
    ComboResult} - one per chopper mode that had at least one combo with
    both a speed and accel limit actually found (a combo that never got a
    baseline, or whose travel was too short, contributes nothing
    comparable). Modes with no usable combo are omitted rather than
    mapped to None, so callers don't need to filter.

    "Best" is ranked by, in priority order:
    1. Not having run warm beats any score difference - reliability
       against thermal buildup during sustained real use matters more
       than a marginally higher number found during a brief bench sweep.
    2. The product of the two RECOMMENDED (already safety-margined)
       values - what someone would actually be told to run at, not the
       raw, edge-of-failure limits. The product has no physical meaning
       on its own (different units), it's only used to rank combos
       relative to each other within this same run.
    3. Lower current wins ties - same measured capability for less heat/
       wear is strictly better.
    """
    best = {}  # mode -> (rank_key, result)
    for result in results:
        speed_rec = recommended_value(result.speed_limit, result.speed_reached_end)
        accel_rec = recommended_value(result.accel_limit, result.accel_reached_end)
        if speed_rec is None or accel_rec is None:
            continue
        rank_key = (not result.ran_warm, speed_rec * accel_rec, -result.current_ma)
        if result.mode not in best or rank_key > best[result.mode][0]:
            best[result.mode] = (rank_key, result)
    return {mode: result for mode, (_, result) in best.items()}


def _single_seek_timeout_s():
    """Worst case for one endstop seek (SeekEndstopPrecise): the
    fast-approach search (CALIBRATION_SEARCH_STEPS steps at the fixed
    HomingSpeed), the back-off (which can run all the way to the
    monitored safety cap before finding release, also at HomingSpeed),
    and the slow re-approach traveling back that same worst-case
    distance plus the overtravel margin, at the fixed HomingSlowSpeed.
    Shared by calibration_timeout() (two seeks) and
    verify_position_timeout() (one seek)."""
    return (
        (CALIBRATION_SEARCH_STEPS + FIRMWARE_HOMING_BACKOFF_MAX_STEPS) / FIRMWARE_HOMING_SPEED
        + (FIRMWARE_HOMING_BACKOFF_MAX_STEPS + FIRMWARE_HOMING_OVERTRAVEL_MARGIN_STEPS) / FIRMWARE_HOMING_SLOW_SPEED
    )


def calibration_timeout():
    """Worst case for a full calibration ('c'): two endstop seeks (min
    then max), plus a flat margin for serial/processing latency.
    Calibration always runs at these fixed firmware speeds now (see the
    fixed-homing-speed design spec), so this no longer depends on
    whatever speed/acceleration is currently being swept."""
    return (2 * _single_seek_timeout_s()) + CALIBRATION_TIMEOUT_MARGIN_S


def verify_position_timeout():
    """Worst case for a position-verify seek ('k'): just one endstop
    seek (max only, no re-zero at min first - see cmd21_VerifyPosition),
    plus the same flat margin."""
    return _single_seek_timeout_s() + CALIBRATION_TIMEOUT_MARGIN_S


def move_timeout(distance_steps, speed, accel):
    """A single absolute move's worst-case duration. distance/speed
    alone understates this for a trapezoidal (or triangular) motion
    profile - part of the travel happens below cruise speed while
    ramping up/down. distance/speed + speed/accel is the exact time
    when cruise speed is reached, and a safe upper bound otherwise (the
    true triangular-profile time, 2*sqrt(distance/accel), is always
    <= this). Plus a flat margin for serial/processing latency and the
    endstop-guard's retry/auto-correction overhead should an unexpected
    (but corrected, not disabled) hit occur mid-move."""
    speed = max(speed, 1)
    accel = max(accel, 1)
    return (abs(distance_steps) / speed) + (speed / accel) + MOVE_TIMEOUT_MARGIN_S


def max_reachable_speed(distance_steps, accel):
    """The highest speed a move of distance_steps can actually reach
    before having to start decelerating again - a trapezoidal profile's
    cutoff, sqrt(distance * accel). A candidate speed above this changes
    nothing about the move actually performed: it still peaks at this
    same value, just via a longer, fully triangular ramp. Used to stop
    the speed sweep before it wastes steps re-testing candidates that
    are all physically identical given the available travel."""
    return int((distance_steps * max(accel, 1)) ** 0.5)


def _step_count(value_range):
    """How many candidate values a (start, end, step, fixed_other) range
    covers - the same sequence _sweep_axis's `while value <= end: ...
    value += step` loop walks. Used only to estimate a sweep's total step
    count up front for progress reporting."""
    start, end, step, _fixed = value_range
    if step <= 0 or end < start:
        return 0
    return (end - start) // step + 1


class SweepTest:
    """Drives a full sweep matrix. Call feed_line(line) for every
    incoming serial line and tick() periodically (e.g. every 100ms) so
    timeouts can fire even when no new line arrives.

    write_line: callback(str) used to send a single line to the device.
    on_combo_done: callback(ComboResult) - fired once per combo that
      finished (normally, or partially if the whole run aborted mid-combo).
    on_finished: callback(aborted: bool, reason: str) - fired once the
      whole run stops, whether it ran to completion or aborted.
    """

    def __init__(self, write_line, on_combo_done, on_finished, on_progress=None,
                 on_step_result=None, time_source=time.monotonic):
        self._write_line = write_line
        self._on_combo_done = on_combo_done
        self._on_finished = on_finished
        self._on_progress = on_progress
        self._on_step_result = on_step_result
        self._time_source = time_source
        self._gen = None
        self._pending_wait = None
        self._wait_deadline = None
        self._running = False
        self._far_margin_steps = SWEEP_TEST_MARGIN_STEPS
        self._abort_reason = ""
        self._completed_steps = 0
        self._total_steps = 0

    def is_running(self):
        return self._running

    def start(self, currents, modes, speed_range, accel_range, tolerance_steps=DEFAULT_TOLERANCE_STEPS,
              far_margin_steps=SWEEP_TEST_MARGIN_STEPS):
        """currents: list[int] mA. modes: list[str], each "spread" or
        "stealth". speed_range: (start, end, step, fixed_acceleration).
        accel_range: (start, end, step, fixed_speed). far_margin_steps: how
        far short of the max endstop the test move stops - lower it to test
        deeper into the tube's high-load region near full closure."""
        self._far_margin_steps = far_margin_steps
        self._running = True
        self._abort_reason = ""
        self._completed_steps = 0
        # The planned total, from the configured ranges - not necessarily
        # what actually runs. A combo that fails or hits its reachable-
        # speed ceiling partway through an axis stops that axis early, so
        # real progress can end up outpacing this estimate near the end of
        # a run. It's still the only total knowable before starting -
        # each combo's own usable travel (which could shrink it further)
        # isn't known until that combo's baseline calibration completes.
        steps_per_combo = _step_count(speed_range) + _step_count(accel_range)
        self._total_steps = len(currents) * len(modes) * steps_per_combo
        self._gen = self._run(currents, modes, speed_range, accel_range, tolerance_steps)
        self._resume(self._gen.send, None)

    def abort(self, reason="aborted by user"):
        if self._running:
            self._resume(self._gen.throw, Aborted(reason))

    def feed_line(self, line):
        if not self._running or self._pending_wait is None:
            return
        if DRIVER_FAULT_RE.match(line):
            self._resume(self._gen.throw, Aborted("driver fault"))
            return
        match = self._pending_wait.pattern.match(line)
        if match:
            self._resume(self._gen.send, match)

    def tick(self):
        if self._running and self._wait_deadline is not None:
            if self._time_source() >= self._wait_deadline:
                self._resume(self._gen.throw, Aborted("timeout waiting for device response"))

    # ---- driver internals ----

    def _resume(self, generator_call, arg):
        try:
            wait_for = generator_call(arg)
        except StopIteration:
            self._finish()
            return
        self._pending_wait = wait_for
        self._wait_deadline = self._time_source() + wait_for.timeout_s

    def _finish(self):
        self._running = False
        self._pending_wait = None
        self._wait_deadline = None
        self._on_finished(bool(self._abort_reason), self._abort_reason)

    # ---- the sweep sequence itself ----

    def _run(self, currents, modes, speed_range, accel_range, tolerance_steps):
        combo_result = None
        try:
            for current_ma in currents:
                yield from self._set_current(current_ma)
                for mode in modes:
                    combo_result = ComboResult(current_ma, mode)
                    combo_result.tolerance_steps = tolerance_steps
                    yield from self._set_mode(mode)

                    baseline_position, _, error = yield from self._calibrate_once()
                    if error is not None:
                        combo_result.note = "baseline calibration failed - " + error
                        self._on_combo_done(combo_result)
                        combo_result = None
                        continue

                    # Margin-based targets, not first-contact-based: see
                    # SWEEP_TEST_MARGIN_STEPS above for why. usable_distance
                    # is the shorter of the two round-trip legs (the
                    # near-min-target -> near-max-target leg) - the binding
                    # distance for how fast a candidate speed can ever
                    # actually be reached.
                    near_min_target = SWEEP_TEST_MARGIN_STEPS
                    near_max_target = baseline_position - self._far_margin_steps
                    usable_distance = near_max_target - near_min_target
                    if usable_distance <= 0:
                        combo_result.note = "travel too short for sweep test margins"
                        self._on_combo_done(combo_result)
                        combo_result = None
                        continue

                    s_start, s_end, s_step, fixed_accel = speed_range
                    speed_ceiling = max_reachable_speed(usable_distance, fixed_accel)
                    (combo_result.speed_limit, combo_result.speed_reached_end,
                     speed_note, combo_result.speed_max_drift) = yield from self._sweep_axis(
                        "f", "g", s_start, s_end, s_step, fixed_accel, tolerance_steps,
                        baseline_position, near_min_target, near_max_target,
                        current_ma, mode, ceiling=speed_ceiling)
                    if speed_note:
                        combo_result.note = speed_note

                    a_start, a_end, a_step, fixed_speed = accel_range
                    (combo_result.accel_limit, combo_result.accel_reached_end,
                     accel_note, combo_result.accel_max_drift) = yield from self._sweep_axis(
                        "g", "f", a_start, a_end, a_step, fixed_speed, tolerance_steps,
                        baseline_position, near_min_target, near_max_target,
                        current_ma, mode)
                    if accel_note:
                        combo_result.note = (combo_result.note + "; " if combo_result.note else "") + accel_note

                    combo_result.ran_warm = yield from self._check_temperature()

                    self._on_combo_done(combo_result)
                    combo_result = None
        except Aborted as exc:
            if combo_result is not None:
                combo_result.note = "aborted - " + exc.reason
                self._on_combo_done(combo_result)
            self._abort_reason = exc.reason
            return

    def _set_current(self, current_ma):
        self._write_line("i")
        self._write_line(str(current_ma))
        yield WaitFor(CURRENT_SET_RE, CONFIRMATION_TIMEOUT_S)

    def _set_mode(self, mode):
        target_re = CHOPPER_SPREAD_RE if mode == "spread" else CHOPPER_STEALTH_RE
        self._write_line("t")
        match = yield WaitFor(CHOPPER_ANY_RE, CONFIRMATION_TIMEOUT_S)
        if target_re.match(match.string):
            return
        self._write_line("t")
        yield WaitFor(target_re, CONFIRMATION_TIMEOUT_S)

    def _set_param(self, cmd_char, value):
        self._write_line(cmd_char)
        self._write_line(str(value))
        pattern = SPEED_SET_RE if cmd_char == "f" else ACCEL_SET_RE
        yield WaitFor(pattern, CONFIRMATION_TIMEOUT_S)

    def _calibrate_once(self):
        """Runs one calibration - now always at the firmware's fixed
        HomingSpeed/HomingAcceleration, so no speed argument is needed
        - and returns (position, first_contact, error). error is None
        on success; position/first_contact are None on failure."""
        self._write_line("c")
        match = yield WaitFor(CALIBRATION_RESULT_RE, calibration_timeout())
        if match.group(1) is None:
            return None, None, match.group(2)
        position = int(match.group(1))
        margin_match = yield WaitFor(FIRST_CONTACT_RE, CONFIRMATION_TIMEOUT_S)
        return position, int(margin_match.group(1)), None

    def _verify_position(self):
        """Runs one 'k' - an unanchored max-endstop reseek from wherever
        the carriage currently is, with no min-endstop re-zero first.
        Unlike _calibrate_once(), which always re-anchors to a fresh,
        known-good zero before counting anything (erasing any drift that
        happened before it ran), this reads motor.getPosition() as it
        stands - an open-loop commanded-pulse count that still carries
        forward any steps lost during the move that preceded this call.
        Comparing the result against a previously trusted position (the
        combo's baseline) exposes missed steps a full recalibration would
        mask. Much cheaper than _calibrate_once() too - one short seek
        instead of a full min+max cycle. Returns (position, error); error
        is None on success, position is None on failure."""
        self._write_line("k")
        match = yield WaitFor(VERIFY_POSITION_RESULT_RE, verify_position_timeout())
        if match.group(1) is None:
            return None, match.group(2)
        return int(match.group(1)), None

    def _check_temperature(self):
        """Sends 'x' and reads just the live Temperature line out of the
        DRIVER FAULT DIAGNOSTICS block cmd15_DriverDiagnostics prints -
        everything else in that block (latched otpw, session-high,
        short-to-ground/supply) is either not per-combo-meaningful (the
        first two persist across the whole run) or already covered by the
        existing driver-fault abort path, so there's no need to parse the
        rest. Returns True if the driver is running at or above the 120C
        pre-warning threshold right at the end of this combo's testing -
        a real reliability concern for sustained real-world duty cycles
        that passing every step-loss check wouldn't otherwise surface."""
        self._write_line("x")
        match = yield WaitFor(TEMPERATURE_RESULT_RE, CONFIRMATION_TIMEOUT_S)
        return match.group(1) != "OK"

    def _test_move(self, target, timeout_s):
        """One absolute move via 'a' - the actual speed/acceleration
        stress test now that calibration's own motion is fixed. Returns
        True on normal completion, False if it tripped the repeated-
        unexpected-endstop-hit safety disable (a stronger, more direct
        signal of missed steps than a post-move calibration mismatch -
        the tracked position diverged enough to run into a switch it
        shouldn't have reached yet)."""
        self._write_line("a")
        self._write_line(str(target))
        match = yield WaitFor(MOVE_RESULT_RE, timeout_s)
        return match.group(1) is not None

    def _sweep_axis(self, swept_cmd, fixed_cmd, start, end, step, fixed_value, tolerance_steps,
                     baseline_position, near_min_target, near_max_target,
                     current_ma, mode, ceiling=None):
        last_passing = None
        max_drift = 0
        value = start
        axis = "speed" if swept_cmd == "f" else "accel"
        while value <= end:
            if ceiling is not None and value > ceiling:
                # Every candidate from here up is physically indistinguishable
                # from `ceiling` given the available travel - a trapezoidal
                # move can't exceed it regardless of what's requested (see
                # max_reachable_speed). Stop instead of wasting steps
                # re-testing the same triangular-profile peak over and over.
                note = (
                    f"stopped at {value} - travel too short to reach it given "
                    f"the fixed value on the other axis (reachable ceiling ~{ceiling})"
                )
                return last_passing, False, note, max_drift

            self._completed_steps += 1
            if self._on_progress is not None:
                self._on_progress(
                    current_ma=current_ma, mode=mode, axis=axis,
                    speed=value if axis == "speed" else fixed_value,
                    accel=fixed_value if axis == "speed" else value,
                    completed=self._completed_steps, total=self._total_steps,
                )

            yield from self._set_param(swept_cmd, value)
            yield from self._set_param(fixed_cmd, fixed_value)

            speed_for_timeout = value if swept_cmd == "f" else fixed_value
            accel_for_timeout = fixed_value if swept_cmd == "f" else value
            leg1_distance = baseline_position - near_min_target
            leg2_distance = near_max_target - near_min_target

            completed = yield from self._test_move(
                near_min_target, move_timeout(leg1_distance, speed_for_timeout, accel_for_timeout))
            if completed:
                completed = yield from self._test_move(
                    near_max_target, move_timeout(leg2_distance, speed_for_timeout, accel_for_timeout))

            passed = False
            needs_reenable = not completed
            if completed:
                position, error = yield from self._verify_position()
                if error is None:
                    drift = abs(position - baseline_position)
                    passed = drift <= tolerance_steps
                    if passed:
                        max_drift = max(max_drift, drift)

            if not completed:
                outcome, step_drift = "fail_move", None
            elif error is not None:
                outcome, step_drift = "fail_verify", None
            elif passed:
                outcome, step_drift = "pass", drift
            else:
                outcome, step_drift = "fail_drift", drift

            if self._on_step_result is not None:
                self._on_step_result(
                    current_ma=current_ma, mode=mode, axis=axis,
                    speed=value if axis == "speed" else fixed_value,
                    accel=fixed_value if axis == "speed" else value,
                    completed=self._completed_steps, total=self._total_steps,
                    outcome=outcome, drift=step_drift, tolerance_steps=tolerance_steps,
                )

            if passed:
                last_passing = value
                value += step
                continue

            # Expected outcome - this is what the sweep is measuring.
            # If the test move itself tripped the repeated-unexpected-
            # hit safety disable, the device won't accept anything else
            # until re-enabled. Either way: step the swept parameter
            # back to the sweep's own starting value (already proven to
            # pass) and recalibrate once more to leave the device in a
            # trustworthy state before moving on.
            if needs_reenable:
                self._write_line("e")
                yield WaitFor(ENABLE_RE, CONFIRMATION_TIMEOUT_S)
            yield from self._set_param(swept_cmd, start)
            # Result intentionally discarded: if this recalibration also
            # fails, the next axis/combo recalibrates from scratch anyway
            # before doing anything else, so there's nothing more useful
            # to do with a failure here than there already is downstream.
            yield from self._calibrate_once()
            return last_passing, False, "", max_drift

        return last_passing, True, "", max_drift
