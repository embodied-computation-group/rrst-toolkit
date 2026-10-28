# Running the 2.0 task

This page is for running the RRST 2.0 task (`task/RRST_2-0/`) on a 2.0 device. For the
legacy task, see [Running the task](../shared/running-the-task.md). Set up the room and
breathing circuit first ([Breathing circuit](../shared/breathing-circuit.md),
[Room and masking](../shared/room-and-masking.md)), and make sure the device has passed
its [bench check](bench-check.md).

!!! warning "Pilot settings, not study settings"
    The task runs with `config/pilotConfig.m`, which is labelled **PILOT**. Several study
    settings are still open: the stimulus unit (percent of the device range or mm), the
    stimulus grid, the Psi priors, the number of trials, the rest position between
    trials, the calibration condition (tube in or out), the motion settings and the
    masking noise. They are listed under "Open questions" in
    [`TASKS.md`](https://github.com/embodied-computation-group/rrst-toolkit/blob/main/TASKS.md).
    `config/zurichConfig.m` refuses to run until they are decided. The values on this
    page are the pilot values.

## Software

| | Version | Notes |
|---|---|---|
| MATLAB | R2024b (tested on the stim laptop) | R2019b or later is needed for `serialport`. The QC figure (`bench/qcSession.m`) also needs Palamedes on the path. |
| Psychtoolbox | 3.0.19 (3.0.19.16 on the stim laptop) | Pinned: 3.0.20 and later need a paid licence key on Windows. Don't run `UpdatePsychtoolbox`. |
| GStreamer | MSVC build (1.28.8 on the stim laptop) | Needed by Psychtoolbox on Windows. |
| Palamedes | 1.11.13 | |

Add Psychtoolbox and Palamedes, with their subfolders, to the MATLAB path and save it.
The task adds its own folders (`task/RRST_2-0/code`, `config`, `task/helpers` and
`device/`) when it starts. It checks that Psychtoolbox and Palamedes are on the path and
stops with an error if either is missing.

!!! note "GStreamer path on Windows"
    Psychtoolbox 3.0.19 needs the environment variable `GSTREAMER_1_0_ROOT_MSVC_X86_64`
    to end with a backslash. Reinstalling GStreamer resets it, and `Screen` then fails.

## First-time setup

### 1. The device record

The task reads the device ID from the firmware and loads `devices/<device ID>.json`.
The record holds the device's measured anchors: 0 = wedge just touching the tube,
100 % = barely possible to inhale. **Without a record the task refuses to run.** Measure
the anchors with `bench/anchorSession.m` (see [Bench check](bench-check.md)) and commit
the record.

The record also states the calibration condition (`"tube in"` or `"tube out"`). Every
session must calibrate in the same condition: the tube adds about 1150 steps to
`MaxPosition`. If the anchors are marked provisional, the task prints the reason before
the session starts.

### 2. The serial port

With the device unplugged, run `serialportlist` in MATLAB. Plug it in and run it again.
The new entry is the device's port.

By default the task uses `cfg.device.port = "auto"`, which works only when exactly one
serial port exists. Most PCs have more than one, so set the port by name (below).

!!! example "The stim laptop"
    On the Zurich stim laptop the device is **COM7**, through a USB hub. Plugged
    directly into the laptop's own USB ports it doesn't appear at all. COM4 and COM5 are
    the laptop's internal LTE modem, so `"auto"` can't be used there.

## Starting a session

In MATLAB:

```matlab
cd <repo>/task/RRST_2-0
addpath('config')
cfg = pilotConfig();
cfg.device.port = "COM7";      % your device's port
cfg.noise.enabled = true;      % masking noise (off by default)
runRRST(cfg)
```

`runRRST()` with no argument uses `pilotConfig()` unchanged (port `"auto"`, no noise).

### Mock run (no device)

Do a mock run on any new PC before the first real session. Nothing moves; a simulated
device answers every command instantly. `cfg.smallWindow` opens a one-third-size window,
so you can still see the MATLAB command window.

```matlab
cd <repo>/task/RRST_2-0
addpath('config')
cfg = pilotConfig();
cfg.device.mock = true;
cfg.smallWindow = true;
runRRST(cfg)
```

Mock data files start with `MOCK_`, so they can't be mistaken for real data.

### Before the window opens

The task asks two questions in the command window:

1. **Subject ID**, a number (saved padded to 4 digits, e.g. `0001`). Press Enter
   without a number for the test ID `9999`. If a completed session for that ID already
   exists in the output folder, the task stops; use a different ID.
2. **Language**: `e` (English) or `d` (Danish).

It then connects to the device and prints the device ID, firmware version and current
motion settings. It loads the device record and checks every configured stimulus level
against the device's scale. A level outside the scale is an error, never clipped.

Finally it prints:

```text
Calibration runs with the tube in, as in the device record.
The wedge will close fully, then open. Press Enter when ready...
```

Check the tube is seated as in the record, and that **nobody is on the mouthpiece**: the
wedge closes fully during calibration. Then press Enter.

## What happens in a session

1. **Calibration** (about 25 s). The screen reads "Please wait while the apparatus
   calibrates." The task sets the motion settings (`cfg.device.motion`), then
   calibrates: the wedge retracts, closes fully to the max endstop, and opens again. The
   measured `MaxPosition` must be within 300 steps of the record's, or the session stops
   (see [Troubleshooting](#troubleshooting)).
2. **Instructions.** The welcome screen explains the trial and the mouse buttons. The
   participant (or you) presses **Space**. The wedge moves to a rest position and the
   masking noise starts, if it's enabled.
3. **Tutorial** (optional, off in the pilot settings: `cfg.runTutorial = false`). An
   easy trial and a hard trial with feedback, a confidence-rating example, practice
   trials, then a break of `cfg.timing.pause` (120 s). See the warning below.
4. **Start.** "The experiment will start now. Press SPACE to start." After Space,
   "Get ready" shows for 3 s.
5. **Trials.** Each trial is a two-interval forced choice: two breaths, one with the
   added resistance (the stimulus), one at level 0 (wedge just touching the tube). The
   stimulus is in the first breath on half of the trials and in the second on the other
   half, in random order. For each breath:
    - the screen shows a circle outline and a countdown ("Get ready to inhale in ...",
      or "Exhale... Get ready to inhale in ..." before the second breath);
    - the wedge moves to that breath's level, and the task waits for the firmware to
      confirm the move;
    - the countdown (`cfg.timing.isi`, 2 s) starts only after the move is confirmed, so
      a slow move makes the trial longer but never shortens the pause;
    - "Take the first inhale..." (or second): after 0.5 s the filled circle expands over
      0.8 s and holds for 0.5 s. The participant breathes in with the circle.
6. **Response.** "Which breath was harder?" Left mouse button = first breath, right =
   second, within 3 s. Only a press that starts after the prompt counts. With no
   response, the trial is repeated and the staircase is not updated.
7. **Confidence.** A slider from "Guess" to "Certain", rated with the mouse within 5 s.
8. **Inter-trial interval.** The screen goes blank and the wedge moves to a random rest
   level in `cfg.stim.restRange` (20-80 % in the pilot). The interval lasts 2-4 s,
   random per trial, counted from the blank screen.
9. **Breaks**, every `cfg.timing.pauseEvery` trials (20). The participant rates how
   unpleasant the task is on a slider. The break screen then counts down
   `cfg.timing.pause` (120 s) and asks them to stand up and move around. With
   `cfg.device.recalibrateAtBreaks = true` (the pilot setting) **the device recalibrates
   during the break**, closing the wedge fully for about 25 s. Make sure the participant
   is off the mouthpiece. After the countdown, "You can continue now"; Space continues.
10. **End.** After the last trial the wedge is **parked** (1 mm from the min endstop,
    well open) and the noise stops. The participant answers the unpleasantness slider
    again, then a few questions in random order (task unpleasantness, dizziness,
    breathlessness, asthma severity), 10 s each. "You have completed the session" shows
    for 2 s, the data are saved and the window closes. For Psi, the command window
    prints the threshold and slope estimates.

The pilot settings run one Psi staircase of 100 trials (`cfg.psi.numTrials`). The
number of trials for a study is open. A full 2.0 session hasn't been timed yet; the
legacy task took 30-35 min for 100 Psi trials, and the tutorial text says 30-40 min.

The command window logs each trial: trial number, level, which breath had the load,
and whether the response was correct.

!!! warning "Tutorial not yet checked"
    The tutorial is ported from `RRS_3-0` but hasn't been run in 2.0. It runs 6 practice
    trials but the pilot settings define only 3 (`cfg.tutorial.exampleStimuli`), so it
    is expected to stop with an error at the fourth practice trial. Esc during the
    tutorial skips the rest of the tutorial; it doesn't abort the session. Keep
    `cfg.runTutorial = false` until this is fixed.

## Experimenter keys

| Key | When | What it does |
|---|---|---|
| **Enter** | Command window, before the window opens | Starts calibration |
| **Space** | Instruction, start and "continue" screens | Continues |
| **Esc** | Countdowns before each breath, inter-trial interval, break countdown | Aborts the session |

With the mouse (the default, `cfg.inputDevice = 2`), Esc is **not** checked on the
response and confidence screens, while the circle expands, or during calibration. Press
it during a countdown or the inter-trial interval.

**Esc aborts the session.** The wedge is parked open, the noise stops, "Experiment was
aborted!" shows for 2 s, and the data so far are saved with an `Aborted_` prefix. The
port is then closed, which switches the motor off.

**If the task stops with an error**, it tries to park the wedge (if the device still
answers), saves the data with an `Error_` prefix, including the error report in
`vars.errorReport`, and shows the error in the command window.

## Masking noise

Masking noise is **off** in the pilot settings. Turn it on with
`cfg.noise.enabled = true`. Settings in `cfg.noise`:

- `file`: the sound to loop, by default `task/helpers/audio/rain_loop_30s.wav`, 30 s of
  synthesised rain that loops without a click (source and checks in
  `task/helpers/audio/README.md`). Leave it empty (`""`) to generate noise instead.
- `volume`: a multiplier on the file. 1 = as recorded (about -29 dBFS RMS). The level in
  the room also depends on the Windows volume.
- `colour`, `fs`, `durS`: used only for generated noise (brown, 44.1 kHz, 30 s loop).

The noise plays on the **default audio output device**. It starts after the welcome
screen and stops when the wedge is parked at the end, so it is not playing during the
first calibration or the end questions. When it starts, the command window prints a
line such as `Masking noise: rain_loop_30s.wav, volume 1, 30 s loop at 48000 Hz.`

Whether the rain masks the motor's high-pitched whine (near 14 kHz in SpreadCycle) still
needs checking by ear at the device.

## Data

Data are saved in `cfg.output.dir`, by default `data/raw/` in the repository. That
folder is never committed to Git. Each session writes two files:

- `RRST_<ID>_<procedure>_<yyyy-mm-dd_HHMM>.mat`: `Results`, `stair`, `vars`, `scr`,
  `keys`. `vars.cfg` is the configuration used. `vars.device` holds the device record,
  every calibration, every move with its level, steps and duration, and the full serial
  transcript.
- the same name with `.csv`: one row per trial.

For example `RRST_0001_psi_2026-10-28_1409.mat`. Prefixes:

| Prefix | Meaning |
|---|---|
| (none) | Completed session |
| `MOCK_` | Mock device; nothing moved |
| `Aborted_` | Esc was pressed |
| `Error_` | The task stopped with an error |

Prefixes combine, e.g. `Aborted_MOCK_RRST_9999_...`. The duplicate-ID check only looks
for completed files, so you can rerun an ID after an aborted or failed run.

## QC figure

`bench/qcSession.m` makes a one-page check of a saved Psi session. Nothing moves. From
the repository root, with Palamedes on the path:

```matlab
addpath('bench')
qcSession("data/raw/RRST_0001_psi_2026-10-28_1409.mat")
```

It writes `<file name>_qc.png` next to the `.mat` file (or pass a second argument with
the output path). The panels:

- **A. Staircase:** the level on each trial (filled = correct, open = incorrect,
  x = no response) and the Psi threshold estimate after each trial, with a 95 % band.
- **B. Psychometric function:** proportion correct per level, the Weibull at the final
  estimate with a 95 % band, and the threshold.
- **C, D.** Response time and confidence, split by accuracy.
- **E.** Stimulus and null move times: a device check.

## Troubleshooting

**"No serial port is available" or "Port COMx is not available".** Check the USB cable
and run `serialportlist` to see which ports exist. If the device doesn't appear at all,
try a USB hub: on the stim laptop it only works through one. If the error lists several
ports, set `cfg.device.port` to the device's port.

**"No record for device ...".** There is no `devices/<device ID>.json` for this device.
Measure its anchors first (see [First-time setup](#first-time-setup)).

**"MaxPosition ... is ... steps from the ... measured with the anchors".** Calibration
doesn't match the record. Check the tube is seated, and that the tube is in or out as
the record says, then start again.

**The window greys out or shows "Not responding".** Windows does this when the task
doesn't poll the window. The wait loops of the main task now call `GetMouse`, which
fixes it. If you see it in the main task, check you are on the current `main`. The
tutorial's loops don't have this fix yet.

**No sound.** Check `cfg.noise.enabled = true`, that the command window printed the
`Masking noise:` line, the Windows volume, and that the headphones or speakers are the
Windows default output device.

**A level is outside the scale.** A configured level (Psi grid, rest range, tutorial
levels) is outside the device's scale. Change the configuration; levels are never
clipped.
