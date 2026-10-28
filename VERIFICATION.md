# Verification

Link evidence beside each item. Mark an item "not applicable" with a reason.
Completion is a judgement about relevant evidence, not a count of ticked boxes.

## Scientific specification

- [ ] Stimulus anchors (0 and full scale) are defined physically and measured per device.
- [ ] Stimulus unit, range and staircase priors are decided and match the preregistration.
- [ ] The implementation matches the intended method (task not yet imported).

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

- [ ] `s` status captured: firmware version and device ID recorded.
- [ ] MATLAB `serialport` and DTR: calibration succeeds when opened through `rrst.openPort`.
- [ ] Transcripts captured from the device match the constructed fixtures (or the
      fixtures are updated with real captures and the parsers still pass).
- [ ] Measured move times across the range are recorded and compared with the pause
      between breaths.
- [ ] Physical anchors measured, recorded with initials and date.
- [ ] Constant-flow resistance curve (optional): see methods §8.

## Review and history

- [ ] Code and new files have been reviewed by the scientist.
- [ ] Small, descriptive commits record the changes and check outcomes.

## Outstanding questions

See `TASKS.md`.
