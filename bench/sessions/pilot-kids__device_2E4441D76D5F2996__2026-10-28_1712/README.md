# RRST-Kids adult pilot, stim laptop, 2026-10-28 17:12

Captured from device 2E4441D76D5F2996 on 2026-10-28. PILOT test data from one adult
tester (subject number 9999), provisional anchors. First real-device run of the kids
variant (branch `kids-variant`, code at `c3c8ef8`: click-on-a-face answers).

Setup: COM7 through the hub, `kidsConfig` defaults (cap 85 %, start 70 %, 30 Psi + 10
catch trials), rain loop at volume 0.6 on headphones. Stopped with Esc after 2 blocks.

Files: `trials.csv` (practice and main trials), `qc.png` (`qcKids`). The `.mat` stays in
`data/raw/`.

## Result

- Practice 6/6 right (80, 0, 80, 0, 75, 0).
- 21 main trials, 16 Psi + 5 catch, no repeats; 7.5 min including one rest.
- Threshold 79.2 % (SE 4.7), slope 6.2, yes-bias (guess) 0.28.
- Levels 60-80 %: 0/2 "yes" at 60-65, 3/6 at 70, 6/9 at 75, 1/3 at 80.
- False alarms 2 of 5 catch trials. Flagged unusable by the hit-rate rule (1 of 3 at
  80 %), the misfire near threshold 80 described in the kids README.

## Notes

- The detection threshold (79 %) sits close to the 85 % cap. The same tester's 2AFC
  threshold in the adult pilots was about 78-83 %.
- Tester: Esc did not work during the rest screen (fixed after this run, also during
  the star and cup animations).
