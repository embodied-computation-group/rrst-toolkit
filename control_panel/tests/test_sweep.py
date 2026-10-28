import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest

from sweep import (
    SweepTest,
    ComboResult,
    calibration_timeout,
    verify_position_timeout,
    move_timeout,
    max_reachable_speed,
    recommended_value,
    best_combo_per_mode,
    RECOMMENDED_MARGIN_FRACTION,
    CALIBRATION_SEARCH_STEPS,
    CALIBRATION_TIMEOUT_MARGIN_S,
    MOVE_TIMEOUT_MARGIN_S,
    FIRMWARE_HOMING_BACKOFF_MAX_STEPS,
    FIRMWARE_HOMING_OVERTRAVEL_MARGIN_STEPS,
    FIRMWARE_HOMING_SPEED,
    FIRMWARE_HOMING_SLOW_SPEED,
    SWEEP_TEST_MARGIN_STEPS,
)


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


class Harness:
    """Drives a SweepTest and records everything it does, so tests can
    script a fake device's responses and assert on the outcome."""

    def __init__(self):
        self.clock = FakeClock()
        self.sent = []
        self.combo_results = []
        self.progress_events = []
        self.step_result_events = []
        self.finished = None  # (aborted, reason)
        self.sweep = SweepTest(
            write_line=self.sent.append,
            on_combo_done=self.combo_results.append,
            on_finished=self._on_finished,
            on_progress=lambda **kwargs: self.progress_events.append(kwargs),
            on_step_result=lambda **kwargs: self.step_result_events.append(kwargs),
            time_source=self.clock,
        )

    def _on_finished(self, aborted, reason):
        self.finished = (aborted, reason)

    def start(self, currents, modes, speed_range, accel_range, tolerance_steps=20):
        self.sweep.start(currents, modes, speed_range, accel_range, tolerance_steps)

    def feed(self, line):
        self.sweep.feed_line(line)

    def reply_current(self, ma):
        self.feed(f"Run current set to {ma} mA")

    def reply_mode(self, mode):
        text = "SpreadCycle" if mode == "spread" else "StealthChop"
        self.feed(f"Chopper mode set to {text} (...)")

    def reply_speed(self, value):
        self.feed(f"Speed set to {value}")

    def reply_accel(self, value):
        self.feed(f"Acceleration set to {value}")

    def reply_calibration_ok(self, position, first_contact):
        self.feed(f"Max Endstop found. Max Position: {position} (no previous saved value to compare)")
        self.feed(f"First-contact position (retract 15.000 mm): {first_contact}")

    def reply_calibration_error(self, which="Max"):
        self.feed(f"ERROR: {which} endstop not found - calibration aborted.")

    def reply_verify_ok(self, position):
        self.feed(f"Position verified against Max endstop: {position}")

    def reply_verify_error(self):
        self.feed("ERROR: Max endstop not found - position verify aborted.")

    def reply_move_ok(self):
        self.feed("Move complete.")

    def reply_move_disabled(self):
        self.feed("ERROR: Repeated unexpected endstop hits - stepper disabled. Investigate before re-enabling (e).")

    def reply_enabled(self):
        self.feed("Stepper enabled in normal mode")

    def reply_driver_fault(self):
        self.feed("ERROR: Driver fault detected - stepper disabled. (overtemperature shutdown ) Investigate before re-enabling (e).")

    def reply_temperature(self, category):
        self.feed(f"Temperature:      {category} - currently >= 120C" if category != "OK"
                   else "Temperature:      OK - currently < 120C")


# Baseline used consistently across tests. Targets are now margin-based,
# not first-contact-based (see SWEEP_TEST_MARGIN_STEPS in sweep.py) -
# first_contact is still sent by the fake device (matching the real
# protocol) but no longer affects the computed targets, so its value here
# is arbitrary. Max Position is picked large relative to the margin so
# ordinary test speeds stay well under the reachable-speed ceiling and
# don't trip the new early-stop behavior by accident (that gets its own
# dedicated, deliberately-short-travel tests below).
BASELINE_POSITION = 100000
FIRST_CONTACT = 84000
NEAR_MIN_TARGET = SWEEP_TEST_MARGIN_STEPS
NEAR_MAX_TARGET = BASELINE_POSITION - SWEEP_TEST_MARGIN_STEPS


