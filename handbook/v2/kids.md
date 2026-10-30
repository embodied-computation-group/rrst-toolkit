# Kids version (in development)

!!! warning "In development: not for use with children yet"
    RRST-Kids ("Milkshake Monster") has run on the real device with one adult tester
    only, before the breath-driven version. The breath feedback has run only with
    synthetic airflow, the cue sounds have not been checked by ear, the child-facing
    text is English only, and the 85 % cap has not been checked on a flow rig (see
    [Open questions](#open-questions)). It lives on the `kids-variant` branch, in
    `task/RRST_kids/`. The next step is the pilot protocol in
    `docs/kids_pilot_protocol_2026-10-30.md`: an experimenter self-test, then one
    child as a usability check.

A child-friendly RRST for children of about 4-5 years, on the same device and device
layer as RRST 2.0, with the airflow sensor driving the screen.

## The task

A purple monster drinks milkshake through a long straw (the mouthpiece). A cheeky
mouse sometimes pinches the straw, so the slurp feels "squishy". **On each trial the child
takes three slurps at the same level and says whether the mouse pinched the straw**: a
yes/no detection task, not the adult two-breath comparison. The experimenter starts the
slurps when the child is ready, and then **the child's own breath drives the monster**:
the airflow sensor sees each slurp, the belly fills, and the milkshake drains a third
per slurp. Nothing is paced, so there is no timed cue to catch. Every answer earns a
star; ten stars finish a milkshake and earn a real sticker from the experimenter.

| | Adult RRST 2.0 | Kids |
|---|---|---|
| Judgement | 2 breaths, which was harder (2AFC) | 3 breaths at one level, yes/no ("did the mouse pinch?") |
| Bias | none modelled | yes-bias (guess rate 0-0.5) estimated and marginalised |
| Catch trials | none | 10 at level 0, never first, never two in a row |
| Levels | 0-100 % | 0-85 % in 5 % steps, **hard cap 85 %** |
| Start | Psi's choice | 70 % |
| Jumps | any | at most 15 % above the highest level so far |
| Trials | set by the study | 30 Psi + 10 catch; stops early when SE < 8 after 20 Psi trials |
| Breathing | timed inhale cue | experimenter starts the trial; the **child's breath drives the screen** (airflow sensor): the belly fills with the slurp, each slurp that counts drains a third of the milkshake. The trial goes on after 3 counted slurps; Space ends them early. Without the sensor: a timed animation (1.2 s in, 1.8 s out, x3) |
| Answer | participant clicks | **experimenter clicks** one of two equally nice scene cards ("easy": the mouse asleep; "squishy": the mouse pinching), the one the child names or points at |
| Feedback | none | practice: the truth after every trial, shown (the mouse pinching or asleep); main trials: a star flies into its slot for every answer |

Why yes/no: a 4-year-old struggles to hold two breaths in memory and compare them.
The cost is that the threshold is a detection threshold that absorbs the child's
yes-bias, not directly comparable to the adult 2AFC threshold, and yes/no needs more
trials for the same precision.

## How the breath drives the screen

The SFM3019 at the circuit inlet streams flow over LSL (stream `Flow`, see
[Airflow sensor](../shared/airflow-sensor.md)). The task reads it and detects each
**slurp**: flow above 3 slm for 50 ms starts one, below it for 150 ms ends it. The
T-valve's small backflow after each breath is negative and never starts a slurp.

- **The belly** shows the current slurp's volume, but saturates: it is full at 40 % of
  the child's reference slurp, so loaded and unloaded slurps both fill it. The screen
  must show *that* the child slurped, not *how hard* it was, or the child could answer
  from the picture instead of the feeling.
- **The milkshake** drains a fixed third per counted slurp, on the slurp's end, with
  bubbles. Never in proportion to the flow.
- **A slurp counts** when its volume is at least 25 % of the reference slurp and at
  least 0.10 L. A smaller one is "weak": the belly goes down, nothing drains, the
  monster tilts its head ("hmm?", never sad) with a soft two-note sound, and the
  child simply slurps again. A "slurp" longer than 6 s is a leak or draught, not
  counted.
- **The reference slurp** is set by the two free trials at the start of practice
  (three slurps each, no question): the median volume of every free slurp the sensor
  saw (counted or weak), clamped to 0.15-2 L. Before it exists the default is 0.6 L, so a small child's free slurps can
  all be weak against it; they still set the reference, and the free slurps never show
  the "try again" pose: they are the tutorial.

## A trial, frame by frame

The child's screen has no text to read: every state has a pose and a sound. The
sentence in the bottom-left corner is for the experimenter.

| | |
|---|---|
| ![Story, beat 1](../assets/img/kids/01_story.png) | **Story, beat 1.** Shown once, in three beats; Space moves on from each, so the experimenter tells the story over them. The monster slurps happily, the milkshake drains, then "ahh" with bubbles. Stars (top) and cups (top right) show progress. |
| ![Story, beat 2](../assets/img/kids/14_story2.png) | **Story, beat 2.** The mouse pinches the straw (scamper sound); the monster strains, cheeks puffed. Beat 3: the mouse runs off and the monster relaxes. |
| ![Mouse running](../assets/img/kids/02_mouse.png) | **Mouse.** The mouse scampers along the bottom (scamper sound) while the wedge moves, at least 1.5 s. On catch trials the wedge moves to 0; the screen is the same. |
| ![Ready](../assets/img/kids/03_cue.png) | **Ready to slurp?** The monster looks at the child, eyebrows up, mouth open on a wiggling straw, with a chime. When the child has the mouthpiece in and is ready, the experimenter presses Space. |
| ![Slurp](../assets/img/kids/04_inhale.png) | **Slurp.** As soon as the child inhales, the monster slurps (cheeks in, happy eyes, lines running up the straw) and the belly fills with the breath. |
| ![Ahh](../assets/img/kids/05_exhale.png) | **Ahhh.** When the slurp ends and counts, a third of the milkshake drains, bubbles rise and the belly goes down. After the third counted slurp the question comes; the child takes them at their own pace (6-8 s for three). |
| ![Question](../assets/img/kids/06_question.png) | **Question.** "Did the mouse pinch the straw?" Two equally bright scene cards: the mouse asleep ("easy") and the mouse pinching ("squishy"), a cheerful monster on both. The child says or points; the experimenter clicks that card. A white ring marks the card under the pointer. |
| ![Answer registered](../assets/img/kids/07_answered.png) | **Answer registered.** The chosen card is framed and the other fades for 0.5 s. |
| ![Practice reveal, pinch](../assets/img/kids/08_feedback.png) | **Practice reveal.** Practice only, after every answer: the truth for 1.5 s. On a loaded trial the mouse is shown pinching the straw, in a spotlight, with the scamper sound... |
| ![Practice reveal, asleep](../assets/img/kids/13_reveal.png) | **...and on a catch trial it is asleep under the table.** |
| ![Star](../assets/img/kids/09_star.png) | **Star.** Main trials: for every answer, right or wrong, a star flies from the monster's belly into the next slot, with a sparkle. |
| ![Cup finished](../assets/img/kids/10_cupdone.png) | **Cup finished.** The tenth star: the empty glass tips into the done row at the top right (fanfare), then the monster dances with its arms up and a new milkshake in the next flavour (pink, chocolate, mint, blueberry). Give a sticker. |
| ![Rest](../assets/img/kids/11_rest.png) | **Rest.** Every 10 trials the monster naps (Z's) for 45 s while a bar drains; then it stretches, and "Ready to slurp?" comes back. Space goes on. |
| ![Done](../assets/img/kids/12_done.png) | **Done.** The monster celebrates. |

During the slurps the monster waits with an idle face (looking at the cup, blinking)
until the child inhales. A weak slurp gets the head-tilt "try again" pose while the
belly goes down; a time-out (8 s without a slurp) only prompts the experimenter, on
the console.

## Session

1. **Calibration**, before the child sits down: tube in, nobody on the mouthpiece. The
   wedge closes fully once (about 0.5 min).
2. **Story** (three beats), then **practice**: 2 free trials of three slurps without a
   question (they set the reference slurp), then 6 trials (80, 0, 80, 0, 75, 0), each followed by
   the reveal. Pass: 5 of 6 right, including both 80s. One retry; a second failure ends
   the session as `PracticeFailed_`, which is itself a result.
3. **Main trials**: up to 40, a nap every 10. With breath-driven slurps a trial is
   about 12-15 s.
4. **Sticker.** About 12-20 minutes in all.

## Running it

**First, start the Physio Recorder** with the **RRST** preset and check the signals,
as for the adult task ([Running the 2.0 task](running.md),
[Recording physiology and airflow](../shared/recording.md)). The preset starts the
flow stream (`flow_lsl.py`); the task opens the `RRST` marker stream at launch and the
recorder starts recording when it appears. A real session holds before calibration
with **NOTHING IS RECORDING** until a recorder is connected.

**The airflow sensor is required by default.** At launch the task looks for the
`Flow` stream (10 s), reads it for 1 s with nobody breathing, and either prints
`Airflow sensor OK: 0.0 slm at rest` or stops with the problem and its fix (no
stream: start the Physio Recorder or `flow_lsl.py`; frozen, reversed, out of range or
constant flow: the message names the check). Nothing moves before this check passes.

```matlab
cd <repo>/task/RRST_kids
addpath('config');

% With the device (on the stim laptop it's COM7, through the USB hub) and the sensor
cfg = kidsConfig(); cfg.device.port = "COM7";
runKidsRRST(cfg)

% Without the airflow sensor: the timed animation, no breath feedback
cfg = kidsConfig(); cfg.device.port = "COM7";
cfg.flow.enabled = false; cfg.flow.feedback = "none";
runKidsRRST(cfg)

% Without a device or a child: simulated device, child and airflow, small window, 5x faster
cfg = kidsConfig(); cfg.device.mock = true; cfg.smallWindow = true;
cfg.debug.simulateChild = [70 8 0.1 0.1];   % [threshold slope falseAlarm lapse]
cfg.debug.timeScale = 0.2;
cfg.markers.lsl = false;                     % no LSL needed for a test run
runKidsRRST(cfg)
```

`cfg.flow.feedback = "none"` with the sensor on keeps the timed animation but still
records every slurp (the comparison run of the pilot protocol). MATLAB asks for the
child ID, then for Enter once the tube is in and nobody is on the mouthpiece
(calibration).

**Console** (the experimenter's view; the child sees none of it):

```
Airflow sensor OK: 0.0 slm at rest
Free slurp 1: 0.14 L, peak 11 slm (1 of 3; small, sets the reference).
Reference slurp 0.15 L (median of 6 free slurps: 0.13 L), peak 11 slm. Belly full at 0.06 L; a slurp counts above 0.10 L.
Slurp 1 counted: 0.18 L, peak 13 slm (1 of 3).
Slurp 2 too weak (0.06 L; a slurp counts from 0.10 L): not counted, try again.
No slurp seen for 8 s: mouthpiece in? Space = go on, x = repeat, Esc = abort
Slurp 3 lasted over 6 s: not counted. Flow is not returning to zero: check the circuit for a leak or a draught at the inlet.
Airflow stream lost: this trial finishes with the timed animation (flowLost). ...
Airflow stream is back.
```

If no free slurp was seen at all, the reference stays at 0.6 L and the console says
so in red: check the mouthpiece. A lost stream never stops the session: the trial
finishes with the timed animation and the task looks for the stream again before the
next trial.

**Experimenter controls**

| Input | Effect |
|---|---|
| Click a card (any button) | That answer. Clicks in the middle strip are ignored. |
| Left arrow / `n` | "Easy" (no) |
| Right arrow / `y` | "Squishy!" (yes) |
| `x` | Bad breath: the trial is repeated later (also during the slurps) |
| Space | Moves on from each story beat, "Ready to slurp?" and after the nap. During the slurps: go on to the question with the slurps so far (flagged `shortSlurps`; with none counted the trial is repeated later). During a question: pause (wedge to 0) |
| Esc | Abort: wedge parked open, data saved as `Aborted_` |

## Data

Saved to `data/raw/` (never committed): `RRSTkids_<ID>_<date>.mat` (every trial
including repeats, practice, the Psi posterior, flags, configuration, the device's
move log and transcript) and a `.csv` with one row per trial. Prefixes: `MOCK_`,
`SIM_`, `Aborted_`, `Error_`, `PracticeFailed_`.

Airflow per trial: in the `.mat`, `tr.slurps` holds every slurp the detector saw,
counted or not: `onsetT` and `endT` (GetSecs clock), `durationS`, `peakSlm`,
`volumeL`, `counted`, and `type` (`end` counted, `weak`, `overlong`, or `interrupted`
by Space or Esc). `vars.flowSource` says whether the flow was `live`, `simulated` or
`off`. The `.csv` adds `nSlurps` (counted slurps), `slurpVolumeL` and `slurpPeakSlm`
(means over the counted slurps, empty if none), `shortSlurps` (Space ended the slurps
before three counted) and `flowLost` (the stream was lost during the trial); `slurpT`
is the length of the slurp phase. The recorder's `.xdf` has the flow with a marker at
every slurp's onset and end (`slurp_<k>_onset`, `slurp_<k>_end_<L>_<slm>`,
`slurp_<k>_weak`, `slurp_<k>_overlong`).

For a QC figure (trials with the threshold estimate, P("squishy") with the fitted
curve, response times, summary):

```matlab
qcKids("data/raw/RRSTkids_9001_2026-10-28_1712.mat")
```

## Safety

- No level above `cfg.child.hardCap` (85 % of the adult scale at most) is ever sent.
  The configuration is rejected at start if any level is above the cap, and every
  level is checked again right before it goes to the device.
- Calibration closes the wedge fully: do it before the child sits down.
- Esc parks the wedge open; closing the port at the end disables the motor. The child
  can always take the mouthpiece out.

## First adult pilot (2026-10-28)

One adult tester, real device, 2 blocks (21 main trials, 5 catch), stopped with Esc.
Timed animation (before the breath feedback). Practice 6/6 right. Threshold 79.2 %
(SE 4.7), yes-bias 0.28, false alarms 2 of 5 catch trials. The "unusable" flag fired
on hits at 80 % (1 of 3), the misfire described below.

![QC figure of the first adult pilot](../assets/img/kids/pilot_qc_2026-10-28_1712.png)

## Open questions

- **Does the breath feedback leak the level?** Peak flow and volume both fall with
  obstruction (bench 2026-10-28, one adult: 84 to 36 slm, 1.85 to 0.80 L between 0
  and 95 %). The belly saturates at 40 % of the reference slurp, so it fills on loaded
  slurps too, but it fills a little *slower* on them: that residual difference in fill
  speed could let a child answer from the picture. Check before any child sees the
  breath mode: an adult runs twice, feedback on (`cfg.flow.feedback = "breath"`) and
  off (`"none"`, sensor still recording), and compares catch-trial false alarms, the
  fitted guess rate, the threshold and its SE. A difference of more than two false
  alarms or a guess rate that moves by more than 0.15 calls for a second pair of runs
  (pilot protocol, Session A). `{{FLOW_FEEDBACK_MODE}}` stays "breath" unless that
  comparison says otherwise.
- **The minimum slurp for a child.** 25 % of the reference and at least 0.10 L are
  guesses; the first child's free slurps and weak count will tell.
- **The cap.** 85 % comes from one adult run. Children breathe with less flow, so the
  same obstruction gives less pressure drop; check 70-85 % on a flow rig. The adult
  tester's threshold was 79 %, close to the cap: a child whose threshold is above
  85 % cannot be measured, and what to report then is undecided.
- **The "low hit rate" flag misfires** for thresholds near 80 % (43 % of simulated
  children there were flagged). It should apply only when the estimated threshold is
  well below 80, or be dropped.
- **The false-alarm flag is noisy** with about 8 catch trials; more catch trials or a
  rule based on the estimated guess rate would be steadier.
- Translations (Swiss German, Danish). The cue sounds' loudness over the rain is still
  to be checked by ear. The lag from breath to screen is still to be measured
  (`TODO(measure)` in [Airflow sensor](../shared/airflow-sensor.md#live-feedback-check)).
