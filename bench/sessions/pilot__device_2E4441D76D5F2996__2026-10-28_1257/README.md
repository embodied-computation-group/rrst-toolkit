# First device pilot, stim laptop, 2026-10-28 12:57

Captured from device 2E4441D76D5F2996 on 2026-10-28. PILOT test data, not study
data: one tester (subject number 9999), provisional anchors (uncut tube), masking
noise off, so the threshold is not meaningful.

Setup: ThinkPad X1 Carbon Gen 6, MATLAB R2024b, Psychtoolbox 3.0.19, Palamedes
1.11.13. Device on COM7 through a USB hub. `pilotConfig()` with
`device.port = "COM7"`, `psi.numTrials = 10`, `timing.pauseEvery = 100`,
satisfaction and experience ratings off. Mouse responses.

Files (the `.mat` stays in `data/raw/`, which is not versioned):

- `trials.csv`: the task's per-trial CSV, unchanged.
- `moves.csv`, `calibrations.csv`: `vars.device.moves` and `.calibrations`.
- `transcript.log`: the full serial transcript (`vars.device.transcript`).

## Device: everything confirmed

- Calibration `c` then `e`: MaxPosition 41273, 23 steps from the record's 41296
  (tube in; tolerance 300). zeroStep 15673, fullStep 40473.
- 32 moves (10 stim, 10 null, 11 rest, 1 park), every one answered
  "Move complete."; no ERROR, fault or stall reply. Stim steps match the level
  mapping exactly. Rest levels 25.4-77.1 % (range 20-80). Session ended parked open
  (step 1600).
- Move durations: stim 0.71-2.88 s, null 2.05-2.80 s, rest 0.32-2.75 s.
- After every move the firmware sends one extra `\nValve>`, logged as
  "unsolicited" and drained before the next command (30 of them). Harmless, but
  it should be understood before the rebuild.
- Commands sent: `s` x2, `c`, `e`, `a` x32 (each followed by its target step).

## Task: two findings

1. **A held mouse button is taken as an answer.** Trial 3: RT 0.00 s and confidence
   RT 0.01 s. `getResponse` (mouse) starts polling without waiting for the buttons
   to be released, and `slideScale` checks the button on its first frame, so one
   held click answered both the breath question and the confidence scale. The trial
   was counted as valid.
2. **Confidence 0 on 5 of 9 rated trials**, with normal confidence RTs (0.7-2.6 s).
   Either the tester clicked the far left end, or the slider starts there and the
   click lands before it moves. To check with the tester.

Other: 10/10 trials saved, 9 valid (trial 10 timed out at 3.00 s), signal interval
5/5, all levels on the configured grid. Psi after 10 trials: threshold 79.2 %,
which happens to be close to the bench observation of first noticeable resistance
(12 of 15.5 mm, about 77 %).
