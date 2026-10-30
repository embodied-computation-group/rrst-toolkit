# RRST-Kids: "Milkshake Monster"

A child-friendly variant of the RRST for children of about 4-5 years, on the same
device and device layer as RRST 2.0. **PILOT: never run with a child.** Child-facing
text is English only and must be translated (Swiss German / Danish) before use.

## Story

A purple monster drinks milkshake through a long straw (the mouthpiece). A cheeky
mouse sometimes pinches the straw, so the slurp feels "squishy". On each trial the
experimenter starts the slurping when the child is ready; the child takes three slurps
at the same level and says whether the mouse pinched. Every answer earns a star; ten stars
finish a milkshake and earn a real sticker from the experimenter.

## Why it differs from the adult task

| | Adult RRST 2.0 | Kids |
|---|---|---|
| Judgement | 2 breaths, which was harder (2IFC) | 3 breaths at one level, yes/no ("did the mouse pinch?") |
| Why | | A 4-year-old forgets breath 1 and shows interval bias, which a 2IFC Psi (guess fixed at 0.5) would misread. A yes/no bias is measurable with catch trials. |
| Bias | none modelled | guess rate (false alarms) 0-0.5 in the posterior, marginalised |
| Catch trials | none | 10 at level 0 (wedge just touching), never first, never two in a row |
| Lapse | 0.02 | 0.10 |
| Levels | 0-100 % | 0-85 % in 5 % steps, **hard cap 85 %** |
| Start | Psi's choice | forced 70 % (just perceptible for an adult) |
| Jumps | any | at most 15 % above the highest level so far |
| Trials | 100 | 30 Psi + 10 catch; stops early when SE < 8 after 20 Psi trials |
| Breathing | 0.8 s timed inhale | experimenter presses Space when the child is ready; `cfg.child.slurps` (3) slurps paced at 1.2 s in (belly grows, milkshake drains a third), 1.8 s out (bubbles); pacing is not enforced and Space ends the slurps early. One timed breath was too hard to catch for a 4.5-year-old (first try, 2026-10-28). |
| Answer | participant clicks | **experimenter clicks** what the child says or points at |
| Feedback | none | practice only (the truth, every time); main trials: a star for every answer |

The threshold is the Weibull alpha for p("yes"): a detection threshold with the
child's yes-bias absorbed by the guess rate, not a bias-free sensitivity measure.

## Run

**First, start the Physio Recorder** (desktop shortcut), fill in Participant and
Session, pick the **RRST** preset, tick the devices and click **Check signals**, as for
the adult task ([Running the 2.0 task](../../handbook/v2/running.md),
[Recording physiology and airflow](../../handbook/shared/recording.md)). The task opens
the LSL marker stream `RRST` at launch and the Physio Recorder starts recording by
itself when it appears. With `cfg.markers.requireRecorder = true` (the default) a real
session holds before calibration with **NOTHING IS RECORDING** until a recorder is
connected; click **Start recording** in the app if it hasn't started. Mock-device
(`cfg.device.mock = true`) and simulated-child runs never wait (the adult task has no
such exception). `cfg.markers.lsl = false` runs without LSL; liblsl-Matlab
(`C:\toolbox\liblsl-Matlab`, `cfg.markers.liblslDir`) is then not needed.

```matlab
cd <repo>/task/RRST_kids
addpath('config');

% Try it without a device or a child: simulated device and child, small window, 5x faster
cfg = kidsConfig(); cfg.device.mock = true; cfg.smallWindow = true;
cfg.debug.simulateChild = [70 8 0.1 0.1];   % [threshold slope falseAlarm lapse]
cfg.debug.timeScale = 0.2;
runKidsRRST(cfg)

% With the device (stim laptop: through the USB hub)
cfg = kidsConfig(); cfg.device.port = "COM7";
runKidsRRST(cfg)
```

