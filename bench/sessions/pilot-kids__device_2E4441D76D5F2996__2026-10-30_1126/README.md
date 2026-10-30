# RRST-Kids adult pilot, stim laptop, 2026-10-30 11:26

Captured from device 2E4441D76D5F2996 on 2026-10-30. PILOT test data from one adult
tester (ID 9001), provisional anchors. Second real-device run with breath feedback
(branch `kids-variant`, code at `0ab4583`: tutorial, cap 100, practice 90/90/85,
standalone recording). Stopped with Esc at main trial 21 (the third block).

Setup: COM7 through the hub, SFM3019 flow over LSL in standalone mode (the task
started `flow_lsl.py` itself), `kidsConfig` defaults with 20 Psi + 8 catch trials,
rain loop at volume 0.6 with cue sounds on headphones.

Files: `trials.csv` (tutorial, practice and main trials), `qc.png` (`qcKids`). The
`.mat` (with every flow sample and marker, 18 MB) and `_flow.csv` stay in `data/raw/`.

## Result

- Tutorial: free play, pinch demo at 90, sleep demo. Practice 11 of 12 right over
  two rounds (90, 0, 90, 0, 85, 0).
- 20 main trials, 15 Psi + 5 catch, 1 repeat; 13.5 min in all.
- Threshold 86.9 % (SE 7.1), slope 5.8, yes-bias (guess) 0.11. The early stop (SE < 8
  after 20 Psi trials) had not fired because only 15 Psi trials had run.
- False alarms 0 of 5 catch trials. Flagged unusable by the hit-rate rule (58 % "yes"
  at 80 % and above), the known misfire for thresholds near or above 80.
- Breath detector: 3 of 3 slurps counted on every trial, no weak or false slurps.
  Peak flow fell with the level: about 85 slm at 0, 75-90 at 80, 60 at 85-90, 35 at 95
  (flow-limited plateau, as on the 2026-10-28 bench).
- Experimenter's reports: the mouse did not animate during the wedge move (the move
  blocks for 1.3-2.8 s, longer than the 1.5 s animation budget); the practice
  feedback was only visible in the experimenter line; "trial 21" and a third block
  were unexpected (20 Psi + 8 catch = 28 planned, not shown anywhere).