def drive_baseline(h, position=BASELINE_POSITION, first_contact=FIRST_CONTACT):
    assert h.sent[-1] == "c"
    h.reply_calibration_ok(position, first_contact)


def drive_one_passing_step(h, swept_cmd, value, fixed_cmd, fixed_value,
                            near_min_target=NEAR_MIN_TARGET, near_max_target=NEAR_MAX_TARGET,
                            baseline_position=BASELINE_POSITION):
    """Answers exactly the exchange one passing sweep step produces:
    set swept param, set fixed param, a two-leg test move, then one
    position-verify ('k') matching the baseline."""
    assert h.sent[-2:] == [swept_cmd, str(value)]
    (h.reply_speed if swept_cmd == "f" else h.reply_accel)(value)
    assert h.sent[-2:] == [fixed_cmd, str(fixed_value)]
    (h.reply_speed if fixed_cmd == "f" else h.reply_accel)(fixed_value)
    assert h.sent[-2:] == ["a", str(near_min_target)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(near_max_target)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_ok(baseline_position)


def drive_combo_completion(h, warm=False):
    """Answers the 'x' temperature check SweepTest sends after both axes
    of a combo finish, right before on_combo_done fires."""
    assert h.sent[-1] == "x"
    h.reply_temperature("PRE-WARNING" if warm else "OK")


def test_single_combo_speed_sweep_passes_every_step_reaches_end():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),  # start, end, step, fixed accel
        accel_range=(5000, 5000, 1000, 1000),  # single-step accel sweep, fixed speed 1000
    )

    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    for speed in (1000, 2000, 3000):
        drive_one_passing_step(h, "f", speed, "g", 5000)

    # Acceleration sweep: single step at 5000, fixed speed 1000.
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    assert len(h.combo_results) == 1
    result = h.combo_results[0]
    assert result.current_ma == 800
    assert result.mode == "spread"
    assert result.speed_limit == 3000
    assert result.accel_limit == 5000
    assert result.note == ""


def test_baseline_calibration_failure_reports_combo_and_moves_on():
    h = Harness()
    h.start(
        currents=[800, 1000],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    assert h.sent[-1] == "c"
    h.reply_calibration_error("Min")

    assert h.finished is None  # whole run doesn't abort - just this combo
    assert len(h.combo_results) == 1
    assert h.combo_results[0].note == "baseline calibration failed - ERROR: Min endstop not found - calibration aborted."

    # Sweep continues on to the next current.
    assert h.sent[-2:] == ["i", "1000"]
    h.reply_current(1000)
    h.reply_mode("spread")
    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)
    drive_one_passing_step(h, "f", 2000, "g", 5000)
    drive_one_passing_step(h, "f", 3000, "g", 5000)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    assert len(h.combo_results) == 2


def test_step_fails_via_verify_position_error():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    drive_one_passing_step(h, "f", 1000, "g", 5000)  # step 1 passes

    # Step 2 (speed=2000): test move completes, but the verify seek errors.
    assert h.sent[-2:] == ["f", "2000"]
    h.reply_speed(2000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(NEAR_MAX_TARGET)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_error()

    # Step-back to start (1000) + one recovery recalibration.
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-1] == "c"
    drive_baseline(h)  # recovery recalibration reply (position content doesn't matter)

    # Acceleration sweep still runs normally afterward.
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    result = h.combo_results[0]
    assert result.speed_limit == 1000  # last passing value, not 2000
    assert result.note == ""


def test_step_fails_via_verify_position_mismatch():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 2000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    # step 1 (speed=1000): test move completes, but the verify seek's
    # position disagrees with the baseline by more than tolerance (20) -
    # exactly the signature of steps lost during the test move itself.
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(NEAR_MAX_TARGET)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_ok(BASELINE_POSITION + 50)  # 50 steps off, over the 20-step tolerance

    # on_step_result reports this same step as a measured-drift failure,
    # not just a pass/fail bit.
    assert h.step_result_events[-1]["outcome"] == "fail_drift"
    assert h.step_result_events[-1]["drift"] == 50

    # step-back to start (1000 - already the start here) + recovery recalibration
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-1] == "c"
    drive_baseline(h)

    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    result = h.combo_results[0]
    assert result.speed_limit is None  # even the first step failed
    assert result.note == ""


