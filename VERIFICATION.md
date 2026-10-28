# Verification

Link evidence beside each item. Mark an item "not applicable" with a reason.
Completion is a judgement about relevant evidence, not a count of ticked boxes.

## Scientific specification

- [x] Stimulus anchors (0 and full scale) are defined physically and measured per device.
      Evidence: `devices/2E4441D76D5F2996.json` (zero = wedge touches tube, full = barely
      possible to inhale), log in `bench/sessions/`, 2026-10-28, measured by MG with
      the uncut tube. **Provisional** until full scale is re-measured with the production tube.
- [ ] Stimulus unit, range and staircase priors are decided and match the preregistration.
- [ ] The implementation matches the intended method. The 2.0 task
      (`task/RRST_2-0/`) is ported, but has not yet run under Psychtoolbox and
      Palamedes: first run due on the stim laptop (mock mode, then the device).

## Calculation checks: task layer

- [x] Level-to-step mapping, device record and calibration checks agree with
      hand-worked values. Evidence: `TestStimulator` (mock record MaxPosition 45000,
      offsets 25600/800: 0 % -> 19400, 50 % -> 31800, 100 % -> 44200, 1 mm = 1600 steps;
      MaxPosition 1150 steps off the record -> `rrst:calibrationMismatch`).
      `TestTaskSupport`: records, port choice, masking noise spectrum and loop seam,
      config validation. 74/74 pass, MATLAB R2021a, 2026-10-28.
- [x] A deliberately introduced plausible error is detected (2026-10-28):
      1. Calibration tolerance disabled (`abs(d) > Inf`): caught by
         `calibrationFarFromRecordIsAnError`.
      2. "Pink" noise generated flat (white): caught by
         `pinkNoiseHasMoreLowThanHighFrequencyPower`.
      Both restored; 74/74 pass.
- [x] `checkcode` on all 2.0 task and device files: one syntax error found and fixed
      (`runRRST.m`); the remaining messages are style notes, mostly in code carried
      over from RRS_3-0. Every helper the 2.0 task calls resolves on the path.

## Calculation checks: device layer

- [x] Obstruction-to-step mapping agrees with hand-worked values.
      Evidence: `TestObstructionToSteps` (hand-worked values in the class header:
      8.5 mm -> 32500, 1 mm -> 22353, 25 % -> 26750, 12.5/18 mm -> 36667; anchors
      45123/24000/1000 -> 21123/44123). 41/41 tests pass, MATLAB R2021a, 2026-10-28,
      commit 2b47b27.
- [x] A deliberately introduced plausible error is detected.
      Evidence (2026-10-28):
      1. The old clipping, `value = min(max(value,0),scaleMax)`, put into
         `obstructionToSteps` is caught by 3 tests (`aboveScaleIsAnErrorNotClipped`,
         `belowZeroIsAnError`, `nonFiniteOrNonScalarIsAnError`).
      2. Accepting a move reply without "Move complete." was at first **not**
         detected. The gap was fixed in 2b47b27 with the connection-lost fixture, and
         the mutation is now caught by `moveWithoutCompletionIsNotOk` and
         `connectionLostMidMoveRaises`.
      Both mutations were reverted with `git checkout`, and the suite was rerun:
      41/41 pass.
- [x] Parsers handle success, refusal, firmware ERROR lines, warnings, missing
      confirmation and unsolicited lines. Evidence: `TestReplyParsing`, `TestDevice`.
      **Limit:** every fixture was constructed from the firmware source, not captured
      from hardware.
- [x] `Device` raises on refused moves, failed calibration, lost connection and
      timeouts. Evidence: `TestDevice` (simulated port only).
- [ ] Expected test values were reviewed and not changed merely to pass.

## Hardware-in-the-loop (needs the device)

- [x] `s` status captured: firmware version and device ID recorded (2E4441D76D5F2996,
      Patient-Regulator after flashing; fixtures `status_uncalibrated__*`).
- [x] MATLAB `serialport` and DTR: calibration succeeds when opened through `rrst.openPort`
      (bench/calibrateAndCapture.m, 2026-10-28).
- [x] Transcripts captured from the device match the constructed fixtures (or the
      fixtures are updated with real captures and the parsers still pass). Real
      status, calibrate and enable replies are fixtures with tests.
- [x] Measured move times across the range are recorded and compared with the pause
      between breaths: 0.4 s (0.25 mm) to 4.1 s (full travel). The 2.0 task starts the
      ISI countdown only after the move is confirmed, so the participant's pause is
      never cut short.
- [x] Physical anchors measured, recorded with initials and date (see above).
- [ ] Constant-flow resistance curve (optional): see methods §8.

## Review and history

- [ ] Code and new files have been reviewed by the scientist.
- [ ] Small, descriptive commits record the changes and check outcomes.

## Outstanding questions

See `TASKS.md`.
