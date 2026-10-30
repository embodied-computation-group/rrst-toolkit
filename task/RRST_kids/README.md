# RRST-Kids: "Milkshake Monster"

A child-friendly variant of the RRST for children of about 4-5 years, on the same
device and device layer as RRST 2.0. **PILOT: never run with a child.** Child-facing
text is English only and must be translated (Swiss German / Danish) before use.

## Story

A purple monster drinks milkshake through a long straw (the mouthpiece). A cheeky
mouse sometimes pinches the straw, so the slurp feels "squishy". On each trial the
experimenter starts the slurping when the child is ready; the child takes three slurps
at the same level, the monster drinks when the child slurps (airflow sensor), and the
child says whether the mouse pinched. Every answer earns a star; ten stars
finish a milkshake and earn a real sticker from the experimenter.

**Stars** are one per answer, right or wrong: progress toward a cup and a sticker, not
a score. They are not feedback, so they are shown in every run, feedback on or off.

**Tutorial** (before the practice): free play at level 0 (the child slurps as often as
they like and watches the belly fill; every slurp sets the reference), two demos with
no question (the mouse pinching the straw during three slurps at 90 %, then asleep
during three at 0, each followed by its reveal), and a bridge screen with the two
answer cards for the experimenter to explain ("Now you say: did the mouse pinch?").

## Why it differs from the adult task

| | Adult RRST 2.0 | Kids |
|---|---|---|
| Judgement | 2 breaths, which was harder (2IFC) | 3 breaths at one level, yes/no ("did the mouse pinch?") |
| Why | | A 4-year-old forgets breath 1 and shows interval bias, which a 2IFC Psi (guess fixed at 0.5) would misread. A yes/no bias is measurable with catch trials. |
| Bias | none modelled | guess rate (false alarms) 0-0.5 in the posterior, marginalised |
| Catch trials | none | 10 at level 0 (wedge just touching), never first, never two in a row |
| Lapse | 0.02 | 0.10 |
| Levels | 0-100 % | 0-100 % in 5 % steps; `cfg.child.hardCap` (default 100, the full scale) is enforced at launch and before every move |
| Start | Psi's choice | forced 70 % (just perceptible for an adult) |
| Jumps | any | at most 15 % above the highest level so far |
| Trials | 100 | 30 Psi + 10 catch, so up to 40 (plus repeats); stops early when SE < 8 after 20 *Psi* trials (catch trials do not count). The experimenter line counts them: `Trial 21 of up to 28 (Psi 15/20, catch 6/8)` |
| Breathing | 0.8 s timed inhale | experimenter presses Space when the child is ready; then the child's own breath drives the monster (airflow sensor): the belly fills with the slurp's volume, each counted slurp drains a third of the milkshake with bubbles (`cfg.timing.drain`, 1.0 s), and the trial goes on when `cfg.child.slurps` (3) slurps have counted. No pacing. One timed breath was too hard to catch for a 4.5-year-old (first try, 2026-10-28). Without the sensor: the old timed animation (1.2 s in, 1.8 s out, x3). |
| Answer | participant clicks | **experimenter clicks** what the child says or points at |
| Feedback | none | practice: after every answer the two answer cards for 2.5 s, the correct one in a thick gold frame with a star badge (right: a gold tick and a sparkle; wrong: the chosen card fades, soft two notes); main trials: none by default (`cfg.feedback.main`), but a star flies into its slot for every answer (progress, not feedback). The tutorial demos show the reveal (the mouse pinching or asleep) |

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

**The airflow sensor is required by default** (`cfg.flow.enabled = true`,
`cfg.flow.feedback = "breath"`): the Physio Recorder's RRST preset starts
`flow_lsl.py`, which streams the SFM3019 as the LSL stream `Flow`. Right after the
marker stream, the task looks for `Flow` for `cfg.flow.timeout` (10 s), reads it for
1 s and prints either

```
Airflow sensor OK: 0.0 slm at rest
```

or stops with the problem and its fix (no stream: start the Physio Recorder or
`flow_lsl.py`; frozen, reversed, out of range or constant flow: the message names the
check). Nothing moves before this check passes.