def test_step_fails_via_move_disabled_requires_reenable_before_recovery():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 2000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    # step 1 (speed=1000): the first leg of the test move trips the
    # repeated-unexpected-endstop-hit safety disable instead of completing.
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_disabled()

    # on_step_result reports this as a move failure, not a drift mismatch -
    # there's no position to measure drift against, since verify never ran.
    assert h.step_result_events[-1]["outcome"] == "fail_move"
    assert h.step_result_events[-1]["drift"] is None

    # Device is disabled now - must be re-enabled before anything else works.
    assert h.sent[-1] == "e"
    h.reply_enabled()

    # Then the usual step-back-and-recalibrate recovery.
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-1] == "c"
    drive_baseline(h)

    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    result = h.combo_results[0]
    assert result.speed_limit is None


def test_driver_fault_mid_sweep_aborts_entire_run_not_just_combo():
    h = Harness()
    h.start(
        currents=[800, 1000],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)

    # Mid-second-step, a real driver fault shows up instead of a set confirmation.
    assert h.sent[-2:] == ["f", "2000"]
    h.reply_driver_fault()

    assert h.finished == (True, "driver fault")
    # The in-progress combo is still reported, with a note, and nothing
    # about current=1000 (the second, never-reached current) was sent.
    assert len(h.combo_results) == 1
    result = h.combo_results[0]
    assert result.current_ma == 800
    assert result.note == "aborted - driver fault"
    # The second current (1000mA) was never set - i.e. "i" is never
    # immediately followed by "1000" anywhere in what was sent.
    sent_pairs = list(zip(h.sent, h.sent[1:]))
    assert ("i", "1000") not in sent_pairs
    assert not h.sweep.is_running()


def test_confirmation_timeout_aborts_entire_run():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    assert h.sent[-2:] == ["f", "1000"]
    # No reply arrives - advance the fake clock past the confirmation timeout.
    h.clock.advance(10)
    h.sweep.tick()

    assert h.finished == (True, "timeout waiting for device response")
    assert not h.sweep.is_running()


def test_multi_combo_sequencing_currents_x_modes_in_order():
    h = Harness()
    h.start(
        currents=[800, 1000],
        modes=["spread", "stealth"],
        speed_range=(1000, 1000, 1000, 5000),  # single-step sweeps, keep this test short
        accel_range=(5000, 5000, 1000, 1000),
    )

    for current in (800, 1000):
        h.reply_current(current)
        for mode in ("spread", "stealth"):
            h.reply_mode(mode)
            drive_baseline(h)
            drive_one_passing_step(h, "f", 1000, "g", 5000)
            drive_one_passing_step(h, "g", 5000, "f", 1000)
            drive_combo_completion(h)

    assert h.finished == (False, "")
    combos = [(r.current_ma, r.mode) for r in h.combo_results]
    assert combos == [(800, "spread"), (800, "stealth"), (1000, "spread"), (1000, "stealth")]


def test_abort_called_by_ui_stops_run_and_sends_nothing_further():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    sent_before_abort = len(h.sent)

    h.sweep.abort()

    assert h.finished == (True, "aborted by user")
    assert not h.sweep.is_running()
    assert len(h.sent) == sent_before_abort  # nothing new sent after abort


def test_abort_accepts_a_custom_reason():
    # Used by app.py to distinguish an automatic abort (e.g. the device
    # disconnected mid-sweep) from the user actually clicking Abort.
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")

    h.sweep.abort(reason="device disconnected")

    assert h.finished == (True, "device disconnected")
    assert not h.sweep.is_running()


def test_set_mode_sends_second_toggle_when_first_lands_on_wrong_mode():
    h = Harness()
    h.start(
        currents=[800],
        modes=["stealth"],
        speed_range=(1000, 1000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)

    # First toggle lands on SpreadCycle - not the target "stealth" - so
    # the coroutine must send a second toggle rather than proceeding.
    assert h.sent[-1] == "t"
    h.reply_mode("spread")
    assert h.sent[-1] == "t"  # second toggle sent, not something else
    h.reply_mode("stealth")

    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    assert h.combo_results[0].mode == "stealth"


def test_reached_end_reported_when_axis_never_fails():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 2000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)
    drive_one_passing_step(h, "f", 2000, "g", 5000)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    result = h.combo_results[0]
    assert result.speed_limit == 2000
    assert result.speed_reached_end is True
    assert result.accel_limit == 5000
    assert result.accel_reached_end is True


