# RRST-Kids first child, stim laptop, 2026-10-30 15:34

Captured from device 2E4441D76D5F2996 on 2026-10-30. USABILITY run with one
4.5-year-old (the experimenter's own child, ID 9002), not study data and not a
measurement of the child: a measurement of the game. Branch `kids-variant` at
`394dc9b` (tutorial, breath feedback, animated mouse, feedback cards), Session B of
`docs/kids_pilot_protocol_2026-10-30.md` (start level 60, 15 Psi + 5 catch, stop after
10, 30 s pauses), standalone recording (the task started `flow_lsl.py` itself).

Stopped with Esc at practice trial 2 (the first catch trial) when she got bored, about
2.5 minutes after free play began. "Fun", by both. Halloween was the competition.

Files: `trials.csv` (tutorial and the one practice trial), `flow.png` (the whole flow
trace with every detected slurp onset in red; the 3 slm onset threshold dashed). The
`.mat` (every flow sample and marker, 13 MB) and `_flow.csv` stay in `data/raw/`.
`qcKids` has nothing to fit for this run (no main trials).

## What happened

| Step | Level | Slurps | Volume (L) | Peak (slm) |
|---|---|---|---|---|
| Free play | 0 | 4 counted + 1 cut off by Space | 0.19, 0.26, 0.30, 0.52 | 17 to 37 |
| Pinch demo | 90 | 4 counted, 8 weak, 1 cut off (13 onsets in 9 s) | 0.11 to 0.24 counted; 0.01 to 0.07 weak | 28 to 35 counted |
| Sleep demo | 0 | 2 counted, 1 weak | 0.65, 0.78 | 64, 72 |
| Practice 1 | 90 | 3 counted | 0.57, 0.66, 0.71 | 50, 48, 58 |

- Reference slurp 0.28 L (median of the four free slurps), so the belly was full at
  0.11 L and a slurp counted above 0.10 L (the floor; 25 % of the reference is 0.07 L).
- Against the obstruction in the pinch demo she took rapid short sniffs (0.1 to 0.3 s)
  rather than one slurp. The demos accept whatever comes and show no "weak".
- Detector: every real breath found, no false onset, the exhale through the T-valve
  never triggered one.
- She was excited and barely following the instructions. Her one practice answer
  ("easy" at level 90, scored wrong) is not evidence of anything and should not be
  read as a perceptual result.

See `handbook/v2/kids.md`, "First child (2026-10-30)", for the write-up and what to
change next.
