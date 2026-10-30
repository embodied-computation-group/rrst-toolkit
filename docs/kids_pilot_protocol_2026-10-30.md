# RRST-Kids pilot protocol: self-test, then one child

Two short sessions to collect first user data on the breath-driven Milkshake Monster
(`kids-variant`, plan in `kids_flow_feedback_and_ux_plan_2026-10-30.md`). Session A is
the experimenter alone on the real device. Session B is one 4.5-year-old, as a usability
check, not as study data. Nothing in B is a measurement of the child; it is a measurement
of the game.

Both sessions run on the stim laptop with the device on COM7 through the USB hub, the
SFM3019 on the SensorBridge (COM10), the Physio Recorder with the RRST preset, and the
task on the external screen.

## Before either session (15 min, once)

1. **Flow stream and lag.** Open the Physio Recorder, RRST preset, check the Flow signal
   is green. Then in MATLAB, from the repo root:
   ```matlab
   cd bench; flowFeedbackCheck(60, SmallWindow=false)
   ```
   Breathe through the mouthpiece ten times, normally. Write down the median and 95th
   percentile lag and the number of breaths it reports. Expected: under 60 ms, ten
   breaths. Put the numbers in `handbook/shared/airflow-sensor.md` where it says
   `TODO(measure)`.
2. **Sounds by ear.** With headphones on:
   ```matlab
   cd task/RRST_kids; addpath('code', 'config', '../../device');
   cfg = kidsConfig(); snd = kidsSound(cfg.noise, cfg.sound);
   for n = snd.cueNames, snd.play(n); WaitSecs(1.5); end; snd.close()
   ```
   Each cue must be clearly audible over the rain and not harsh. If a cue clips or is
   too loud, lower `cfg.sound.volume` (0.8) and note the value.
3. **Mock run with simulated flow** to make sure the whole session completes on this
   machine after the merges:
   ```matlab
   cfg = kidsConfig(); cfg.device.mock = true; cfg.smallWindow = true;
   cfg.debug.simulateChild = [70 8 0.1 0.1]; cfg.debug.timeScale = 0.2;
   cfg.markers.lsl = false; runKidsRRST(cfg)
   ```

## Session A: experimenter self-test (about 30 min)

Purpose: does the breath feedback feel immediate and right, does the detector behave on
real breaths through the obstruction, and a first look at the level-leak question (plan
step 6). Two runs, same settings except the feedback mode.

Settings for both runs (ID 9001 for A1 and 9002 for A2: the kids task asks only for an
ID, and the file name carries the ID and the time):
```matlab
cfg = kidsConfig(); cfg.device.port = "COM7";
cfg.child.numPsiTrials = 20; cfg.child.numCatchTrials = 8;   % shorter than the default 30 + 10
```

**Run A1, feedback on** (`cfg.flow.feedback = "breath"`, the default). Start the Physio
Recorder recording when the task asks for it. Go through calibration, story, the tutorial
(free play, the pinch and sleep demos, the answer cards) and the practice, then the main
trials until the early stop or 28 trials. The experimenter line at the bottom left (and
the console) says where you are: `PRACTICE k of 6` or `Trial n`. **The reveal (the mouse
shown pinching or asleep) appears only in the tutorial demos and the practice**; main
trials have no feedback, only a star per answer, right or wrong. The console prints each
practice answer and, after each round, whether it passed and why not. While running,
note on paper:

| What to watch | Note |
|---|---|
| Free play | The console's reference line at its end (volume, belly-full and counts-above thresholds). Does the belly fill in step with your breath, or late? (Free play never marks a slurp weak on screen; the console says "small; sets the reference".) |
| Demos | Did the pinch at 80 feel clearly different from the sleep demo at 0? |
| Every slurp | Did the belly start to rise as soon as you began inhaling? Did the drain happen on the breath's end? |
| False onsets | Any slurp counted when you had not inhaled (the T-valve backflow must never trigger one)? |
| Weak slurps | Did any real breath come out as "weak"? At which level? |
| High levels (75 to 85) | Did the belly still fill completely? If it visibly fills slower, that is the leak the plan worries about: note how obvious it is. |
| Timeout prompt | Did it ever fire when you had breathed? |
| Sounds | Cue timing relative to what you saw; anything startling. |
| Trial length | Rough seconds per trial from Space to the answer. |

**Run A2, feedback off** (`cfg.flow.feedback = "none"`; keep `cfg.flow.enabled = true`
so the flow is still recorded and free play still sets the reference). Same
procedure. Note the same things where they apply, and whether the fixed pacing now feels
slow or fast compared with A1.

**Afterwards** for both files in `data/raw/`, from the repo root:
```matlab
addpath('task/RRST_kids');
qcKids("data/raw/RRSTkids_9001_<date>.mat")   % A1, feedback on
qcKids("data/raw/RRSTkids_9002_<date>.mat")   % A2, feedback off
```
Compare between A1 and A2: false alarms on catch trials, the fitted guess rate (yes-bias)
in the QC summary, the threshold and its SE, trials to stop, and the mean trial length
from the CSV. With one run each this is a sanity check, not evidence; a difference in
false alarms of more than two trials or a guess rate that moves by more than 0.15 is
worth a second pair of runs before any child sees the "breath" mode.