def test_reached_end_false_when_a_real_failure_was_found():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)

    assert h.sent[-2:] == ["f", "2000"]
    h.reply_speed(2000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(NEAR_MAX_TARGET)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_error()
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-1] == "c"
    drive_baseline(h)

    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    result = h.combo_results[0]
    assert result.speed_limit == 1000
    assert result.speed_reached_end is False


def test_calibration_timeout_is_a_fixed_constant_based_on_homing_speed():
    # Hand-computed from the same formula: per seek is the fast-approach
    # search plus worst-case back-off (both at the fixed HomingSpeed),
    # plus the worst-case slow re-approach (at the fixed HomingSlowSpeed)
    # - doubled for min+max seeks, plus the flat serial/processing
    # margin. Calibration always runs at these fixed firmware speeds
    # now, so this no longer takes a speed argument.
    per_seek = (
        (CALIBRATION_SEARCH_STEPS + FIRMWARE_HOMING_BACKOFF_MAX_STEPS) / FIRMWARE_HOMING_SPEED
        + (FIRMWARE_HOMING_BACKOFF_MAX_STEPS + FIRMWARE_HOMING_OVERTRAVEL_MARGIN_STEPS) / FIRMWARE_HOMING_SLOW_SPEED
    )
    expected = 2 * per_seek + CALIBRATION_TIMEOUT_MARGIN_S
    assert calibration_timeout() == pytest.approx(expected)
    assert calibration_timeout() > 20.0


def test_verify_position_timeout_is_half_of_calibration_timeout():
    # verify_position_timeout() covers one endstop seek (max only, no
    # min-endstop re-zero), not two - it should take exactly the margin
    # off, halve what's left, then add the same margin back.
    assert verify_position_timeout() == pytest.approx(
        (calibration_timeout() - CALIBRATION_TIMEOUT_MARGIN_S) / 2 + CALIBRATION_TIMEOUT_MARGIN_S
    )
    assert verify_position_timeout() < calibration_timeout()


def test_move_timeout_scales_with_distance_and_speed():
    speed, accel = 8000, 5000
    ramp_term = speed / accel
    assert move_timeout(8000, speed, accel) == pytest.approx(8000 / speed + ramp_term + MOVE_TIMEOUT_MARGIN_S)
    assert move_timeout(16000, speed, accel) == pytest.approx(16000 / speed + ramp_term + MOVE_TIMEOUT_MARGIN_S)
    # Doubling the distance grows only the distance-dependent portion -
    # the acceleration ramp term and margin are per-move constants, not
    # per-distance.
    assert move_timeout(16000, speed, accel) - move_timeout(8000, speed, accel) == pytest.approx(8000 / speed)


def test_move_timeout_includes_acceleration_ramp_term():
    # distance/speed alone understates a trapezoidal move's real worst
    # case - part of the travel happens below cruise speed while
    # ramping up/down. A weaker acceleration means a longer ramp
    # (speed/accel), which must show up as a longer timeout even with
    # distance/speed held fixed.
    distance, speed = 8000, 8000
    slow_accel_timeout = move_timeout(distance, speed, 1000)
    fast_accel_timeout = move_timeout(distance, speed, 10000)
    assert slow_accel_timeout > fast_accel_timeout
    assert slow_accel_timeout - fast_accel_timeout == pytest.approx(speed / 1000 - speed / 10000)


def test_move_timeout_handles_zero_speed_and_zero_accel_without_dividing_by_zero():
    assert move_timeout(8000, 0, 5000) == move_timeout(8000, 1, 5000)
    assert move_timeout(8000, 8000, 0) == move_timeout(8000, 8000, 1)


def test_max_reachable_speed_is_trapezoidal_cutoff():
    # sqrt(distance * accel), truncated to an int.
    assert max_reachable_speed(10000, 4000) == int((10000 * 4000) ** 0.5)
    assert max_reachable_speed(10000, 4000) == 6324
    assert max_reachable_speed(10, 3) == 5  # sqrt(30) = 5.477...