**Experimenter:** click the face the child chose (any button; the pointer shows only on
the answer screen, a white ring marks the face under it, and clicks in the middle strip are
ignored), or Left arrow / `n` = "easy" (no), Right arrow / `y` = "squishy" (yes). The chosen
face lights up for half a second so you can see what was recorded. `x` = bad breath (trial repeated later). Space = pause
(wedge to 0) and continue. Esc = abort (wedge parked open, data saved as `Aborted_`).
Space also moves on from the story, "Ready to slurp?" and break screens, and ends the
slurps early.

**Session:** calibration with nobody on the tube (about 0.5 min) -> story -> 2 free
slurps and 6 practice trials with feedback (80, 0, 80, 0, 75, 0; pass: 5 of 6 and both
80s right; one retry, then the session ends as `PracticeFailed_`, which is itself an
outcome) -> up to 40 main trials with a 45-s break every 10 -> sticker. About 15-20 s per
trial, so about 15-20 minutes in all.

**Markers** (stream `RRST`; names match the adult task where the event exists). `n`
counts every trial run, free slurps and repeats included, so each `n` is unique; it is
`n` in the saved trials.

| Marker | Event |
|---|---|
| `RRST_ready` | stream opened at launch |
| `calibration_start`, `calibration_end` | calibration (nobody on the tube) |
| `story` | story screen appears |
| `practice_start` | each practice round |
| `main_start` | "Ready" screen before the main trials appears |
| `trial_<n>_level_<x>` | wedge move confirmed; catch trials `level_0` |
| `trial_<n>_go` | experimenter's Space: slurps start |
| `question` | answer screen appears (flip onset) |
| `answer_yes`, `answer_no`, `bad_breath`, `no_answer`, `pause` | experimenter's entry (`no_answer`: none in time) |
| `trial_<n>_correct` / `trial_<n>_wrong` | answered trials: "yes" on a load or "no" on a catch trial is correct |
| `rest_start`, `rest_end` | break; `rest_end` at the Space that resumes the trials |
| `aborted` / `done` | end of the run (`aborted`: Esc or an error; `done`: complete or practice failed) |

**Saved** to `data/raw/` (never committed): `RRSTkids_<ID>_<date>.mat` with the result
(every trial including repeats, practice, Psi posterior, bias flags, outcome), the
configuration, and the device's full move log and transcript; and a `.csv` with one
row per trial. Prefixes: `MOCK_`, `SIM_`, `Aborted_`, `Error_`, `PracticeFailed_`.

## Safety

- No level above `cfg.child.hardCap` is ever sent. `validateKidsConfig` rejects a cap
  above 85 and any configured level (grid, prior, practice, rest, start) above the
  cap; `kidsCheckLevel` checks every level again right before it goes to the device.
- Calibration closes the wedge fully: do it before the child sits down (the script
  asks for that).
- Esc parks the wedge open; closing the port at the end disables the motor. The child
  can always take the mouthpiece out.
- The 85 % cap is a judgement from one adult (87.5 % was easy and not distressing).
  Children breathe with less flow, so the same obstruction gives less pressure drop;
  check 70-85 % on the flow rig and consider a lower cap for the first child.

## Files

- `runKidsRRST.m`: entry point (configuration, markers, device, recorder check, calibration prompt).
- `config/kidsConfig.m`, `config/validateKidsConfig.m`.
- `code/kidsProcedure.m`, `kidsNextLevel.m`, `kidsRecord.m`, `kidsRequeue.m`,
  `kidsShouldStop.m`, `kidsSchedule.m`, `kidsFlags.m`, `kidsCheckLevel.m`: the
  procedure, tested in `tests/TestKids.m` with a simulated child.
- `code/kidsMain.m` (session), `kidsScene.m`, `kidsQuestion.m` (drawing, simple shapes
  only), `kidsText.m`, `kidsSave.m`.
- `code/kidsOpenMarkers.m`, `kidsWaitsForRecorder.m`, `kidsMarkerLabel.m`: LSL markers
  through the shared `task/helpers/rrstMarker.m`, tested in `tests/TestKidsMarkers.m`.
- `simulateKids.m`: precision across simulated children, no screen or device.
- `qcKids.m`: QC figure for one saved session.
- Masking sound: the adult task's rain loop at volume 0.6; check the level for small
  headphones by ear.
