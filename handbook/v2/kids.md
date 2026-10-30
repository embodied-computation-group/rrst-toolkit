# Kids version (in development)

!!! warning "In development: not for use with children yet"
    RRST-Kids ("Milkshake Monster") has run on the real device with one adult tester
    only: once before the breath-driven version, twice with it (aborted in practice,
    see [First real run with feedback](#first-real-run-with-feedback-2026-10-30-adult);
    then 20 main trials, see
    [Second run with feedback](#second-run-with-feedback-2026-10-30-adult-20-main-trials)).
    The feedback cards and the mouse's run to the cup have run only in mock sessions,
    the cue sounds have not been checked by ear, the child-facing
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

**Stars are progress, not feedback:** one per answer, right or wrong, toward a cup and
a sticker. Because they say nothing about the answer they are shown in every run,
feedback on or off.

**The tutorial** comes between the story and the practice: free play (the child slurps
as often as they like and watches the belly fill), two demos with no question (three
slurps with the mouse pinching the straw at 90 %, then three with it asleep at 0, each
followed by its reveal), and a bridge screen with the two answer cards, "Now you say:
did the mouse pinch?", for the experimenter to explain. Only then does the practice
ask.

| | Adult RRST 2.0 | Kids |
|---|---|---|
| Judgement | 2 breaths, which was harder (2AFC) | 3 breaths at one level, yes/no ("did the mouse pinch?") |
| Bias | none modelled | yes-bias (guess rate 0-0.5) estimated and marginalised |
| Catch trials | none | 10 at level 0, never first, never two in a row |
| Levels | 0-100 % | 0-100 % in 5 % steps; a configurable cap (`cfg.child.hardCap`, default 100) is enforced at launch and before every move |
| Start | Psi's choice | 70 % |
| Jumps | any | at most 15 % above the highest level so far |
| Trials | set by the study | 30 Psi + 10 catch, so up to 40 (plus repeats); stops early when SE < 8 after 20 *Psi* trials, so with catch trials a run goes past trial 20. The experimenter line counts them: `Trial 21 of up to 28 (Psi 15/20, catch 6/8)` |
| Breathing | timed inhale cue | experimenter starts the trial; the **child's breath drives the screen** (airflow sensor): the belly fills with the slurp, each slurp that counts drains a third of the milkshake. The trial goes on after 3 counted slurps; Space ends them early. Without the sensor: a timed animation (1.2 s in, 1.8 s out, x3) |
| Answer | participant clicks | **experimenter clicks** one of two equally nice scene cards ("easy": the mouse asleep; "squishy": the mouse pinching), the one the child names or points at |
| Feedback | none | practice: after every answer, the two answer cards for 2.5 s with the **correct card in a thick gold frame and a star badge**; right: a gold tick and a sparkle; wrong: the chosen card fades and the mouse on the correct card squeezes the straw (or a Z floats up from it asleep), soft two notes. Main trials: none by default (`cfg.feedback.main = true` turns the cards on), but a star flies into its slot for every answer, right or wrong. Tutorial demos: the reveal (the mouse pinching or asleep) |

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
  least 0.10 L. A counted slurp drains over 1 s (`cfg.timing.drain`); the next one
  can start at once. A smaller one is "weak": the belly goes down, nothing drains, the
  monster tilts its head ("hmm?", never sad) with a soft two-note sound, and the
  child simply slurps again. A "slurp" longer than 6 s is a leak or draught, not
  counted.
- **The reference slurp** is set by the tutorial's free play: the median volume of
  every slurp the sensor saw there (counted or weak), clamped to 0.15-2 L. Before it
  exists the default is 0.6 L, so a small child's free slurps can all be weak against
  it; they still set the reference, and free play never shows the "try again" pose.
  When the glass is empty a new one stands there; Space ends free play once the child
  has slurped (hold Space 1 s to go on without a slurp).

## A trial, frame by frame

The child's screen has no text to read: every state has a pose and a sound. The
small bottom-left line is for the experimenter: first what is happening and which key
goes on (`PRACTICE 3 of 6. Space starts the slurps. ...`, `Trial 21 of up to 28 (Psi
15/20, catch 6/8). Space starts the slurps. No feedback; one star per answer.`; the
counts are of the trials done), then the story's sentence or the truth after a
practice answer. The console prints the same line.

| | |
|---|---|
| ![Story, beat 1](../assets/img/kids/01_story.png) | **Story, beat 1.** Shown once, in three beats; Space moves on from each, so the experimenter tells the story over them. The monster slurps happily, the milkshake drains, then "ahh" with bubbles. Stars (top) and cups (top right) show progress. |
| ![Story, beat 2](../assets/img/kids/14_story2.png) | **Story, beat 2.** The mouse pinches the straw (scamper sound); the monster strains, cheeks puffed. Beat 3: the mouse runs off and the monster relaxes. |
| ![Free play](../assets/img/kids/15_freeplay.png) | **Tutorial, free play.** Wedge at 0. The monster waits in its ready pose; every slurp fills the belly and drinks a third of the glass, and an empty glass is replaced at once. The child slurps as often as they like; Space ends it after at least one slurp. Every slurp sets the reference. |
| ![Demo, mouse pinching](../assets/img/kids/16_demo_pinch.png) | **Tutorial, demo 1.** The wedge at 90 % and the mouse pinching the straw *while* the child slurps three times: the only time the pinch is seen during breathing. Then the reveal. Demo 2 is the same at 0 with the mouse asleep. Then the two answer cards, explained, and the practice. |
| ![Mouse by the cup](../assets/img/kids/02_mouse.png) | **Mouse.** While the wedge moves, the mouse runs from the left along the ground to the cup (scamper sound), stops by it with a cheeky face (upright, eyes wide, a grin, one paw waving; a squeak), then hops behind the cup. It animates for the whole move: the frames are drawn while the firmware moves, at least 1.5 s and until 0.5 s after the move is confirmed, and the mouse hides only once the wedge is in place. On catch trials the wedge moves to 0; the screen is the same. |
| ![Ready](../assets/img/kids/03_cue.png) | **Ready to slurp?** The monster looks at the child, eyebrows up, mouth open on a wiggling straw, with a chime. When the child has the mouthpiece in and is ready, the experimenter presses Space. |
| ![Slurp](../assets/img/kids/04_inhale.png) | **Slurp.** As soon as the child inhales, the monster slurps (cheeks in, happy eyes, lines running up the straw) and the belly fills with the breath. |
| ![Ahh](../assets/img/kids/05_exhale.png) | **Ahhh.** When the slurp ends and counts, a third of the milkshake drains, bubbles rise and the belly goes down. After the third counted slurp the question comes; the child takes them at their own pace (6-8 s for three). |
| ![Question](../assets/img/kids/06_question.png) | **Question.** "Did the mouse pinch the straw?" Two equally bright scene cards: the mouse asleep ("easy") and the mouse pinching ("squishy"), a cheerful monster on both. The child says or points; the experimenter clicks that card. A white ring marks the card under the pointer. |
| ![Answer registered](../assets/img/kids/07_answered.png) | **Answer registered.** The chosen card is framed and the other fades for 0.5 s. |
| ![Practice feedback, right](../assets/img/kids/08_feedback.png) | **Practice feedback, right.** After every practice answer, for 2.5 s: the two cards stay, the correct card gets a thick gold frame and a big star badge, the chosen card keeps its white frame. Right: a big gold tick pops up on it, with a sparkle. Here the child said "squishy" and the mouse did pinch. |
| ![Practice feedback, wrong](../assets/img/kids/17_feedback_wrong.png) | **Practice feedback, wrong.** The child said "squishy" on a catch trial: the gold frame and star go to "easy", the chosen card fades, and on the correct card a Z floats up from the sleeping mouse (on a loaded trial the mouse squeezes the straw twice), with soft two notes. No red or green, no sad face. The experimenter line says `Practice: not right. The gold card shows the truth.` and the truth sentence. Main trials get the same with `cfg.feedback.main = true`. |
| ![Demo reveal, asleep](../assets/img/kids/13_reveal.png) | **Demo reveal.** After each tutorial demo (there is no answer to mark) the mouse is shown pinching the straw or, as here, asleep under the table, in a spotlight, for 1.5 s. `cfg.feedback.style = "reveal"` uses this for the practice too, as before 2026-10-30. |
| ![Star](../assets/img/kids/09_star.png) | **Star.** Main trials: for every answer, right or wrong, a star flies from the monster's belly into the next slot, with a sparkle. Stars count answers, not correct answers, so they are shown in every run. |
| ![Cup finished](../assets/img/kids/10_cupdone.png) | **Cup finished.** The tenth star: the empty glass tips into the done row at the top right (fanfare), then the monster dances with its arms up and a new milkshake in the next flavour (pink, chocolate, mint, blueberry). Give a sticker, then Space. |
| ![Rest](../assets/img/kids/11_rest.png) | **Rest.** Every 10 trials the monster naps (Z's) for 45 s while a bar drains; then it stretches, and "Ready to slurp?" comes back. Space goes on. |
| ![Done](../assets/img/kids/12_done.png) | **Done.** The monster celebrates. |

During the slurps the monster waits with an idle face (looking at the cup, blinking)
until the child inhales. A weak slurp gets the head-tilt "try again" pose while the
belly goes down; a time-out (8 s without a slurp) only prompts the experimenter, on
the console.

## Session

1. **Calibration**, before the child sits down: tube in, nobody on the mouthpiece. The
   wedge closes fully once (about 0.5 min).
2. **Story** (three beats), then the **tutorial**: free play (sets the reference
   slurp), the pinch demo at 90 and the sleep demo at 0 (three slurps each, no
   question, each followed by the reveal), the answer cards explained.
3. **Practice**: 6 trials (90, 0, 90, 0, 85, 0), each followed by the feedback cards,
   marked `PRACTICE k of 6` on the experimenter line. Pass: 5 of 6 right, including both 90s.
   The console prints every practice answer and, after each round, whether it passed
   and why not. One retry; a second failure ends the session as `PracticeFailed_`,
   which is itself a result.
4. **Main trials**: up to 40 (30 Psi + 10 catch), a nap every 10. The run stops early
   once the threshold's SE is below 8 after 20 *Psi* trials; catch trials do not count,
   so it usually goes past trial 20. The console prints the plan at the start, after
   every answer the threshold, its SE and where the early stop stands, and at the end
   why the run stopped. With breath-driven slurps a trial is about 12-15 s.
5. **Sticker.** About 12-20 minutes in all.

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

**Without the Physio Recorder.** `cfg.recording.mode = "standalone"` runs the task
from MATLAB alone: close the Physio Recorder, then
`cfg = kidsConfig(); cfg.device.port = "COM7"; cfg.recording.mode = "standalone"; runKidsRRST(cfg)`.
The first console line says `STANDALONE recording`. With no `Flow` stream running the
task starts `flow_lsl.py` itself, hidden, and stops it at the end (also after Esc or an
error); one already running is used and left alone. It never waits for a recorder, and
saves every flow sample and marker it sees in the `.mat` (`result.flow`,
`result.markers`) and in `<name>_flow.csv`. There is no PLUX (ECG, belt) in this mode.

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
Main trials: up to 28 (20 Psi + 8 catch). Early stop: SE < 8 after 20 Psi trials.
Trial 21: squishy (yes). Threshold 86.9 %, SE 7.1. Early stop: SE < 8 after 20 Psi trials; now SE 7.1 after 15 (5 more Psi trials needed).
Stopped early: SE 7.1 < 8 after 20 Psi trials (27 of up to 28 trials run). Threshold 86.9 %.
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

- No level above `cfg.child.hardCap` (default 100, the full adult scale; Micah, 2026-10-30: no restriction below it) is ever sent.
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

## First real run with feedback (2026-10-30, adult)

The experimenter, real device, breath feedback on, sensor live. "Very cute, huge
improvement." Every slurp was detected: 3 of 3 on every trial, 1.2 to 2.0 L and 83 to
137 slm per slurp, no weak slurp, no false onset. The run never reached the main
trials: practice round 1 failed at 80 % ("easy" answered twice at 80, both must-pass
trials), round 2 started, and the run was aborted from boredom. What went wrong was the
framing, not the detector:

- The experimenter did not know they were in practice, so the reveal ("the mouse was
  present / absent") made no sense: "it was not clear why it was telling me the mouse
  was present or absent if this is a no-feedback run".
- "It should say press space to continue when needed."
- "It's not clear what the stars represent or if they need to be shown on no-feedback
  runs."
- "We should build a quick intro tutorial."
- Three slurps took about 12 s per trial: the drain-and-bubbles animation after each
  slurp (1.8 s, the timed fallback's exhale) plus the breaths.

Changed in response: the experimenter line on every screen and the console
(`PRACTICE k of n`, `Trial n`, which key goes on), the tutorial (free play, the two
demos, the answer cards), stars explained above, and a 1.0 s drain
(`cfg.timing.drain`). Not changed: the practice levels, the pass rule and the cap.
An adult failing practice at 80 % was near threshold (the first adult pilot's
threshold was 79 %); practice is now 90/90/85 and the cap is full scale. The round outcome is visible on the
console with the reason.

## Second run with feedback (2026-10-30, adult, 20 main trials)

The experimenter again, real device, breath feedback on, the tutorial and 20 Psi + 8
catch trials configured. Threshold 86.9 % (SE 7.1), slope 5.8, yes-bias 0.11, 0 of 5
false alarms on catch trials, practice 11 of 12 right, 13.5 minutes in all. Peak flow
fell from about 85 slm at 0 to 35 slm at 95 %. Three reports:

- **"The mouse is not animating during the wedge move; it should run over to the drink
  and make a cheeky face and noise during this period and actually animate."** The
  move waited for the firmware (1.3 to 2.8 s per trial) before the mouse's 1.5 s
  animation, so almost none of it was left and the mouse jumped to the end. Now the
  device layer calls back on every poll while the firmware moves (`'WhileWaiting'` on
  `rrst.Device.moveTo` and `rrst.Stimulator.present`/`null`/`rest`/`park`; the
  firmware's reply stays the source of truth), and the mouse runs to the cup, stops
  with a cheeky face and a squeak, and hides behind the cup, for as long as the move
  takes and at least 1.5 s; it hides only after the move is confirmed.
- **"The feedback in the training is super weird and only in the text given to the
  experimenter; there should be clear, easy-to-understand visual feedback for the
  participant."** The reveal (the mouse in a spotlight, the cup empty) did not say
  which answer was right. Now the practice shows the two answer cards with the correct
  one in gold, a star badge, a tick when right, the chosen card faded when wrong (see
  the frames above). `cfg.feedback.main` gives the same in the main trials;
  `cfg.feedback.style = "reveal"` keeps the old scene.
- **"It said trial 21 and ran a 3rd break block when it should have ended after 20
  trials."** Not a bug: 20 Psi + 8 catch is up to 28 trials, and the early stop needs
  20 *Psi* trials (15 had run by trial 21). The experimenter could not see that; now
  the line says `Trial 21 of up to 28 (Psi 15/20, catch 6/8)` and the console prints
  the plan, the estimate after every answer and why the run stopped.

## First child (2026-10-30, 4.5 years, usability)

The experimenter's own daughter, real device, breath feedback on, standalone recording,
the Session B settings of the pilot protocol (start level 60, 15 Psi + 5 catch). She
went through the story, free play, both demos and one practice trial, then got bored
and the run was stopped with Esc at the first catch trial, about 2.5 minutes after free
play began (Halloween was the competition). "Fun", by both. Not a measurement of the
child: a measurement of the game. Archive: `bench/sessions/child-kids__device_2E4441D76D5F2996__2026-10-30_1534/`.

What the sensor saw:

- **Free play:** four slurps of 0.19 to 0.52 L at 17 to 37 slm, a fifth cut off by
  Space. Reference slurp 0.28 L (the median), so the belly was full at 0.11 L and a
  slurp counted above 0.10 L: the absolute floor was the binding rule (25 % of the
  reference is 0.07 L).
- **Pinch demo at 90:** thirteen onsets in nine seconds. Four counted (0.11 to 0.24 L),
  eight weak (0.01 to 0.07 L, 0.1 to 0.3 s each), one cut off. Against the
  obstruction she took rapid short sniffs instead of one slurp; the demo shows no
  "weak" on screen (by design), so nothing told her to slurp longer.
- **Sleep demo at 0:** 0.65 and 0.78 L at 64 to 72 slm, more than twice her free-play
  slurps. By then she had learned to pull hard.
- **Practice trial 1 at 90:** three slurps of 0.57 to 0.71 L at 48 to 58 slm, answered
  "easy" (wrong). Her peak flow fell by about a quarter between level 0 and 90; the
  adult tester's fell from about 85 to 35 slm between 0 and 95 (second run above).
- **Detector:** every breath found, no false onset, the exhale through the T-valve never
  triggered.

**Read this run narrowly.** She was excited and barely following the instructions, so
nothing here is evidence about what a child can perceive, and her one wrong answer at
level 90 is not data. What it does show is that the machinery ran on a small child's
breathing:

1. **The detector held.** Every real breath was found, no false onset, the exhale
   through the T-valve never triggered one. That was the main thing to find out.
2. **The 0.10 L floor, not the 25 % rule, decided what counted** at her 0.28 L
   reference. Her counted slurps against the obstruction were 0.11 to 0.24 L, so a
   higher floor would have called them weak. One child, so this sets no value; it
   does say the floor is in the right region.
3. **Short sniffs against the obstruction.** Her breaths at level 90 were 0.1 to 0.3 s
   bursts rather than one slurp. The demos accept whatever comes, but in practice and
   main trials those would be "weak" and would trigger the try-again pose. Worth
   watching next time, before deciding it needs a change.
4. **Flow numbers, for the record.** Peak flow 17 to 37 slm in free play, 64 to 72 at
   level 0 in the sleep demo, 48 to 58 at level 90. Noted because a child's flow is
   what sets the pressure drop across the wedge, and the scale's anchors are measured
   at an adult's; whether that matters needs a child who is actually doing the task.

To fill in from the observation sheet (Micah), when a session is calm enough to judge
any of it: did she breathe on the ready cue without a prompt; did she look at the
belly; sucking or blowing; how she answered and whether "squishy" landed; her reaction
to the mouse, the star and the sounds.

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
- **The minimum slurp for a child.** 25 % of the reference and at least 0.10 L were
  guesses. The first child (2026-10-30) had a 0.28 L reference, so the 0.10 L floor
  was the rule that counted; her counted slurps against the obstruction were 0.11 to
  0.24 L. One child: the floor looks right, the fraction is untested.
- **Is the adult scale the right scale for a child?** The anchors are measured at an
  adult's flow, and the pressure drop across the wedge depends on the flow through it,
  so the same wedge position need not be the same stimulus for a child. Nothing
  measures this yet: the one child so far was not doing the task. Open until a child
  completes a run, or a bench measurement of pressure against flow at fixed wedge
  positions settles it directly. `{{CHILD_SCALE}}` in `kidsConfig` stays the adult
  scale until then.
- **The cap** was 85 % from one adult run until 2026-10-30, when Micah set it to the
  full scale (100): children breathe with less flow, so the same obstruction gives
  less pressure drop, and a cap below full scale left high thresholds unmeasurable.
  `cfg.child.hardCap` remains for any site that wants one. Practice moved from
  80/80/75 to 90/90/85 the same day, after an adult missed two of three at 80.
- **The "low hit rate" flag was dropped** on 2026-10-30: it misfired for thresholds
  near or above 80 % (43 % of simulated children there, and both adult pilots). Only
  false alarms flag a session now; the hit rate at and above 80 is still reported.
- **The false-alarm flag is noisy** with about 8 catch trials; more catch trials or a
  rule based on the estimated guess rate would be steadier.
- Translations (Swiss German, Danish). The cue sounds' loudness over the rain is still
  to be checked by ear. The lag from breath to screen is still to be measured
  (`TODO(measure)` in [Airflow sensor](../shared/airflow-sensor.md#live-feedback-check)).