```matlab
cd <repo>/task/RRST_kids
addpath('config');

% Try it without a device or a child: simulated device, child and airflow, small window, 5x faster
cfg = kidsConfig(); cfg.device.mock = true; cfg.smallWindow = true;
cfg.debug.simulateChild = [70 8 0.1 0.1];   % [threshold slope falseAlarm lapse]
cfg.debug.timeScale = 0.2;
cfg.markers.lsl = false;                     % optional: no LSL marker stream
runKidsRRST(cfg)

% With the device (stim laptop: through the USB hub) and the airflow sensor
cfg = kidsConfig(); cfg.device.port = "COM7";
runKidsRRST(cfg)

% Without the airflow sensor: the timed animation of the first version
cfg = kidsConfig(); cfg.flow.enabled = false; cfg.flow.feedback = "none";
runKidsRRST(cfg)
```

A simulated child always gets synthetic airflow (three 25-slm, 1.3-s breaths per
trial, 2.5 s apart, starting 0.5 s after Space), so it runs through the breath-driven
trial; a mock device uses the live stream if one appears within 2 s, else synthetic
airflow. Both print `*** SIMULATED FLOW ***`. `cfg.flow.feedback = "none"` with the
sensor on keeps the timed animation but still records every slurp.

### Without the Physio Recorder

`cfg.recording.mode = "standalone"` runs the task from MATLAB alone: no Physio
Recorder, no LabRecorder. Close the Physio Recorder (and SEK-ControlCenter) first, plug
in the SensorBridge, then:

```matlab
cd C:\Users\stim\Desktop\cannabodies\rrst-toolkit\task\RRST_kids
addpath('config');
cfg = kidsConfig(); cfg.device.port = "COM7"; cfg.recording.mode = "standalone";
runKidsRRST(cfg)
```

The first line says `STANDALONE recording`. If no `Flow` stream appears within 2 s the
task starts `plux-lsl\flow_lsl.py` itself, hidden (`flowStreamer`; `cfg.flow.streamer`
and `cfg.flow.streamerScript`, by default `plux-lsl` next to this toolkit) and prints
its PID and log file, waits up to `cfg.flow.timeout` for the stream, and runs the usual
`Airflow sensor OK` check; if the stream never comes it stops with the streamer's last
output (e.g. `SensorBridge not found`). A streamer that was already running is used and
left running. The task never waits for a recorder (`Standalone recording: the task
records flow and markers itself.`), keeps every flow sample it pulls (1 kHz) and every
marker it sends, also with `cfg.markers.lsl = false`, and stops the streamer it started
at the end, after Esc and after an error. Saved next to the `.mat`:
`result.flow` (`[t flowSlm]`), `result.markers` (table `t`, `label`) and `result.t0`
(trial `tStart` = 0), all on the GetSecs clock, and `<name>_flow.csv` (`t,flow`). The
markers also go to LSL when `cfg.markers.lsl` is on, so a recorder can run alongside.
No PLUX (ECG, respiration belt) in this mode: that needs the Physio Recorder. The data
are written at the end of the session (also after Esc or an error); if MATLAB itself is
killed, the session's flow is lost.

