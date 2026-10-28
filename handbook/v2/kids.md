# Kids version (in development)

!!! warning "In development: not for use with children yet"
    RRST-Kids ("Milkshake Monster") has run on the real device with one adult tester
    only. The child-facing text is English only, the 85 % cap has not been checked on
    a flow rig, and two of its data-quality flags need redesign (see
    [Open questions](#open-questions)). It lives on the `kids-variant` branch, in
    `task/RRST_kids/`.

A child-friendly RRST for children of about 4-5 years, on the same device and device
layer as RRST 2.0.

## The task

A purple monster drinks milkshake through a long straw (the mouthpiece). A cheeky
mouse sometimes pinches the straw, so the slurp feels "squishy". **On each trial the child
takes three slurps at the same level and says whether the mouse pinched the straw**: a
yes/no detection task, not the adult two-breath comparison. The experimenter starts the
slurps when the child is ready, so the child never has to catch a timed cue. Every answer earns a star; ten stars finish a
milkshake and earn a real sticker from the experimenter.

| | Adult RRST 2.0 | Kids |
|---|---|---|
| Judgement | 2 breaths, which was harder (2AFC) | 3 breaths at one level, yes/no ("did the mouse pinch?") |
| Bias | none modelled | yes-bias (guess rate 0-0.5) estimated and marginalised |
| Catch trials | none | 10 at level 0, never first, never two in a row |
| Levels | 0-100 % | 0-85 % in 5 % steps, **hard cap 85 %** |
| Start | Psi's choice | 70 % |
| Jumps | any | at most 15 % above the highest level so far |
| Trials | set by the study | 30 Psi + 10 catch; stops early when SE < 8 after 20 Psi trials |
| Breathing | timed inhale cue | experimenter starts the trial; 3 slurps paced at 1.2 s in, 1.8 s out, not enforced; Space ends them early |
| Answer | participant clicks | **experimenter clicks** the face the child names or points at |
| Feedback | none | practice: the truth after every trial; main trials: a star for every answer |

Why yes/no: a 4-year-old struggles to hold two breaths in memory and compare them.
The cost is that the threshold is a detection threshold that absorbs the child's
yes-bias, not directly comparable to the adult 2AFC threshold, and yes/no needs more
trials for the same precision.

## A trial, frame by frame

| | |
|---|---|
| ![Story screen](../assets/img/kids/01_story.png) | **Story.** Shown once. The experimenter tells the story and presses Space. Stars (top) and cups (top right) show progress. |
| ![Mouse running](../assets/img/kids/02_mouse.png) | **Mouse.** The mouse scampers along the bottom while the wedge moves (at least 1.5 s). On catch trials the wedge moves to 0. |
| ![Ready](../assets/img/kids/03_cue.png) | **Ready to slurp?** The monster waits. When the child has the mouthpiece in and is ready, the experimenter presses Space. |
| ![Inhale](../assets/img/kids/04_inhale.png) | **Big slurp!** The belly grows and a third of the milkshake drains (1.2 s). |
| ![Exhale](../assets/img/kids/05_exhale.png) | **Ahhh.** The belly shrinks and bubbles rise (1.8 s). Then two more slurps, about 9 s in all. The child doesn't have to keep time with the monster; once they've had their slurps, Space goes straight to the question. |
| ![Question](../assets/img/kids/06_question.png) | **Question.** "Did the mouse pinch the straw?" The child says or points; the experimenter clicks that face. A white frame marks the face under the pointer. |
| ![Answer registered](../assets/img/kids/07_answered.png) | **Answer registered.** The chosen face is framed and the other fades for 0.5 s. |
| ![Practice feedback](../assets/img/kids/08_feedback.png) | **Practice feedback.** Practice only: the truth after every trial. |
| ![Star](../assets/img/kids/09_star.png) | **Star.** Main trials: a star for every answer, right or wrong. |
| ![Cup finished](../assets/img/kids/10_cupdone.png) | **Cup finished.** Ten stars: the monster dances; give a sticker. |
| ![Rest](../assets/img/kids/11_rest.png) | **Rest.** 45 s every 10 trials, then Space to go on. |
| ![Done](../assets/img/kids/12_done.png) | **Done.** |

## Session

1. **Calibration**, before the child sits down: tube in, nobody on the mouthpiece. The
   wedge closes fully once (about 0.5 min).
2. **Story**, then **practice**: 2 free slurps without a question, then 6 trials (80,
   0, 80, 0, 75, 0) with feedback. Pass: 5 of 6 right, including both 80s. One retry;
   a second failure ends the session as `PracticeFailed_`, which is itself a result.
3. **Main trials**: up to 40, a rest every 10, about 15-20 s per trial.
4. **Sticker.** About 15-20 minutes in all.

## Running it

```matlab
cd <repo>/task/RRST_kids
addpath('config');

% With the device (on the stim laptop it's COM7, through the USB hub)
cfg = kidsConfig(); cfg.device.port = "COM7";
runKidsRRST(cfg)

% Without a device or a child: simulated device and child, small window, 5x faster
cfg = kidsConfig(); cfg.device.mock = true; cfg.smallWindow = true;
cfg.debug.simulateChild = [70 8 0.1 0.1];   % [threshold slope falseAlarm lapse]
cfg.debug.timeScale = 0.2;
runKidsRRST(cfg)
```

MATLAB asks for the child ID, then for Enter once the tube is in and nobody is on the
mouthpiece (calibration).

**Experimenter controls**

| Input | Effect |
|---|---|
| Click a face (any button) | That answer. Clicks in the middle strip are ignored. |
| Left arrow / `n` | "Easy" (no) |
| Right arrow / `y` | "Squishy!" (yes) |
| `x` | Bad breath: the trial is repeated later |
| Space | Moves on from the story, ready and rest screens; during a question, pauses (wedge to 0) |
| Esc | Abort: wedge parked open, data saved as `Aborted_` |

**Data** are saved to `data/raw/`: `RRSTkids_<ID>_<date>.mat` (every trial, practice,
the Psi posterior, flags, configuration, the device's move log and transcript) and a
`.csv` with one row per trial. Prefixes: `MOCK_`, `SIM_`, `Aborted_`, `Error_`,
`PracticeFailed_`. For a QC figure (trials with the threshold estimate, P("squishy")
with the fitted curve, response times, summary):

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
Practice 6/6 right. Threshold 79.2 % (SE 4.7), yes-bias 0.28, false alarms 2 of 5
catch trials. The "unusable" flag fired on hits at 80 % (1 of 3), the misfire
described below.

![QC figure of the first adult pilot](../assets/img/kids/pilot_qc_2026-10-28_1712.png)

## Open questions

- **The cap.** 85 % comes from one adult run. Children breathe with less flow, so the
  same obstruction gives less pressure drop; check 70-85 % on a flow rig. The adult
  tester's threshold was 79 %, close to the cap: a child whose threshold is above
  85 % cannot be measured, and what to report then is undecided.
- **The "low hit rate" flag misfires** for thresholds near 80 % (43 % of simulated
  children there were flagged). It should apply only when the estimated threshold is
  well below 80, or be dropped.
- **The false-alarm flag is noisy** with about 8 catch trials; more catch trials or a
  rule based on the estimated guess rate would be steadier.
- Translations (Swiss German, Danish); cue sounds; whether to record mouth pressure to
  flag weak slurps.