def test_max_reachable_speed_handles_zero_accel_without_dividing_by_zero():
    assert max_reachable_speed(10000, 0) == max_reachable_speed(10000, 1)


def test_recommended_value_discounts_a_real_failure_edge():
    # reached_end=False means a real failure was found just past this
    # value - the exact edge, with no margin for thermal drift or wear.
    assert recommended_value(50000, reached_end=False) == int(50000 * RECOMMENDED_MARGIN_FRACTION)
    assert recommended_value(50000, reached_end=False) == 40000


def test_recommended_value_leaves_reached_end_unchanged():
    # reached_end=True means the sweep never actually found a failure -
    # `limit` is just wherever the configured range ran out, not a real
    # observed edge. Discounting an already-arbitrary cutoff would
    # understate real headroom, so it's returned as-is.
    assert recommended_value(20000, reached_end=True) == 20000


def test_recommended_value_handles_no_passing_value():
    assert recommended_value(None, reached_end=False) is None
    assert recommended_value(None, reached_end=True) is None


def test_combo_result_tracks_worst_drift_seen_among_passing_steps():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)  # Max Position BASELINE_POSITION

    # step 1 (speed=1000): passes with zero drift.
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(NEAR_MAX_TARGET)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_ok(BASELINE_POSITION)

    # step 2 (speed=2000): passes, but with 15 steps of drift - still
    # within the default tolerance (20), so it counts as a pass, but it's
    # the new worst-observed drift for this axis.
    assert h.sent[-2:] == ["f", "2000"]
    h.reply_speed(2000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(NEAR_MAX_TARGET)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_ok(BASELINE_POSITION + 15)

    # step 3 (speed=3000): passes with zero drift again - the worst-seen
    # value must stay at 15, not drop back down.
    drive_one_passing_step(h, "f", 3000, "g", 5000)

    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    result = h.combo_results[0]
    assert result.speed_limit == 3000
    assert result.speed_max_drift == 15
    assert result.accel_max_drift == 0  # every accel step passed with zero drift
    assert result.tolerance_steps == 20


def test_progress_reports_current_settings_and_step_count():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 2000, 1000, 5000),  # 2 speed steps
        accel_range=(5000, 5000, 1000, 1000),  # 1 accel step -> total 3
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    # Progress for the first speed step fires before its own confirmation
    # replies are even sent - it's reporting what's about to be tested.
    assert len(h.progress_events) == 1
    ev = h.progress_events[0]
    assert ev == {
        "current_ma": 800, "mode": "spread", "axis": "speed",
        "speed": 1000, "accel": 5000, "completed": 1, "total": 3,
    }

    drive_one_passing_step(h, "f", 1000, "g", 5000)
    assert h.progress_events[-1]["completed"] == 2
    assert h.progress_events[-1]["axis"] == "speed"
    assert h.progress_events[-1]["speed"] == 2000

    drive_one_passing_step(h, "f", 2000, "g", 5000)
    assert h.progress_events[-1]["completed"] == 3
    assert h.progress_events[-1]["axis"] == "accel"
    assert h.progress_events[-1]["speed"] == 1000  # fixed speed for the accel sweep
    assert h.progress_events[-1]["accel"] == 5000  # first accel candidate

    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert len(h.progress_events) == 3  # nothing further once the last axis's only step is done
    assert h.finished == (False, "")


def test_progress_total_is_planned_range_even_when_a_candidate_is_never_attempted():
    h = Harness()
    small_baseline = 20000  # usable_distance = 20000 - 9600 = 10400
    fixed_accel = 5000
    # reachable ceiling = int(sqrt(5000 * 10400)) = 7211 - the range below
    # asks for candidates up to 10000, so 8000/9000/10000 are never
    # actually attempted, but the planned total still counts all of them.
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 10000, 1000, fixed_accel),  # 10 planned speed steps
        accel_range=(5000, 5000, 1000, 1000),  # 1 planned accel step -> total 11
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h, position=small_baseline)

    assert h.progress_events[0]["total"] == 11

    near_min = SWEEP_TEST_MARGIN_STEPS
    near_max = small_baseline - SWEEP_TEST_MARGIN_STEPS
    for speed in range(1000, 7001, 1000):
        drive_one_passing_step(h, "f", speed, "g", fixed_accel,
                                near_min_target=near_min, near_max_target=near_max,
                                baseline_position=small_baseline)

    # Stopped by the ceiling after 7 speed steps - 8000/9000/10000 never
    # attempted, so no progress event exists for them, even though the
    # planned total above still counted all 10. The accel axis's own
    # single planned step still fires right after (completed=8), so the
    # final count is 8 (7 speed + 1 accel), not the full 11 planned.
    speed_values_reported = [ev["speed"] for ev in h.progress_events if ev["axis"] == "speed"]
    assert speed_values_reported == [1000, 2000, 3000, 4000, 5000, 6000, 7000]
    assert max(ev["completed"] for ev in h.progress_events) == 8  # not 11


