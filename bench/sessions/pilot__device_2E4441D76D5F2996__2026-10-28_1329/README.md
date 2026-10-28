# Third device pilot, stim laptop, 2026-10-28 13:29

Captured from device 2E4441D76D5F2996 on 2026-10-28. PILOT test data from one
tester (subject number 9999), provisional anchors (uncut tube). Code at `2185457`
plus the mouse-release fix (`e9695db`) and brown noise (`2825bd9`).

Setup: as the first pilot (COM7 through the hub, 10 Psi trials, no tutorial, no
end questionnaires), with the Psi threshold prior narrowed to 50-100 % and masking
noise on: brown, volume 0.2, headphones (USB audio).

Files: `trials.csv` (task CSV, unchanged), `moves.csv`, `calibrations.csv`,
`transcript.log` (full serial transcript), `qc.png` (`bench/qcSession.m`). The
`.mat` stays in `data/raw/`.

## Device

- Motion settings before the session: 16000 steps/s, 10000 steps/s^2, SpreadCycle,
  795 mA run, 50 % hold, 16 microsteps. Same as configured, so calibration sent
  only `s`, `c`, `e`: no `f`, `g`, `t` or `v` in the transcript.
- Calibration MaxPosition 41266 (record 41296, diff -30).
- 32/32 moves confirmed, no ERROR/fault/stall, steps match the level mapping
  exactly, parked open at 1600. Move times: stim 1.03-2.80 s, null 1.41-2.80 s,
  rest 1.05-2.64 s.

## Task

- 10/10 valid. No near-zero response times, so the mouse-release fix held in real
  use (shortest RT 0.42 s).
- The narrowed prior worked: first trial at 72.5 %, and Psi spent trials 3-9 at
  80 %. Threshold after 10 trials 76.2 % (first pilot: 79.2 %).
- Confidence 0 on trials 1, 2 and 10 (one correct, two incorrect), 54-100 on the
  others.

## Tester's notes

- Brown noise at high volume was "a bit eye watering". It had to be turned up
  fairly loud, and the motor was still faintly audible right next to the device
  (closer than in production).
- Proposal: blend noise colours into something rain-like; the rain recording used
  with RRS_3-0 masked well.
- A stray backslash showed on the calibration screen (`\ Please wait`), inherited
  from RRS_3-0. Fixed.
