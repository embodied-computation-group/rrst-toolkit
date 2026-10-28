# 20-trial device pilot, stim laptop, 2026-10-28 14:09

Captured from device 2E4441D76D5F2996 on 2026-10-28. PILOT test data from one
tester (subject number 9999), provisional anchors (uncut tube). Code at `6d3e4c0`
(stray-prompt fix, rain loop).

Setup: COM7 through the hub, 20 Psi trials, threshold prior 50-100 %, no tutorial,
no end questionnaires, masking sound `rain_loop_30s.wav` at volume 1 on headphones.

Files: `trials.csv`, `moves.csv`, `calibrations.csv`, `transcript.log`, `qc.png`.
The `.mat` stays in `data/raw/`.

## Device

Calibration MaxPosition 41219 (record 41296, diff -77; tolerance 300). 62/62 moves
confirmed, no ERROR/fault/stall, steps match the mapping, parked open. Only `s`,
`c`, `e`, `a` sent. 55 late stray prompts, all skipped by the new framing.

## Task

- 20/20 valid, 17/20 correct. Levels: 72.5, 82.5 x3, 80 x2, then 87.5 for 12 of the
  last 14 trials (67.5 and 90 once each). 13/13 correct at 87.5, 0/2 at 67.5-72.5.
- Psi threshold 82.8 -> 77.6 % over the run, posterior SE 12.3 -> 8.0 %. Slope 6.5.
- Tester: "extremely easy, like it got stuck; I could basically always tell which
  was loaded."
- Errors only at the lowest levels (67.5, 72.5, 80) argue against a non-respiratory
  cue: a sound or timing cue would have made those easy too.

## Why it felt stuck (simulation, 200 runs, observer threshold 78 %, slope 6.5)

| Psi variant | N | threshold RMS error | posterior SE | % correct | median distance of levels from threshold |
|---|---|---|---|---|---|
| standard (as run) | 20 | 6.3 | 10.0 | 81 | 7.0 |
| standard | 40 | 5.9 | 8.0 | 82 | 10.0 |
| slope marginalised | 20 | 5.7 | 10.2 | 81 | 5.0 |
| slope marginalised | 40 | 4.8 | 8.5 | 81 | 6.4 |

A finer grid (50-100 % in 1.25 % steps) changed nothing. Psi works as designed: it
places trials where they say most about threshold *and* slope, which for a steep
function is above threshold, and it runs at about 80 % correct. Twenty trials leave
the threshold uncertain by about +/-10 %.