Keep the two `.mat`/`.csv` files, the recorder's `.xdf` and figures, and this page's notes
in `bench/sessions/kids__device_<id>__<date>/` with a README (your own pilot runs may be
committed; study data never).

## Session B: one child, usability (about 12 min of task, 25 min in all)

Purpose: does a 4.5-year-old understand what to do from the screen and sounds alone, and
does she stay engaged for one or two cups. The threshold is not the point; stop as soon
as she is done.

**Settings** (shorter than the pilot defaults; levels and cap as the defaults, full
scale, by Micah's decision of 2026-10-30):
```matlab
cfg = kidsConfig(); cfg.device.port = "COM7";
cfg.child.startLevel = 60;
cfg.child.numPsiTrials = 15; cfg.child.numCatchTrials = 5;
cfg.child.stopMinTrials = 10;
cfg.timing.pause = 30;
```
`validateKidsConfig` will refuse anything above the cap, so these are checked at launch.

**Setup**
- A new single-use filtered mouthpiece and a cleaned coupler (`handbook/shared/hygiene.md`).
  Let her hold the mouthpiece first and try breathing through it with the device off.
- Headphones at the volume you found in the pre-check, tried on her for comfort before
  the task starts; if she will not wear them, run without the rain (`cfg.noise.enabled =
  false`) and accept the motor noise.
- Calibration before she sits down (the script asks). Physio Recorder recording.
- You sit next to her with the keyboard and mouse; she only needs to breathe and point.
- A second adult or a phone on a stand filming the screen and her face is the most
  useful record of all (your call as her parent; it stays with you, not in the repo).

**Structure** (the experimenter line at the bottom left and the console say which step
you are in and which key goes on)
1. **Story.** Tell it in your own words over the screens. Press Space to move on when
   she looks ready, not before.
2. **Tutorial, inside the task.**
   - *Free play (wedge at 0, about 2 min).* "Can you make the monster's belly big?" Let
     her breathe through the mouthpiece as often as she likes and watch the belly; the
     milkshake refills when it is empty. This is where you learn whether the feedback
     is self-explanatory. Space ends it once she has slurped (hold Space 1 s if she will
     not). Every slurp sets her reference volume, however small: read the console line
     and write it down.
   - *Demo 1, the mouse pinching (wedge at 70).* "Look, the mouse is pinching the
     straw! Slurp and feel it." Three slurps with the mouse on the straw, then the
     reveal. No question.
   - *Demo 2, the mouse asleep (wedge at 0).* "Now it is asleep. Slurp again." Three
     slurps, then the reveal.
   - *The answer cards.* "Now you say: did the mouse pinch?" Show her the two cards
     (easy: the mouse asleep; squishy: the mouse pinching), then Space.
3. **Practice (6 trials with the reveal).** Let the screen do the explaining: after each
   answer the mouse is shown pinching or asleep. Only add words if she asks.
4. **Main trials: at most two cups (20 answers).** No reveal; a star for every answer,
   right or wrong (progress, not a score). One rest in between. Stop with Esc the
   moment she wants to stop; a stopped session is a result.
5. **Sticker** at each full cup (the cup tip waits for Space) and at the end.

**Observation sheet** (one line per trial or event; a phone voice memo is fine):

| Item | What to record |
|---|---|
| Ready cue | Did she put the mouthpiece in and breathe without a verbal prompt? Count prompts per trial. |
| Breathing | Did she breathe before Space, on the cue, or only after being told? Any blowing instead of sucking? |
| Weak / timeout | How many "weak" slurps (console) and whether the try-again pose and sound registered with her (they never come in free play or the demos). |
| Demos | Did she notice the mouse on the straw while slurping? Any comment on the feeling? |
| Belly | Did she look at the belly while breathing? Any comment ("it's getting big")? |
| Question | Did she answer by speaking, pointing, or both? Any preference for one card regardless of the trial? Did she understand "squishy"? |
| Reveal (practice) | Did she react to the mouse being shown? Did the idea of the pinch land? |
| Rewards | Reaction to the star, the star flight, the cup, the sounds. |
| Attention | Time to the first look-away; what pulled her back; when she asked to stop. |
| Quotes | Anything she said about the monster, the mouse, the straw, the feeling. |

**Afterwards**
- `qcKids` on the file (as above); look at `tr.slurps` in the `.mat` for her slurp volumes and peak
  flow per trial, and how many were weak. Her reference volume tells you whether the
  pilot thresholds (0.10 L floor, 25 % of reference) are right for a child.
- The recorder's `.xdf` has the flow with every `slurp_<k>_onset` marker: check that
  onsets line up with the breaths on the trace.
- Write the observations into `handbook/v2/kids.md` under a new "First child (date)"
  section, as the adult pilot of 2026-10-28 was recorded, and list what to change next.

## Safety reminders

- The cap and every level are checked at launch and before each move; nothing above `cfg.child.hardCap`
  can be sent with the settings above.
- Esc parks the wedge open; closing the port disables the motor; she can always take the
  mouthpiece out.
- If she coughs, gags or looks uncomfortable, Esc, mouthpiece out, done for the day.