- `code/kidsSound.m`, `code/kidsCueWave.m`: rain loop and cue sounds (below), tested
  in `tests/TestKidsSound.m`.

## Sounds

`kidsSound` opens one PsychPortAudio master device (playback, mode 1+8) at the rain
file's sample rate and keeps it running for the session. Two slave devices are mixed
into it: one loops the rain at `cfg.noise.volume`, the other plays short cue sounds at
`cfg.sound.volume`, so a cue never interrupts the masking. The cues are generated in
code by `kidsCueWave` (no sound files): `ready` (rising two-note chime), `slurp`,
`bubbles`, `star` (sparkle), `cup` (fanfare), `mouse` (scamper ticks) and `tryagain`
(soft two notes a whole tone down, neutral, never sad). Usage:

```matlab
snd = kidsSound(cfg.noise, cfg.sound);   % replaces startMaskingNoise(cfg.noise)
snd.play("ready");                       % returns at once; cuts off a cue still playing
snd.stop();                              % stop the cue; the rain keeps going
snd.close();                             % replaces stopMaskingNoise; also on error paths
```

`cfg.sound.enabled = false` turns the cues off (the rain still follows
`cfg.noise.enabled`). Without Psychtoolbox or an audio device, `kidsSound` prints one
`rrst:soundOff` warning and every call is a silent no-op, so a sound problem never
stops the session; check the console for that warning. `snd.active` (cues) and
`snd.rainOn` (rain) say what is playing. Not yet wired into `kidsMain`, which still
calls `startMaskingNoise`; use one or the other, never both. A cue at its peak over a
loud rain droplet can clip briefly (0.6 + 0.72 > 1); lower `cfg.sound.volume` if that
is audible.

## Simulated precision (`simulateKids`, 100 runs per profile, slope 8, lapse 0.1)

| True threshold | False alarms | Bias | RMS error | Final SE | Trials used | Stopped early | Flagged unusable |
|---|---|---|---|---|---|---|---|
| 55 | 0.05 | +1.7 | 3.9 | 6.1 | 27 | 99 % | 0 % |
| 55 | 0.35 | +0.5 | 4.8 | 7.7 | 31 | 81 % | 34 % |
| 70 | 0.05 | +1.0 | 3.9 | 5.6 | 26 | 100 % | 3 % |
| 70 | 0.20 | +0.5 | 3.6 | 6.4 | 27 | 99 % | 11 % |
| 70 | 0.35 | -0.4 | 4.7 | 7.1 | 29 | 90 % | 33 % |
| 80 | 0.05 | -1.1 | 2.9 | 4.0 | 26 | 100 % | 43 % |
| 80 | 0.35 | -4.7 | 6.2 | 5.9 | 27 | 98 % | 46 % |

Threshold estimates are within about 4-6 % (RMS) for every profile, and most runs stop
early after about 27 trials (20 Psi + catch), i.e. about 5 minutes of trials. No level
ever exceeded the cap. Two problems:

- **The "low hit rate" flag misfires for children with high thresholds.** It flags a
  child who says "yes" to fewer than 60 % of trials at 80 % and above, but for a child
  whose threshold is near 80 that is expected, not a sign of a bad session (43 % of
  low-bias children at threshold 80 were flagged). The rule should only apply when the
  estimated threshold is well below 80, or be dropped. Not changed yet: a design call.
- **The false-alarm flag is noisy** with only about 8 catch trials per run: a third of
  children with a true false-alarm rate of 0.35 cross the 0.4 line. More catch trials
  or a posterior-based rule (the guess rate is estimated anyway) would be steadier.

## Not done or not checked

- Never run with a child; one adult run on the real device.
- Cue sounds exist (`kidsSound`) but are not yet played by `kidsMain`. They have run
  without error on the stim PC (2026-10-30, nobody listening); not heard by a child,
  and their loudness over the rain has not been checked by ear.
- Esc is checked during animations, answers and rests, not while the wedge is moving.
- Translations; the colours and drawings have not been seen by a child.
- Design questions from the spec: the cap, what to report when a child's threshold
  is above the cap (practice fails), and whether mouth pressure should be recorded
  to flag weak slurps objectively.
