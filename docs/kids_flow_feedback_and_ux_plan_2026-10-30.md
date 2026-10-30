# RRST-Kids: live airflow feedback and a child-game UX pass

Plan, 2026-10-30. Applies to the `kids-variant` branch (`task/RRST_kids/`, last commit
d3bef73, "Milkshake Monster"). Nothing here is implemented yet.

## 1. Why flow feedback

The kids task currently *tells* the child when to breathe: after the experimenter presses
Space, the monster's belly grows and the milkshake drains on a fixed timer (1.2 s in,
1.8 s out, three times, about 9 s). The child's own breathing has no effect on the screen.
The first try with a 4.5-year-old showed the cost: a timed breath was too hard to catch,
and the task was changed to experimenter-started trials.

The SFM3019 at the circuit inlet already streams inhalation flow at 1 kHz over LSL
(`plux-lsl/flow_lsl.py`, stream "Flow", channels nSeq/flow/temp, about 20 ms behind the
bridge). Driving the monster from that stream turns the trial into a real game loop:
**the child slurps, the monster drinks.** That gives three things at once:

1. **Causality.** The belly grows and the milkshake drains *because* the child inhaled.
   No pacing to follow, no timer to catch. The trial ends when three real slurps have
   happened, not after 9 s.
2. **A minimum-effort guarantee.** A slurp only counts when it reaches a minimum volume,
   so every trial's stimulus was actually sampled. This answers the open question
   "whether to record mouth pressure to flag weak slurps": weak slurps are detected live
   and never counted.
3. **Per-slurp physiology in the data.** Onset, peak flow, volume and duration for every
   slurp, in the `.mat` and as LSL markers, with no analysis step.

### The one scientific risk: the feedback must not reveal the level

Peak flow and volume both fall with obstruction (bench 2026-10-28, one adult: peak
84 to 36 slm and volume 1.85 to 0.80 L between 0 % and 95 %). A screen that shows flow
*proportionally* shows the child the pinch: the milkshake would visibly drain slower on
load trials, and the child could answer "squishy" from the picture instead of from the
feeling. Detection would become partly visual.

So the feedback shows **that** a slurp is happening, and roughly **how far along** it is,
but is designed not to carry the level:

- **Belly** = cumulative volume of the current slurp, normalised to the child's own
  free-slurp volume and **saturating at a low fraction of it** (about 40 %), so nearly
  every slurp, loaded or not, fills the belly completely. The fill *speed* still differs
  a little between loaded and unloaded slurps; this is the residual leak and it is
  bounded by the saturation point.
- **Milkshake** drains by exactly one third per counted slurp, on the slurp's end, never
  proportionally.
- **Bubbles** on the slurp's end, fixed animation.
- **No flow-rate cue** (no particles racing up the straw at a speed set by flow). Not
  even as an option in the first version.