**Experimenter line.** Every screen carries one short line for the experimenter,
small at the bottom left (`kidsPrompt`), and the console prints it (`>>`) whenever it
changes: what is happening and which key goes on, e.g.
`PRACTICE 3 of 6. Space starts the slurps. The truth is shown after the answer.` or
`Trial 21 of up to 28 (Psi 15/20, catch 6/8). Space starts the slurps. No feedback; one star per answer.`
(a main trial's line never names the level; the counts are of the trials done). The
story's sentences, and after a practice answer the truth ("Yes! The mouse pinched
it!"), follow on a second line.

**Console during the session** (the experimenter's view; the child sees none of it):

```
>> Free slurps: let them breathe. Space when done.
Free slurp 1: 0.42 L, peak 18 slm.
Free slurp 2: 0.12 L, peak 11 slm (small; sets the reference).
Reference slurp 0.42 L (median of 6 free slurps: 0.42 L), peak 18 slm. Belly full at 0.17 L; a slurp counts above 0.11 L.
Practice 3 of 6: level 80, answered easy (no): wrong.
Practice round 1 NOT PASSED: 4 of 6 correct; only 4 correct, 5 needed; level 80 wrong (practice 3). Practice runs again.
Main trials: up to 28 (20 Psi + 8 catch). Early stop: SE < 8 after 20 Psi trials.
Trial 21: squishy (yes). Threshold 86.9 %, SE 7.1. Early stop: SE < 8 after 20 Psi trials; now SE 7.1 after 15 (5 more Psi trials needed).
Stopped early: SE 7.1 < 8 after 20 Psi trials (27 of up to 28 trials run). Threshold 86.9 %.
Slurp 1 counted: 0.35 L, peak 25 slm (1 of 3).
Slurp 2 too weak (0.05 L; a slurp counts from 0.11 L): not counted, try again.
No slurp seen for 8 s: mouthpiece in? Space = go on, x = repeat, Esc = abort
Slurp 3 lasted over 6 s: not counted. Flow is not returning to zero: check the circuit for a leak or a draught at the inlet.
Airflow stream lost: this trial finishes with the timed animation (flowLost). ...
Airflow stream is back.
```

The reference line comes at the end of free play (`kidsFreePlay`; with the tutorial
off, after the `cfg.practice.nFree` free trials): the reference volume is the median
of every free slurp the detector saw, counted or weak (`kidsSetReference`,
`kidsReferenceSlurps`: type `end` or `weak`, never `overlong` or `interrupted`),
clamped to 0.15-2 L. Before it exists a slurp counts only from 25 % of the 0.6 L
default, so a small child's free slurps can all be weak; they still set the reference,
and free slurps are never marked weak on screen (no try-again pose or sound: they are
the tutorial; the records and markers keep the type). After it, the belly is full at
`cfg.flow.bellyFraction` (40 %) of the reference, and a slurp counts from 25 % of it
and at least 0.10 L (`cfg.flow.minVolumeL`). If no free slurp was seen at all, the
default 0.6 L stays and the console says so (in red). A slurp longer than `cfg.flow.maxSlurpDur` (6 s) is not counted and the console
suggests a leak. If the stream is lost mid-session the trial finishes with the timed
animation (`flowLost`), the task looks for the stream again before each trial and
prints `Airflow stream is back.`; the session never stops because of airflow.

**Experimenter:** click the face the child chose (any button; the pointer shows only on
the answer screen, a white ring marks the face under it, and clicks in the middle strip are
ignored), or Left arrow / `n` = "easy" (no), Right arrow / `y` = "squishy" (yes). The chosen
face lights up for half a second so you can see what was recorded. `x` = bad breath (trial repeated later). Space = pause
(wedge to 0) and continue. Esc = abort (wedge parked open, data saved as `Aborted_`).
Space also moves on from each of the three story beats, from "Ready to slurp?", from
the tutorial's bridge (answer cards), from the cup tip (after the sticker) and from the
ready screen after a nap. **Free play:** Space ends it once at least one slurp was
seen; before that, hold Space for 1 s to go on anyway (no sensor, or a child who will
not breathe yet). **During the
slurps:** Space = go on to the question with the slurps so far (flagged
`shortSlurps`; with no slurp counted the trial is repeated later instead, answer
`noslurp`), `x` = bad breath (trial repeated later), Esc = abort.

**Session:** calibration with nobody on the tube (about 0.5 min) -> story (three beats)
-> tutorial (`cfg.tutorial`: free play at 0, sets the reference slurp; demo of the
mouse pinching at `cfg.tutorial.pinchLevel` (90) and asleep at 0, three slurps each,
no question, each followed by the reveal; the answer cards explained) -> 6 practice
trials, each followed by the feedback cards (90, 0, 90, 0, 85, 0; pass: 5 of 6 and both 90s
right; one retry, then the session ends as `PracticeFailed_`, which is itself an
outcome) -> up to 40 main trials (30 Psi + 10 catch; the run stops early once the SE
is below 8 after 20 Psi trials, so with catch trials it usually goes past trial 20)
with a 45-s nap every 10 -> sticker. About 15-20 s per
trial with the timed animation, so about 15-20 minutes in all; three real slurps take
6-8 s, so breath-driven trials are a little shorter. `cfg.tutorial.enabled = false`
brings back the two free trials instead (`cfg.practice.nFree = 2`,
`cfg.practice.levels = [0 0 80 0 80 0 75 0]`); the tutorial and free trials are one
or the other.

**Markers** (stream `RRST`; names match the adult task where the event exists). `n`
counts every trial run, free play, demos, free slurps and repeats included, so each
`n` is unique; it is `n` in the saved trials.

| Marker | Event |
|---|---|
| `RRST_ready` | stream opened at launch |
| `calibration_start`, `calibration_end` | calibration (nobody on the tube) |
| `story` | first story beat appears |
| `tutorial_start`, `freeplay_start` | free play starts (wedge at 0 confirmed) |
| `freeplay_end` | free play ends (Space) |
| `demo_pinch_level_<x>`, `demo_sleep_level_0` | a demo's wedge move confirmed (in place of `trial_<n>_level_<x>`); `trial_<n>_go` and the slurp markers follow |
| `tutorial_end` | Space on the bridge (answer cards) |
| `practice_start` | each practice round |
| `main_start` | "Ready" screen before the main trials appears |
| `trial_<n>_level_<x>` | wedge move confirmed; catch trials `level_0` |
| `trial_<n>_go` | experimenter's Space: slurps start |
| `slurp_<k>_onset` | slurp k starts (sample time of the onset); k numbers every slurp of the trial, counted or not |
| `slurp_<k>_end_<L>_<slm>` | slurp k counted: volume in L (2 decimals), peak in slm (sample time of the end) |
| `slurp_<k>_weak`, `slurp_<k>_overlong` | slurp k not counted (too small; longer than `cfg.flow.maxSlurpDur`). Free slurps send the detector's type too, though a weak free slurp is drunk on screen |
| `question` | answer screen appears (flip onset) |
| `answer_yes`, `answer_no`, `bad_breath`, `no_answer`, `pause` | experimenter's entry (`no_answer`: none in time) |
| `trial_<n>_correct` / `trial_<n>_wrong` | answered trials: "yes" on a load or "no" on a catch trial is correct |
| `rest_start`, `rest_end` | break; `rest_end` at the Space that resumes the trials |
| `aborted` / `done` | end of the run (`aborted`: Esc or an error; `done`: complete or practice failed) |

**Saved** to `data/raw/` (never committed): `RRSTkids_<ID>_<date>.mat` with the result
(every trial including repeats, practice, Psi posterior, bias flags, outcome; the
tutorial's free play and demos are in `result.practice` with `phase` "tutorial" and
`answer` "freeplay", "demo_pinch" or "demo_sleep"), the
configuration, and the device's full move log and transcript; and a `.csv` with one
row per trial. Prefixes: `MOCK_`, `SIM_`, `Aborted_`, `Error_`, `PracticeFailed_`.
Airflow per trial: in the `.mat`, `tr.slurps` holds every slurp the detector saw
(`onsetT`, `endT` on the GetSecs clock, `durationS`, `peakSlm`, `volumeL`, `counted`,
`type`: end, weak, overlong or interrupted); `vars.flowSource` is `live`, `simulated`
or `off`. The `.csv` has the summary columns `nSlurps` (counted slurps),
`slurpVolumeL` and `slurpPeakSlm` (means over the counted slurps, empty if none),
`shortSlurps` (Space ended the slurps before three counted) and `flowLost` (the
stream was lost during the trial); `slurpT` is the length of the slurp phase.

## Feedback

`cfg.feedback.practice` (default true) gives the child feedback after every practice
answer; `cfg.feedback.main` (default false) after every main answer too, before its
star. `cfg.feedback.style = "cards"` (default): for `cfg.timing.feedback` (2.5 s)
both answer cards stay as on the question screen; the **correct card** gets a thick
gold frame and a big star badge in its corner, and the chosen card keeps its white
frame.

- **Right:** a big gold tick pops up in the chosen card's top left corner, with the
  `star` sparkle.
- **Wrong:** the chosen card fades (its frame stays) and the mouse on the correct card
  shows the truth: it squeezes the straw twice, or a Z floats up from it asleep, with
  the soft `tryagain` notes. Never red or green, never a sad face.

The experimenter line says `Practice: right.` or `Practice: not right.`, then the truth
sentence. `cfg.feedback.style = "reveal"` brings back the earlier scene (the mouse
pinching or asleep in a spotlight, 1.5 s); the tutorial demos always use it, since
there is no answer to mark. Code: `kidsFeedbackBeat` (sequence and sound, pure),
`kidsFeedbackLayout` (geometry, pure), `kidsQuestion(scr, txt, answer, true, truth, p)`
(drawing), tested in `tests/TestKidsFeedback.m`.

## Poses

The child reads nothing: every state has a pose of the monster (`kidsPose`, drawn by
`kidsScene` from shapes) and a sound. `idle` (looks at the cup, blinks every 3 s)
while waiting; `ready` (looks at the child, eyebrows up, mouth open on a wiggling
straw) on "Ready to slurp?"; `slurp` (cheeks in, happy eyes, lines along the straw)
while the child inhales; `ahh` (eyes closed, smiling, bubbles) while a counted slurp
drains; `tryagain` (head tilt, one eyebrow up, never sad) while a weak or overlong
slurp's belly goes down (never in free play, the free trials or the demos); `celebrate` (arms up, grin) for a
full cup, the stretch after a nap and the sticker; `sleep` (Z's) during the nap;
`strain` (cheeks puffed, sweat drop) only in story beat 2, where the mouse pinches the
straw. Free play waits in `ready`. While the wedge moves the mouse runs from the left
to the cup (`toCup`, scamper sound), stands by it with a cheeky face (`cheeky`: upright,
eyes wide, a grin with two teeth, one paw waving; `squeak`) and hides behind the cup
(`hide`). The frames are drawn while the firmware moves (the device's `'WhileWaiting'`
callback), timed by `kidsMoveProgress`: at least `cfg.timing.moveMin` (1.5 s), as long
as the move takes (1.3-2.8 s on the real device, 2026-10-30) plus 0.5 s, and the mouse
never hides before the firmware has confirmed the move. The sequence is the same for
catch and loaded trials. Esc during a move ends the session once the move is
confirmed. The mouse
pinches (`pinch`) in the story, during the tutorial's pinch demo (the only time it is
seen pinching while the child breathes) and in the reveal of a loaded trial, and sleeps
(`sleep`) during the sleep demo and in the reveal of a catch trial. `kidsBeat` gives the scene, length and cue of each moment (story beats, move,
ready, reveal, star flight, cup tip and celebrate, nap, stretch, sticker);
`kidsSlurpPhase` the poses during the slurps. Every frame gets `t` (seconds since the
session started) and `flavour = cupsDone + 1` (pink, chocolate, mint, blueberry).
Catch and load trials look the same up to the question. The handbook page
(`handbook/v2/kids.md`) shows the key frames; `handbook/assets/img/kids/poses_contact_sheet.png`
shows every pose.

## Safety

- No level above `cfg.child.hardCap` is ever sent. `validateKidsConfig` rejects a cap
  above 100 (the full adult scale) and any configured level (grid, prior, practice,
  rest, start, pinch demo) above the cap; `kidsCheckLevel` checks every level again
  right before it goes to the device. The default cap is 100: Micah decided on
  2026-10-30 that the children's levels should not be restricted below the adult
  scale (full scale = barely possible to inhale, set per device at the bench).
- Calibration closes the wedge fully: do it before the child sits down (the script
  asks for that).
- Esc parks the wedge open; closing the port at the end disables the motor. The child
  can always take the mouthpiece out.
- The 85 % cap is a judgement from one adult (87.5 % was easy and not distressing).
  Children breathe with less flow, so the same obstruction gives less pressure drop;
  check 70-85 % on the flow rig and consider a lower cap for the first child.

## Files

- `runKidsRRST.m`: entry point (configuration, markers, airflow check, device, recorder check, calibration prompt).
- `config/kidsConfig.m`, `config/validateKidsConfig.m`.
- `code/kidsProcedure.m`, `kidsNextLevel.m`, `kidsRecord.m`, `kidsRequeue.m`,
  `kidsShouldStop.m`, `kidsSchedule.m`, `kidsFlags.m`, `kidsCheckLevel.m`: the
  procedure, tested in `tests/TestKids.m` with a simulated child.
- `code/kidsMain.m` (session), `kidsBeat.m` (scene, length and cue of each moment,
  pure; `tests/TestKidsBeat.m`), `kidsMoveProgress.m` (the move beat's clock, pure),
  `kidsPose.m` (geometry and poses, pure) and
  `kidsScene.m` (drawing, simple shapes only; `tests/TestKidsScene.m`),
  `kidsQuestion.m`, `kidsQuestionLayout.m` (answer screen; `tests/TestKidsQuestion.m`),
  `kidsFeedbackBeat.m`, `kidsFeedbackLayout.m` (the child's feedback;
  `tests/TestKidsFeedback.m`), `kidsText.m`, `kidsSave.m`.
- `code/kidsOpenMarkers.m`, `kidsWaitsForRecorder.m`, `kidsMarkerLabel.m`: LSL markers
  through the shared `task/helpers/rrstMarker.m`, tested in `tests/TestKidsMarkers.m`.
- `code/kidsPrompt.m`: the experimenter's line per moment, and `kidsRunReport.m`: the
  console's plan, estimate and stop reason for the main trials (both pure;
  `tests/TestKidsPrompt.m`).
- `code/kidsTutorialPlan.m` (the tutorial's steps, pure), `kidsFreePlay.m` (free
  play), `kidsSetReference.m`, tested in `tests/TestKidsTutorial.m`.
- `code/kidsSlurpPhase.m`: one trial's slurps, breath-driven or timed, and
  `kidsReferenceSlurps.m` (the free slurps that set the reference), tested in
  `tests/TestKidsSlurpPhase.m`; `code/kidsFlow.m` (breath detector), `kidsSimFlow.m`
  (synthetic airflow), `kidsBreathScale.m`, tested in `tests/TestKidsFlow.m`; the live
  stream through the shared `task/helpers/flowInlet.m`.
- Standalone recording: `code/kidsStandalone.m`, and the shared
  `task/helpers/flowStreamer.m` (starts and stops `flow_lsl.py`, reusable by the adult
  task) and `flowRecord.m` (the growing sample store behind `src.record`), tested in
  `tests/TestKidsStandalone.m`.
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
`bubbles`, `star` (sparkle), `cup` (fanfare), `mouse` (scamper ticks), `squeak` (two
short rising chirps, the cheeky mouse) and `tryagain` (soft two notes a whole tone
down, neutral, never sad). Usage:

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
`snd.rainOn` (rain) say what is playing. `kidsMain` uses it instead of
`startMaskingNoise` (never both): `ready` on "Ready to slurp?" (also after a nap),
`mouse` while the wedge moves, in story beat 2 and in the reveal of a loaded trial,
`squeak` when the mouse stands by the cup, `slurp` at a slurp's onset, `bubbles` when
it counts (and for every free slurp but an overlong one), `tryagain` when it does not
(never in the free trials) and after a wrong answer, `star` when the star flies and
after a right answer, `cup` when the cup tips. A cue at its peak over a
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

- Never run with a child. Three adult runs on the real device: 2026-10-28 (timed
  animation), 2026-10-30 (breath feedback; every slurp detected, aborted in the
  second practice round, which led to the tutorial and the experimenter line) and
  2026-10-30 again (20 main trials with the tutorial; its three reports led to the
  mouse's run during the move, the feedback cards and the trial counts, see
  `handbook/v2/kids.md`). The feedback cards, the cheeky mouse and the counts have run
  only in unattended mock sessions. Next: `docs/kids_pilot_protocol_2026-10-30.md`.
- Cue sounds have run without error on the stim PC (2026-10-30, nobody listening);
  not heard by a child, and their timing and loudness over the rain have not been
  checked by ear.
- Breath-driven trials have run with one adult breathing (2026-10-30, practice
  only: 3 of 3 slurps detected on every trial, no weak, no false onset); the feedback
  on versus off comparison (plan step 6, which also checks the fill-speed leak) is
  still to do.
- The lag from breath to screen is not measured yet (`TODO(measure)` in
  `handbook/shared/airflow-sensor.md`; `bench/flowFeedbackCheck`).
- The monster and the mouse are drawn from shapes in code (`kidsPose`/`kidsScene`), not
  sprites; the plan's sprite textures (U3) are not done.
- The answer screen (`kidsQuestion.m`) repeats drawing helpers of `kidsScene.m`
  (monster face, mouse poses); keep them in step until they are shared.
- Esc pressed while the wedge moves is acted on once the firmware has confirmed the
  move (the reply is always read), so it can take up to a move's length (about 3 s).
- Translations; the colours and drawings have not been seen by a child.
- Design questions from the spec: the cap, what to report when a child's threshold
  is above the cap (practice fails), and whether mouth pressure should be recorded
  to flag weak slurps objectively.
