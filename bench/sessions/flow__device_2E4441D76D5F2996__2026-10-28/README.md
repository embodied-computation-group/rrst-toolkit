# Airflow pilot, 2026-10-28 (device 2E4441D76D5F2996)

Pilot data from one operator (Micah Allen), shared with his consent. Stim laptop
(Aarhus), RRST 2.0 unit 2E4441D76D5F2996, Sensirion SFM3019-240 (serial 2033002297)
at the circuit inlet via SEK-SensorBridge, biosignalsplux hub with a respiration belt
on port 1 (no ECG). Recordings are XDF (LSL, one shared clock); load with pyxdf.
Figures were made with `plux-lsl\rrst_figures.py`.

## `wedge_levels_1957/`: flow against wedge level

`bench/flowLevels.m`: the wedge held at 0, 25, 50, 75 and 95 % of the device range
while the operator breathed through the circuit. Streams `Flow` and `RRST` (markers
`level_<x>_ready` / `_done`). The file holds a first, aborted attempt and then the
full run: use the last occurrence of each marker. The recording helper was stopped
by force, so pyxdf reports an unexpected end of file; the data load fine. The marker
stream dropped out twice and reconnected (liblsl 1.14 in MATLAB at the time; all
markers arrived).

Median peak flow / volume per breath: 0 % 84 slm / 1.85 L, 25 % 81 / 1.65,
50 % 73 / 1.23, 75 % 65 / 1.07, 95 % 36 / 0.80. At 95 % the breath is a flat,
flow-limited plateau.

## `rrst20_2208/`: 20-trial RRST with belt and flow

`runRRST` with the pilot configuration, 20 Psi trials, confidence ratings, masking
noise, subject 9999 (test). Recorded with the Physio Recorder's RRST preset, which
started recording automatically when RRST launched. Summary PASS: 149 markers
(42 onsets; one trial repeated after no response), no dropped samples. Streams
`PLUX` (RESP1), `Flow`, `RRST`, `SessionMarkers`. Task files: `.csv` (per trial) and
`.mat` (everything, including confidence in `Results.ConfResp`). Recorded before the
`trial_<n>_level_<x>` and `trial_<n>_correct|wrong` markers existed, so figures need
`--task-csv`.

First look (one person, 20 trials):

- At levels of 75 % or more, the load breath had lower peak flow than the null breath
  on 10 of 12 trials (median 12 slm lower, Wilcoxon p = 0.009). Below 75 %, on 3 of 8.
  Level vs peak drop: Spearman ρ = −0.52, p = 0.02.
- Inhaled volume showed no load effect (median difference −0.01 L, ρ with level
  −0.05): under load the breath was slower and longer.
- On several trials (12, 18, 19) the load breath was the stronger one: spontaneous
  effort changes the stimulus.
- Confidence rose with level (ρ = 0.56, p = 0.01) and with the peak-flow drop
  (ρ = 0.56, p = 0.01; 0.55 among correct trials). Level and flow drop are correlated
  with each other, and neither survives controlling for the other (partial ρ ≈ 0.4,
  p ≈ 0.1).
- The belt signal was small (about ±0.4 %); it was probably worn loose.

## `rrst20_2148_unrecorded/`

The same 20-trial run done once before, at 21:48, when recording was never started.
Task files only. This is why RRST now waits for a recorder before calibration.