Mode is a configuration value, `cfg.flow.feedback`, with `"breath"` (as above) the
default and `"none"` (today's timed animation) the fallback. Whether to allow a
proportional mode for piloting is a design call: `{{FLOW_FEEDBACK_MODE}}`. The
confound is also a pilot question in its own right: compare catch-trial false alarms
and the fitted guess rate with feedback on and off in adults before any child sees the
"breath" mode.

## 2. Architecture

```
SensorBridge (COM10) --> flow_lsl.py --> LSL "Flow" --> Physio Recorder (records, as now)
                                                   \-> kids task inlet (liblsl-Matlab)
                                                        kidsFlow (buffer, breath detector)
                                                        kidsMain slurp phase (breath-driven)
                                                        kidsScene (belly, cup, bubbles)
```

- **Read over LSL, not from the bridge.** Only one program can hold the SensorBridge
  port, and the Physio Recorder already owns `flow_lsl.py`. An LSL inlet in the task
  costs nothing and the recorder keeps recording the same stream.
  `C:\toolbox\liblsl-Matlab` (v1.14.0 with the 1.18 `lsl.dll`) has `lsl_resolve_byprop`,
  `lsl_inlet` and `pull_chunk`; nothing in the toolkit uses an inlet yet, so this is the
  first use and needs a bench check (section 4).
- **Latency budget.** Bridge read about 20 ms, LSL on the same machine under 1 ms, one
  frame 17 ms, so a breath onset reaches the screen in roughly 40 to 60 ms. Fine for
  feedback; the latency is measured in the bench check and written into the handbook.
- **Who starts the stream.** The Physio Recorder's RRST preset starts `flow_lsl.py`
  and starts recording when it sees the "RRST" marker stream. The kids task sends no
  markers today, so step 1 below adds them; then the existing workflow (open the
  Physio Recorder, launch the task) works unchanged for kids. If no "Flow" stream is
  found within `cfg.flow.timeout` (10 s), the task prints one RA-readable message
  ("No airflow stream. Start the Physio Recorder with the RRST preset, or set
  cfg.flow.enabled = false to run without breath feedback.") and stops. It never
  silently falls back at launch; mid-session loss is handled per trial (section 3.5).

### New and changed files

| File | Role |
|---|---|
| `task/helpers/flowInlet.m` (new, shared) | Open/close the "Flow" inlet; `pull()` returns new samples as GetSecs-stamped `[t flow]`, using the LSL-to-GetSecs offset the same way `rrstMarker.m` does. Shared so the adult task can reuse it for roadmap item 6, guided breathing. |
| `task/RRST_kids/code/kidsFlow.m` (new) | Class. Ring buffer, low-pass, breath detector with hysteresis, running volume and peak, per-slurp records. Source is pluggable: `flowInlet` (live), `kidsSimFlow` (synthetic breaths for tests, mock and `simulateChild`), or none. |
| `task/RRST_kids/code/kidsSimFlow.m` (new) | Synthetic inhalations: half-sine flow with configurable peak, duration and interval, plus the T-valve's small negative backflow after each breath, so tests exercise the backflow rule. |
| `task/RRST_kids/code/kidsBreathScale.m` (new) | Belly fill from volume: `min(volume / (frac * refVolume), 1)` with `refVolume` from the free slurps and `frac` = `cfg.flow.bellyFraction`. Pure function, tested. |
| `task/RRST_kids/code/kidsMain.m` | Slurp phase becomes breath-driven (section 3.3); markers; per-slurp records in `tr.slurps`; reference breath from the free slurps. |
| `task/RRST_kids/code/kidsScene.m` | No new fields needed for the breath mode (belly, cup, bubbles exist). UX changes in section 5 touch it. |
| `task/RRST_kids/config/kidsConfig.m`, `validateKidsConfig.m` | `cfg.flow.*` and `cfg.markers.*` (below). |
| `tests/TestKidsFlow.m` (new) | Breath detector, scale, simulated-flow trial logic. |
| `bench/flowFeedbackCheck.m` (new) | Latency and detector check on the real stream, no device move. |
| `task/RRST_kids/README.md`, `handbook/v2/kids.md`, `handbook/shared/airflow-sensor.md` | Docs. |

### Configuration (pilot values, to be tuned on the rig)

```matlab
cfg.markers.lsl = true;                   % "RRST" marker stream, opened at launch (as runRRST)
cfg.markers.requireRecorder = true;       % hold before calibration until a recorder is listening
cfg.markers.liblslDir = "C:\toolbox\liblsl-Matlab";

cfg.flow.enabled = true;                  % false: today's timed animation, no inlet
cfg.flow.feedback = "breath";             % "breath" | "none"   {{FLOW_FEEDBACK_MODE}}
cfg.flow.timeout = 10;                    % s to find the "Flow" stream at launch
cfg.flow.onsetSlm = 3;                    % flow above this starts a slurp (flow_quality uses 3 slm)
cfg.flow.onsetHold = 0.05;                % s above threshold before it counts (noise guard)
cfg.flow.offsetHold = 0.15;               % s below threshold before the slurp ends
cfg.flow.minVolumeFrac = 0.25;            % slurp counts if volume >= this x reference volume
cfg.flow.minVolumeL = 0.10;               % ...and at least this (absolute floor, children)
cfg.flow.bellyFraction = 0.40;            % belly is full at this x reference volume (saturation)
cfg.flow.refVolumeDefault = 0.6;          % L, used until the free slurps have set the reference
cfg.flow.slurpTimeout = 8;                % s without a slurp onset: experimenter prompt
cfg.flow.maxSlurpDur = 6;                 % s: a "slurp" longer than this is a leak/draught, not counted
cfg.flow.smoothHz = 5;                    % low-pass before detection
```

`validateKidsConfig` rejects `feedback = "breath"` with `enabled = false`, and any
threshold that is not positive. **The feedback never changes a level.** `kidsCheckLevel`
and the 85 % cap are untouched; the flow path only decides when the question appears
and what the data contain.

## 3. Behaviour, trial by trial

### 3.1 Launch (`runKidsRRST.m`)

1. Open the "RRST" marker outlet (as `runRRST` does), push `RRST_ready`.
2. If `cfg.flow.enabled`: resolve "Flow", open the inlet, read for 1 s and check that
   flow is finite and not frozen (reuse the rules in `flow_quality.py`: frozen, out of
   range, reversed sensor, constant flow). Print "Airflow sensor OK: 0.0 slm at rest."
   or the specific problem.
3. `waitForRecorder` if required (unchanged from the adult task).
4. Calibration as now (nobody on the tube).

### 3.2 Free slurps become the breath calibration and the tutorial

The two free slurps (`cfg.practice.nFree`) are kept, with feedback on. The monster's
belly fills from the child's breath and the milkshake drains per slurp. The reference
volume is the median of these two slurps, clamped to [0.15, 2] L; the belly saturation
and the minimum-volume rule follow from it. If both free slurps are missing (no onset in
`slurpTimeout`), the experimenter is prompted on the console and the defaults stay.
Console line: "Reference slurp 0.42 L, peak 18 slm. Belly full at 0.17 L; a slurp
counts above 0.11 L."

### 3.3 Slurp phase (replaces the fixed three-cycle animation)

```
Space (experimenter: child is ready)
loop until counted == cfg.child.slurps:
    wait for onset          -> marker slurp_<k>_onset; belly fills with volume
    wait for offset         -> if volume >= min: counted++, milkshake drains 1/3,
                               bubbles, marker slurp_<k>_end_<volume>_<peak>
                               else: marker slurp_<k>_weak; belly deflates, no drain
    timeout (no onset for slurpTimeout s) -> console prompt; Space = go on with what
                               we have (trial repeated later if counted == 0), x = repeat
Space at any point ends the phase early (as now); Esc aborts (as now).
-> question
```

Every slurp, counted or not, is recorded in `tr.slurps` as onset (GetSecs and LSL
time), duration, peak flow, volume, counted. `tr.slurpT` keeps its meaning (phase
duration). A trial with fewer than `cfg.child.slurps` counted slurps when Space ends it
is kept but flagged `tr.shortSlurps = true`; the QC figure shows it.

With the stream lost or `feedback = "none"`, the phase runs the current timed animation.

### 3.4 Markers (new for kids; names match the adult task where the event exists)

`RRST_ready`, `calibration_start/end`, `story`, `practice_start`, `main_start`,
`trial_<n>_level_<x>` (sent at the confirmed move, catch trials carry `level_0`),
`trial_<n>_go` (Space), `slurp_<k>_onset`, `slurp_<k>_end_<vol>_<peak>`,
`slurp_<k>_weak`, `question`, `answer_yes` / `answer_no` / `bad_breath` / `no_answer`,
`trial_<n>_correct|wrong`, `rest_start/end`, `aborted`, `done`. The Physio Recorder's
figures epoch on `trial_<n>_level_<x>` already; `rrst_figures.py` will need a kids
branch for one-interval trials (listed in step 9, not blocking).

### 3.5 Failure handling (RA-first)

| Situation | Behaviour |
|---|---|
| No "Flow" stream at launch | One console message naming the fix; task stops before calibration. |
| Sensor frozen, reversed, constant flow at launch | Same, with the specific message from the quality rules. |
| Stream stops mid-session (`lsl:lost_error`, or no samples for 1 s) | Current trial finishes with the timed animation, `tr.flowLost = true`, console warning once; the task tries to reconnect between trials and reports when it is back. The session never aborts because of flow. |
| Child breathes before Space | Ignored (the detector only runs during the slurp phase); the monster does not react, which is itself the cue that it is not yet time. |
| Leak or draught (flow never drops to zero) | Slurp exceeds `maxSlurpDur`, not counted, console warning "flow is not returning to zero: check the circuit". |

## 4. Bench check before any child or adult pilot

`bench/flowFeedbackCheck.m` (no device move, no calibration):

1. Open the inlet, show a bare window with a bar driven by `kidsFlow`, breathe ten
   times. Print per breath: onset, duration, peak, volume, and the lag between the
   sample's LSL timestamp and the Flip that first showed it. Expected: lag 40 to 60 ms,
   ten breaths detected, zero spurious onsets from the T-valve backflow.
2. Repeat with the wedge held at 75 % by hand via the Control Panel (optional) to
   check that the belly still saturates on loaded breaths with `bellyFraction = 0.4`.
3. Record the run through the Physio Recorder and confirm the recorder's flow trace and
   the task's `tr.slurps` agree on onsets within 10 ms.

Results go to `bench/sessions/` with a README, like the 2026-10-28 flow bench.

## 5. UX pass: the task as a children's game

Review of the twelve key frames in `handbook/assets/img/kids/` and of `kidsScene.m`,
`kidsQuestion.m`, `kidsText.m`, from the point of view of someone who ships games for
four-year-olds. The verdict first: the structure is right (one character, one goal, one
question, a star every time), but the presentation is a flat diagram with captions, and a
four-year-old cannot read captions. Everything the child needs to know is currently in
the text at the bottom.

### 5.1 What a four-year-old actually sees

| Screen | Problem |
|---|---|
| Story, Ready, Star, Cup done | **They look identical.** Same pose, same face, same cup. The only difference is the sentence, which the child cannot read. The child has no way to tell "wait" from "go" from "well done". |
| Monster | **No character.** Two fixed eyes, a dot for a mouth, no arms, no brows, no blink. The straw enters the face at eye level like a pipe. Nothing ever looks at the child or at the cup. In a children's game the character's face *is* the UI. |
| Big slurp / Ahhh | The belly is a lighter disc that grows. Readable, but it is the only thing moving, and it moves on a timer the child did not cause. |
| Mouse | The antagonist of the whole story is a small grey blob in the corner. The pinch, the one thing the child must detect, is never shown happening. |
| Question | Green smiling face versus **red squashed, eyes-shut, "oof" face**. To a child that reads as happy versus hurt, good versus bad. Children avoid choosing the "bad" picture, which is a response bias built into the response screen. The yes-bias is modelled in the Psi guess rate, but there is no reason to manufacture it. |
| Practice feedback | A sentence ("Yes! The mouse pinched it!"). The truth is the most teachable moment in the session and it is text. |
| Rest | "Little rest. 37": a countdown number. Four-year-olds do not read numbers reliably. |
| Progress | Ten stars and four cups at the top are small and static; a star appearing is not an event. |
| Sound | None. The README says a second stream next to the rain needs PsychPortAudio master/slave devices, and so it was left out. Children's games are sound-led; this is the single biggest gap. |
| Pace | 15 to 20 s per trial, up to 40 trials, 15 to 20 min. Long for the age. The breath-driven slurp phase (section 3) shortens trials by itself: three real slurps take 6 to 8 s, not 9 s plus slack. |

### 5.2 Design principles to adopt

1. **No reading.** Child-facing text goes away from the child's screen. The caption strip
   becomes an *experimenter* line, small, in a corner, or on the console (the stim laptop
   runs the task on the external screen, `max(Screen('Screens'))`, so the console is the
   natural experimenter display). Every state the child must recognise gets a pose and a
   sound.
2. **The face is the interface.** Five monster expressions carry the whole task: waiting
   (looks at child, blinks), ready (mouth open on the straw, eyebrows up), slurping
   (cheeks in, eyes squeezed happy), satisfied (eyes closed, bubbles), celebrating (arms
   up). Drawn once as sprites, not coded as shapes.
3. **Cause and effect within half a second.** Breath moves the belly (section 3); the
   answer click makes the star fly into its slot; the tenth star tips the cup.
4. **Both answers are equally nice.** The question shows two *scenes*, not two emotions:
   "the monster drank and the mouse was asleep" versus "the mouse pinched the straw". Both
   bright, both with a cheerful monster. Keep green/red out of it.
5. **Show the pinch.** The story and the practice feedback show the mouse actually
   pinching the straw and the slurp getting hard. Once in the story, every time in
   practice feedback. In main trials the mouse runs behind the cup on every trial (as now,
   so nothing leaks) and is never shown pinching.
6. **One thing moves at a time.** Keep the flat, uncluttered look; add a ground line and
   a table so the cup stands on something, nothing more.

### 5.3 Concrete changes, in priority order

| # | Change | Where | Size |
|---|---|---|---|
| U1 | **Cue sounds** through a PsychPortAudio master with two slaves (rain loop on one, short cues on the other): ready chime, slurp (triggered by breath onset), bubbles, star, cup fanfare, mouse scamper. Short wav files in `task/RRST_kids/assets/sounds/`, generated in code where possible (chime, bubbles). | new `kidsSound.m`; `startMaskingNoise` gains a master/slave option | M |
| U2 | **Breath-driven slurp** (sections 1 to 3). The child's breath becomes the controller. | `kidsMain`, `kidsFlow` | L |
| U3 | **Expression sprites** for the monster (five poses) and the mouse (run, pinch, sleep), loaded as textures; shapes stay as fallback when the asset folder is missing. Art: self-made or CC0, no licensing surprises; keep the current colours. | `kidsScene`, `task/RRST_kids/assets/img/` | M |
| U4 | **Question screen redesign**: two scene cards, same size and brightness, monster cheerful in both; mouse pinching the straw on the "squishy" card, mouse asleep in the corner on the "easy" card. Pointer ring and chosen-card behaviour unchanged. | `kidsQuestion` | S |
| U5 | **Practice feedback as a reveal**: the cup slides aside and the mouse is either pinching the straw or asleep, with the matching sound; 1.5 s, no text. | `kidsMain`, `kidsScene` | S |
| U6 | **Story as three animated beats** (monster slurps happily; mouse creeps and pinches, slurp gets hard, monster's cheeks strain; mouse hides). Space advances each beat so the experimenter narrates over it. | `kidsMain` | M |
| U7 | **Star flight**: the earned star appears at the monster and flies to its slot (0.6 s); tenth star tips the cup into the "done" row. | `kidsScene`, `reward()` | S |
| U8 | **Rest as a nap**: monster asleep with rising Z's, a draining bar instead of a number; wakes with a stretch when the rest ends. | `kidsScene`, `rest()` | S |
| U9 | **Experimenter line** off the child's screen: console prints the state, the level (experimenter only), slurp count and the reference volume; the on-screen caption shrinks to a corner or disappears. | `kidsMain`, `kidsText` | S |
| U10 | **Flavour per cup**: pink, chocolate, green, blue for cups 1 to 4, a small novelty every ten trials. | `kidsScene` | S |
| U11 | **Rounded display font** (an installed rounded sans; Arial stays as fallback) for the few remaining labels. | `openScreen` | S |

U1 and U2 are the ones that change what the child experiences. U3 to U5 are what make
it look like a game. The rest is polish.

### 5.4 Things a game developer would also insist on

- **Watch three children before polishing.** Record where they look and when they
  disengage; the pilot protocol should log the experimenter's prompts per trial.
- **Target 8 to 10 minutes of trials.** With breath-driven slurps and the early-stop
  rule (about 27 trials in simulation) this is within reach; if not, the cup-and-sticker
  loop is the place to add a short second session, not a longer first one.
- **Turn-taking must be explicit.** The monster "asks" (opens its mouth, chime), the
  child acts, the monster reacts, the question comes, the star comes. The same order
  every trial, so the child learns the rhythm in practice and stops needing prompts.
- **Never punish.** Weak slurps and time-outs produce a neutral "try again" pose, never
  a sad face or a lost star.

## 6. Order of work

Test first, small commits, on `kids-variant` after merging `main` (the branch is two
merges behind: markers, recorder guard and the handbook updates are on `main`).

1. **Markers for the kids task** (`cfg.markers`, `rrstMarker` calls, `waitForRecorder`).
   Makes the Physio Recorder's auto-start and the figures work for kids with no flow
   feedback at all. Test: markers are no-ops when `cfg.markers.lsl = false`.
2. **`flowInlet.m` and `bench/flowFeedbackCheck.m`**; run the bench check on the stim
   laptop and record the latency. This is the go/no-go for the rest.
3. **`kidsFlow` breath detector, `kidsSimFlow`, `kidsBreathScale`** with
   `tests/TestKidsFlow.m`: onset and offset with hysteresis, backflow ignored, volume in
   litres from slm, weak slurp not counted, over-long slurp not counted, reference
   volume from two free slurps, scale saturates at `bellyFraction`.
4. **Breath-driven slurp phase in `kidsMain`** with the simulated child using
   `kidsSimFlow`; the mock run (`cfg.device.mock = true`) exercises it end to end.
   Timed animation kept behind `cfg.flow.feedback = "none"`.
5. **Cue sounds** (U1) and the **question screen** (U4), both small and independent of
   flow.
6. **Adult pilot on the real device**, feedback on, with the Physio Recorder: compare
   catch-trial false alarms and the fitted guess rate with feedback on versus off
   (two short runs). Decide `{{FLOW_FEEDBACK_MODE}}`.
7. **Sprites, reveal, story beats, star flight, nap** (U3, U5, U6, U7, U8).
8. **Docs**: kids README, `handbook/v2/kids.md` (new key frames), airflow page
   cross-reference, TASKS.md.
9. **Physio Recorder figures** for one-interval kids trials (`rrst_figures.py`, in
   `plux-lsl`): per-trial slurp gallery, volume and peak by level and catch.

Steps 1 to 4 are the flow feature; 5 and 7 are the UX pass; 6 is the decision point
between them.

## 7. Decisions (Micah, 2026-10-30)

- **Feedback mode: saturating volume.** `cfg.flow.feedback = "breath"` as described in
  section 1; the belly is full at 40 % of the child's reference slurp, the milkshake
  drains a fixed third per counted slurp, no flow-rate cue. The adult on/off comparison
  (step 6) checks the residual leak; `{{FLOW_FEEDBACK_MODE}}` is resolved as "breath"
  unless that comparison says otherwise.
- **Minimum volume: both rules.** A slurp counts at 25 % of the child's reference
  volume and at least 0.10 L.
- **Masking: keep the rain loop**, volume 0.6; cue sounds are mixed over it on a second
  PsychPortAudio slave.
- **No cap below full scale** (Micah, later on 2026-10-30, after the first run): `cfg.child.hardCap` default 100, Psi grid 0:5:100, practice 90/90/85, pinch demo 90.
- **The kids site has the same rig** (SFM3019 + SensorBridge). Flow feedback is the
  default; `cfg.flow.enabled = false` stays as a tested fallback only.