def test_combo_result_records_whether_the_driver_ran_warm():
    h = Harness()
    h.start(
        currents=[1200],
        modes=["spread"],
        speed_range=(1000, 1000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(1200)
    h.reply_mode("spread")
    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h, warm=True)

    assert h.combo_results[0].ran_warm is True


def test_combo_result_not_warm_when_temperature_reads_ok():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 1000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)
    drive_one_passing_step(h, "f", 1000, "g", 5000)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h, warm=False)

    assert h.combo_results[0].ran_warm is False


def test_test_move_targets_use_fixed_margin_not_first_contact():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 1000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    # first_contact is deliberately way off from the margin-based targets -
    # it must have zero effect on what the test move actually targets.
    drive_baseline(h, position=BASELINE_POSITION, first_contact=1)

    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(SWEEP_TEST_MARGIN_STEPS)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(BASELINE_POSITION - SWEEP_TEST_MARGIN_STEPS)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_ok(BASELINE_POSITION)

    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)

    assert h.finished == (False, "")


def test_combo_skipped_when_travel_too_short_for_sweep_margins():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 3000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    # 2 * SWEEP_TEST_MARGIN_STEPS (9600) exceeds this baseline (5000) - the
    # near-min and near-max targets would cross, so the combo must be
    # skipped rather than sending a nonsensical move.
    drive_baseline(h, position=5000)

    assert h.finished == (False, "")
    assert len(h.combo_results) == 1
    assert h.combo_results[0].note == "travel too short for sweep test margins"
    assert "f" not in h.sent
    assert "a" not in h.sent


def test_speed_sweep_stops_early_when_travel_too_short_for_candidate():
    h = Harness()
    small_baseline = 20000  # usable_distance = 20000 - 9600 = 10400
    fixed_accel = 5000
    # reachable ceiling = int(sqrt(5000 * 10400)) = 7211
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 10000, 1000, fixed_accel),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h, position=small_baseline)

    near_min = SWEEP_TEST_MARGIN_STEPS
    near_max = small_baseline - SWEEP_TEST_MARGIN_STEPS
    for speed in range(1000, 7001, 1000):
        drive_one_passing_step(h, "f", speed, "g", fixed_accel,
                                near_min_target=near_min, near_max_target=near_max,
                                baseline_position=small_baseline)

    # 8000 exceeds the reachable ceiling (7211) - the sweep must stop
    # before ever sending 'f'/'8000', not send it and then fail on it.
    assert ("f", "8000") not in list(zip(h.sent, h.sent[1:]))

    drive_one_passing_step(h, "g", 5000, "f", 1000,
                            near_min_target=near_min, near_max_target=near_max,
                            baseline_position=small_baseline)
    drive_combo_completion(h)

    assert h.finished == (False, "")
    result = h.combo_results[0]
    assert result.speed_limit == 7000  # last value actually reachable and passing
    assert result.speed_reached_end is False
    assert "reachable ceiling" in result.note


def _make_result(current_ma, mode, speed_limit, speed_reached_end, accel_limit, accel_reached_end, ran_warm=False):
    r = ComboResult(current_ma, mode)
    r.speed_limit = speed_limit
    r.speed_reached_end = speed_reached_end
    r.accel_limit = accel_limit
    r.accel_reached_end = accel_reached_end
    r.ran_warm = ran_warm
    return r


def test_best_combo_per_mode_picks_the_highest_scoring_combo():
    results = [
        _make_result(600, "spread", speed_limit=20000, speed_reached_end=False, accel_limit=20000, accel_reached_end=False),
        _make_result(1000, "spread", speed_limit=40000, speed_reached_end=False, accel_limit=40000, accel_reached_end=False),
    ]
    best = best_combo_per_mode(results)
    assert best["spread"].current_ma == 1000


