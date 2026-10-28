# RRST 2.0 task

The Respiratory Resistance Sensitivity Task for the RRST 2.0 device (Teensy 4.0 +
TMC2209, Patient-Regulator firmware). It is ported from `task/RRS_3-0` (Niia
Nikolova). The screens, timing and Palamedes procedures are unchanged; the device
layer, configuration and known bugs are new.

> **Status (2026-10-28): not yet run under Psychtoolbox.** The device layer is tested
> on the bench and against a simulated device, but the task screens have only been
> code-checked. Do the mock run below before testing with the device or participants.

## Requirements

- MATLAB R2019b or later, for `serialport`. Development used R2021a.
- **Psychtoolbox 3** and **Palamedes** on the MATLAB path.
- This repository: the task uses `device/` (the `rrst` package), `task/helpers/` and
  the device records in `devices/`.
- A record for your device in `devices/<device ID>.json`. Without one the task
  refuses to run. Measure the anchors with `bench/anchorSession.m`.

## Run

```matlab
cd <repo>/task/RRST_2-0

% 1. Mock run: no device needed, nothing moves. Check every screen and the saved data.
addpath('config'); cfg = pilotConfig(); cfg.device.mock = true; cfg.smallWindow = true;
runRRST(cfg)

% 2. With the device (pilot settings)
runRRST()
```

Before anything moves, `runRRST` checks the configuration and toolboxes, finds the
serial port (`cfg.device.port = "auto"` works only when exactly one port exists),
reads the device ID, loads that device's record, and checks every configured level
against the device's range. It then asks you to confirm the tube is seated.
Calibration (about 25 s) closes the wedge fully, then opens it.

**Esc** aborts at any time: the wedge is parked open and the data so far are saved
with an `Aborted_` prefix.

## Event markers (LSL)

With `cfg.markers.lsl = true` (the pilot default) the task opens a Lab Streaming
Layer marker stream named `RRST` at launch, before the participant prompts. A recorder must
start after the stream exists: the Physio Recorder's RRST preset starts recording by
itself when the stream appears. With `cfg.markers.requireRecorder = true` (default),
RRST waits before calibration until a recorder receives the markers, and prints
NOTHING IS RECORDING meanwhile. Each marker carries the event's own time:

| Marker | Event |
|---|---|
| `RRST_ready` | stream opened (sent before any recorder connects) |
| `tutorial_start`, `tutorial_end` | tutorial |
| `session_start` | participant pressed space to begin |
| `trial_<n>_interval<k>_ready` | wedge move confirmed; ISI countdown starts (k = 1, 2) |
| `trial_<n>_interval<k>_onset_load` / `_onset_null` | inhale cue: the expanding ring appears |
| `trial_<n>_level_<x>` | load level of the trial (at the load interval's `_ready`) |
| `trial_<n>_response` / `trial_<n>_noresponse` | answer, or none in time (the trial is repeated with the same n) |
| `trial_<n>_correct` / `trial_<n>_wrong` | whether the answer named the load breath |
| `trial_<n>_confidence` | confidence rating confirmed |
| `trial_<n>_iti` | ITI starts, wedge goes to rest |
| `break_start`, `break_end` | break |
| `session_end_complete` / `_aborted` / `_error` | end of the run |

Needs **liblsl-Matlab** at `cfg.markers.liblslDir` (default
`C:\toolbox\liblsl-Matlab`, release v1.14.0). Replace its `bin\lsl.dll` with a
liblsl 1.18 DLL (for example pylsl's `pylsl\lib\lsl.dll`): with the bundled 1.14
DLL, recorders on liblsl 1.18 kept losing the string stream ("Stream transmission
broke off"). With more than one serial port (e.g. the airflow sensor's
SensorBridge), set `cfg.device.port` explicitly.

## Configuration

`config/pilotConfig.m` holds every setting: device, stimulus axis, procedure (`psi`
or `quest`), Psi grid and priors, timing, breaks, masking noise and output folder.
It is labelled **PILOT**. It is not a study decision. `config/zurichConfig.m` refuses
to run until the open decisions in `TASKS.md` are made.

Stimulus levels are in `cfg.stim.unit`:

- `"percent"`: 0 = wedge just touching the tube, 100 = barely possible to inhale,
  both from the device record.
- `"mm"`: wedge travel past the zero anchor. The first unit offers 15.5 mm.

A level outside the device's scale is an error, never clipped.

## Data

`<repo>/data/raw/RRST_<ID>_<procedure>_<date>.mat` and `.csv`. Mock runs are
prefixed `MOCK_`. `data/raw/` is never committed. Each trial adds these fields to
`Results`, on top of the RRS_3-0 ones:

- `StimSteps`, `StimMoveT`, `NullMoveT`;
- `RestLevel`, `RestMoveT`;
- `Calibrations`.

`vars.device` holds the device record, every calibration, every move with its
duration, and the full serial transcript. `vars.cfg` is the configuration used.

## Changes from RRS_3-0

| Area | RRS_3-0 | 2.0 |
|---|---|---|
| Moves | Sent without waiting; failures went unnoticed | Each move is confirmed by the firmware; failures stop the session |
| Timing | ISI countdown ran while the motor was still moving | ISI countdown starts after the move is confirmed |
| Step range | Hard-coded 12000-38000 | Per-device anchors from `devices/`, checked at every calibration |
| Level used | `round(xCurrent)`: the 0.49 mm grid was never used | The level the staircase proposed |
| Rest between trials | In mm mode, resolved to full obstruction | Random level in `cfg.stim.restRange` |
| Abort / end | Recalibrated, which ends with the wedge closed | Parks the wedge open |
| Masking noise | 60-min wav loaded into memory; audio device 4 hard-coded | Generated pink noise, 30-s loop, default audio device |
| Bugs | `experimentEnd` argument order, `isfield('vars',...)`, `resetResp` undefined, metacog check on `stair(2)` | Fixed |
| Breaks | Repeated if the trial before was invalid | Once per block |

The N-down and method-of-constant-stimuli procedures are not ported. RRS_3-0
described them as untested.