def test_best_combo_per_mode_prefers_not_running_warm_over_a_higher_score():
    results = [
        _make_result(1200, "spread", speed_limit=80000, speed_reached_end=False, accel_limit=80000,
                     accel_reached_end=False, ran_warm=True),
        _make_result(800, "spread", speed_limit=30000, speed_reached_end=False, accel_limit=30000,
                     accel_reached_end=False, ran_warm=False),
    ]
    best = best_combo_per_mode(results)
    # The 1200mA combo scores far higher, but ran warm - reliability under
    # sustained real use outranks a bigger number from a brief bench sweep.
    assert best["spread"].current_ma == 800


def test_best_combo_per_mode_breaks_ties_with_lower_current():
    results = [
        _make_result(1000, "spread", speed_limit=25000, speed_reached_end=False, accel_limit=25000, accel_reached_end=False),
        _make_result(600, "spread", speed_limit=25000, speed_reached_end=False, accel_limit=25000, accel_reached_end=False),
    ]
    best = best_combo_per_mode(results)
    assert best["spread"].current_ma == 600


def test_best_combo_per_mode_excludes_combos_missing_either_limit():
    results = [
        _make_result(800, "spread", speed_limit=None, speed_reached_end=False, accel_limit=30000, accel_reached_end=False),
        _make_result(1000, "spread", speed_limit=25000, speed_reached_end=False, accel_limit=25000, accel_reached_end=False),
    ]
    best = best_combo_per_mode(results)
    assert best["spread"].current_ma == 1000


def test_best_combo_per_mode_is_separate_per_mode_and_omits_unusable_modes():
    results = [
        _make_result(800, "spread", speed_limit=30000, speed_reached_end=False, accel_limit=30000, accel_reached_end=False),
        _make_result(800, "stealth", speed_limit=None, speed_reached_end=False, accel_limit=None, accel_reached_end=False),
    ]
    best = best_combo_per_mode(results)
    assert "spread" in best
    assert "stealth" not in best  # no usable combo for this mode


def test_step_result_fires_on_pass_with_measured_drift():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 2000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    # step 1 (speed=1000): verify succeeds, 5 steps off - within the
    # default 20-step tolerance, so this passes but with nonzero drift.
    drive_one_passing_step(h, "f", 1000, "g", 5000, baseline_position=BASELINE_POSITION + 5)

    assert h.step_result_events[-1] == {
        "current_ma": 800, "mode": "spread", "axis": "speed",
        "speed": 1000, "accel": 5000, "completed": 1, "total": 3,
        "outcome": "pass", "drift": 5, "tolerance_steps": 20,
    }

    # Finish the run cleanly.
    drive_one_passing_step(h, "f", 2000, "g", 5000)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)
    assert h.finished == (False, "")


def test_step_result_fires_on_fail_verify():
    h = Harness()
    h.start(
        currents=[800],
        modes=["spread"],
        speed_range=(1000, 2000, 1000, 5000),
        accel_range=(5000, 5000, 1000, 1000),
    )
    h.reply_current(800)
    h.reply_mode("spread")
    drive_baseline(h)

    # step 1 (speed=1000): test move completes, but the verify seek errors.
    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-2:] == ["g", "5000"]
    h.reply_accel(5000)
    assert h.sent[-2:] == ["a", str(NEAR_MIN_TARGET)]
    h.reply_move_ok()
    assert h.sent[-2:] == ["a", str(NEAR_MAX_TARGET)]
    h.reply_move_ok()
    assert h.sent[-1] == "k"
    h.reply_verify_error()

    assert h.step_result_events[-1] == {
        "current_ma": 800, "mode": "spread", "axis": "speed",
        "speed": 1000, "accel": 5000, "completed": 1, "total": 3,
        "outcome": "fail_verify", "drift": None, "tolerance_steps": 20,
    }

    assert h.sent[-2:] == ["f", "1000"]
    h.reply_speed(1000)
    assert h.sent[-1] == "c"
    drive_baseline(h)
    drive_one_passing_step(h, "g", 5000, "f", 1000)
    drive_combo_completion(h)
    assert h.finished == (False, "")
