# RRST methods paper: key methodological details

> **Source status: read this first.**
> - **Primary source, read in full:** the published article, Nikolova et al. (2022), *Biological Psychology* 170:108325, doi:10.1016/j.biopsycho.2022.108325. It is open access under CC BY; received 19 Oct 2021, revised 21 Mar 2022. The PDF and the extracted text were kept in the analysis workspace and are not part of this repo. The Weibull equation and Table 1 were checked against renders of the PDF page, not just the extracted text.
> - **Also read:** the bioRxiv preprint v2 (2021-10-20, `rrst_v2.xml` / `rrst_v2.txt`). It is used only to note what changed in revision (§13).
> - **Not accessed:** the online **Supplementary Material**, a separate file on the publisher site. It holds the parts list, Supp. Fig. 1 (apparatus schematic) and Supp. Fig. 2 (correlation heatmap). The original repo README links a separate parts list (Google Sheet), which has not been opened either.
> - Comparisons with code refer to `original/task/RRS_3-0/code/loadParams.m` (header "version 2-2", last edit 08/06/2021) and `main.m` in the RespiroceptionMethodsPaper repo.

**Citation:** Nikolova, N., Harrison, O., Toohey, S., Brændholt, M., Legrand, N., Correa, C., Vejlø, M., **Snejbjerg Jensen, M.**, Fardo, F., & Allen, M. (2022). The respiratory resistance sensitivity task: An automated method for quantifying respiratory interoception and metacognition. *Biological Psychology*, 170, 108325.

Two things relevant to this project:
- Martin Snejbjerg Jensen is a co-author on the published version. He isn't on the preprint.
- Olivia Harrison's affiliations include the Translational Neuromodeling Unit, University of Zurich and ETH Zurich.

---

## 1. Sample and setting (main study, Aarhus)
- N = 33 recruited (20 female), ages 19–66 (M = 28.09, SD = 9.08), from the CFIN SONA pool.
- **Exclusions:**
  - 1 for non-converging staircases, leaving **N = 32** for type 1.
  - 2 more from the metacognition analysis for overly extreme confidence ratings, leaving N = 30. The example criterion given is "more than 90% 100% rating", i.e. over 90% of ratings at 100 (§7).
- **Inclusion:** no current psychiatric diagnosis; no drugs or medication that alter psychological function; normal or corrected vision; fluent English or Danish.
- Respiratory illness was **not** an exclusion criterion. No participant reported a history of it, and only 2 rated asthma symptoms above 10%.
- 60–75 min total; participants were reimbursed. Ethics: Region Midtjylland.
- **Second site** (Otago, NZ; HDEC 20/CEN/168): N = 15 (12 female, age 23.1 ± 5.5) did the RRST and the Filter Detection Task (FDT), with pressure and flow recorded.

## 2. Apparatus, as published
- A 3D-printed housing clamps flexible tubing against a **wedge**. The wedge is driven by a stepper motor through a **TR8×2 leadscrew** (2 mm lead) and coupler.
- **Electronics:** stepper motor with a **TMC driver** and **Teensy 3.1**. The text also says "Arduino circuit board".
- Commands come from **Psychtoolbox over USB** (USB-A to micro-USB). Stimulus positions are set by the staircase.
- **Breathing circuit:** hospital-grade circuit with custom couplers. A **Hans Rudolph 2-way non-rebreathing T-valve** and a **PowerBreathe TrySafe filtered mouthpiece**, single use, sit at the participant end.
- Noise and vibration: motor damper and rubber feet.
- **Software:** MATLAB 2020a, Psychtoolbox 3, Palamedes.

## 3. Session set-up and cue masking
- Seated at a height-adjustable desk. The mouthpiece is held on a desktop microphone stand; a photo is in the GitHub repo.
- **Auditory masking:** over-ear headphones playing continuous "rain" noise.
- **Visual masking:** the device and the compressed tubing sit in a box beside the participant.
- **Tactile masking:** damper, rubber feet, thick foam under the device, and a surface detached from the participant's desk.
- **Movement-duration cue removed:** the load moves to a *random* position in every ITI, so movement duration doesn't predict the next stimulus.
- **The masking was tuned by piloting:** "extensive piloting using, for example, **different acceleration settings for the motor driver**, and varying noise sounds", so that participants couldn't use vibration or sound cues. *The new firmware's speed, acceleration, driver and chopper mode change the motor's sound and vibration, so masking needs re-piloting on the Zurich build.*
- **Tutorial**, first session only, about 5 min: trial structure introduced step by step, then 2 trials with accuracy feedback, then 6 trials of varying difficulty without feedback.
- **Durations:** tutorial about 5 min, QUEST about 15 min, Psi about 30 min including breaks.

## 4. Trial structure (2IFC)
- Two breaths per trial. One is the stimulus (load) and one is the standard (0%, no load). Which interval gets the load is pseudorandom.
- **Each interval:**
  - **1500 ms** "prepare to breathe" instruction;
  - then a circle outline plus a "first inhale / second inhale" cue for **200 ms**;
  - then an expanding Gaussian ring for **800 ms** that fills the circle.
- **Breathing instructions:** inhale "sharply and shallowly", lasting just under 1 s. Keep the mouth on the mouthpiece and exhale through the nose between intervals ("like a snorkel") to limit rebreathing. Otherwise participants breathe as is comfortable, and may exhale through or outside the circuit.
- **Type 1 response:** "which breath was more difficult?", given with the left/right **mouse** buttons. Maximum **3 s**. (The Fig. 1 legend still says "keyboard press".)
- **Confidence:** a VAS slider from "Guess" to "Certain", confirmed with a left click. Maximum **5 s**. A trial with no response is **repeated**.
- **Breaks:** forced, at least **2 min every 20 trials** (about every 5 min), to avoid hyperventilation. Participants stand, move and breathe normally.
- **Unpleasantness VAS** before each break, from "Not unpleasant" to "Very unpleasant".
- **End-of-session ratings:** dizziness/light-headedness, breathlessness and presence of asthma symptoms.

## 5. Stimulus units
- The staircases ran in **wedge displacement, 0–18 mm in 1 mm steps**, proportional to motor rotation. These units were used for **all analyses**.
- The values are converted to **% obstruction for figures only**.
- The text calls these "18 preset stimuli"; 0:1:18 is actually 19 values.
- The threshold is a continuous estimate, not limited to the preset levels.
- **Authors' suggestion:** future studies can restrict the range based on these data and use **sub-millimetre steps** for finer granularity.
- The paper does not define the physical anchors of 0% and 100%. The code comments in `scale2motorstep.m` define them per device:
  - **min:** wedge just touching the tube, with a sheet of A4 paper just held in place.
  - **max:** barely possible to inhale.

## 6. Psychophysics
- **PMF:** Weibull with threshold α (75% correct), slope β and lapse λ. Guess rate γ is fixed at 0.5. Both γ and λ were **fixed from pilot values**; the authors note they could be estimated freely.
- **Equation as printed:** P(correct)_W = Ψ_W(x; α, β, λ) = (1 − λ) − (5 − λ)·exp((−Δx/α)β).
  - **This is a typesetting error.** The intended form, consistent with γ = 0.5, is Ψ = (1 − λ) − (0.5 − λ)·exp(−(x/α)^β), which equals γ + (1 − γ − λ)(1 − exp(−(x/α)^β)).
- **Design:** two counterbalanced sessions per participant, **QUEST** and **Psi**.
- **QUEST:**
  - Uniform prior over threshold, 0–18 mm.
  - **2 interleaved staircases × 30 trials**, so a 60-trial session. Interleaving reduces trial-to-trial dependencies and checks that the two staircases converge.
  - Each staircase's threshold is its posterior mean (King-Smith et al., 1994); the QUEST threshold is the mean of the two.
- **Psi:**
  - Weibull, α uniform [0:1:18], β uniform log(1)–log(16), γ = 0.5, λ = 0.02.
  - Each trial presents the stimulus with the minimum expected entropy.
  - **100 trials**; the authors note that slope often needs more than 100.
- **Individual and group PMF fitting:** Bayesian criterion, with a search grid matching the Psi priors.

## 7. Analysis
- MATLAB 2020a and Palamedes.
- **Correlations:** Pearson for perceptual vs metacognitive measures and for agreement between methods. Spearman for the exploratory correlations with aversiveness and symptom ratings.
- **RT and stimulus level by accuracy:** described as "paired-sample Student's t-tests assuming unequal variances (F-test for equality of variance)". That wording is internally inconsistent; the reported fractional df, e.g. t(42.25), indicate Welch tests.
- **Type 1 coding:** correct means the loaded interval was chosen.
- **Type 2 binning:**
  - Confidence (0–100) goes into **4 bins**, justified by Sandberg et al. (2010).
  - The text says both "4 equally spaced bins" and that they used **Fleming's (2017) binning, which normalises confidence quantiles per participant** to avoid empty bins. These two descriptions conflict. The repo's `new_bin_ratings.m` should be checked to see which one was actually run.
  - Participants with overly extreme ratings were excluded (2).
- **Type 2 measures:**
  - **aROC is the main metacognitive measure**, chosen because Psi held accuracy at about 80%.
  - d′, aROC and M-ratio were computed with the **HMeta-d toolbox**.
  - The paper defines M-ratio as "d/meta-d". The standard definition is meta-d′/d′.

## 8. Physical validation: resistance versus obstruction
- **Ohm's law:** R = Δp / F.
- **Constant-flow rig:** 0.95 L/s of room-temperature air, attached in place of the mouthpiece section.
- **Instruments:** mouth pressure from an ADInstruments gauge with bridge amplifier; flow from an ADInstruments spirometer with a 300 L flow head; recorded on a 16-channel PowerLab with LabChart 8.
- **Protocol:** 17 obstruction steps from 0 to 100%, each interleaved with a return to 0%, repeated 3 times. Pressure and flow were averaged over 2 s per step.
- **Result** (Fig. 7):
  - Resistance rises **exponentially** with obstruction, sharply above about **70%**.
  - ln R is linear in obstruction: slope = 0.44, R² = 0.88, p < .0001.
  - There is noise at very low obstruction and a departure from linearity at very high obstruction.
- **In participants** (Fig. 8, N = 15): ln R vs obstruction r = 0.82; ln pressure vs obstruction r = 0.62.
- **Stated future work:** record physiology during the task so trials not performed correctly can be detected and excluded automatically. The repo was to gain functions for this.

## 9. Benchmark results to check Zurich data against
| Measure | Published value |
|---|---|
| Psi threshold α | **65.61% obstruction** (SD 8.47), range 56.71–89.79% |
| Psi slope β | mean 7.80 (SD 2.61), range 3.12–12.37 |
| Psi accuracy | 76–84% (79% ± 1.5% at Otago) |
| Convergence | Psi threshold SE drops mostly by about trial 50; approximate threshold usually found within about 20 trials; slope SE still falling at trial 100 |
| Psi vs QUEST thresholds | r(31) = 0.88; no mean difference, t(55) = −0.97, p = .34 |
| RT, correct < incorrect | Psi t(42.25) = −3.34; QUEST t(49.8) = −3.35 |
| Stimulus, correct > incorrect | Psi t(60) = 4.66; QUEST t(60) = 3.82 |
| aROC | mean 0.70 (SD 0.09), range 0.48–0.85; uncorrelated with type 1, r(31) = −0.03 |
| Unpleasantness | mean 24.69% (text) or 24.96% (legend); stable over 10 blocks (6 Psi + 4 QUEST) |
| End-of-session symptoms | dizziness 18.92%, breathlessness 29.08%, asthma 2.22% |

**Table 1, FDT vs RRST (Otago, N = 15; Student's t, df = 13):**

| | FDT (SD) | RRST (SD) | t | p | d |
|---|---|---|---|---|---|
| Pressure (cmH₂O) | 1.21 (0.66) | 2.75 (2.27) | −2.386 | .033 | −0.638 |
| Resistance (cmH₂O/L/s) | 1.82 (1.21) | 7.92 (13.16) | −1.766 | .101 | −0.472 |
| Accuracy | 71% (9%) | 79% (1.5%) | −3.196 | .007 | −0.854 |
| Confidence | 5.2 (1.6) | 5.7 (1.4) | −1.161 | .267 | −0.310 |
| aROC | 0.63 (0.07) | 0.61 (0.05) | 0.759 | .462 | 0.203 |

Resistance was non-normal (Shapiro–Wilk W = 0.631); a Wilcoxon test gave W = 25, p = .091. Across tasks, mean confidence correlated, r(14) = 0.75, p = .002. Type 1 and type 2 sensitivity, resistance and pressure did not correlate (all p > .05).

## 10. Authors' stated limitations and recommendations
- **Breathing pattern varies** (flow and pressure) at the same obstruction, especially in clinical groups. The authors advise caution with type 1 % obstruction measures, and recommend **recording pressure and flow during the task** so PMFs can be expressed against inspiratory pressure.
- **2AFC asymmetries:** attention may be distributed unevenly across intervals, and the working-memory load favours the second breath. The adaptive staircase absorbs drift in accuracy.
- **Tolerance:** aversive for a small subset; aversiveness is uncorrelated with perceptual and metacognitive parameters.
- **Reliability:** only same-session reliability was tested. **Test–retest over days or weeks is still needed.**
- **Future work:** trial-by-trial affect and symptom ratings.

## 11. Inconsistencies remaining in the published version
- Device described as both an "Arduino circuit board" and a "Teensy 3.1".
- Response device: mouse in the methods, "keyboard press" in the Fig. 1 legend.
- "18 preset stimuli" for 0–18 mm in 1 mm steps, which is 19 values.
- Weibull equation typeset incorrectly (§6).
- Confidence binning described as both "equally spaced" and quantile-normalised (§7).
- M-ratio written as "d/meta-d".
- Unpleasantness mean given as 24.69% in the text and 24.96% in the Fig. 6 legend.
- Said to be "under 30 min", but the Psi session is 30 min including breaks.
- The text says "increased average resistance … in the RRST", but that comparison has p = .101.

## 12. Paper versus current task code (RRS_3-0)
| Item | Paper | Code (`loadParams.m` / `main.m`) |
|---|---|---|
| Stimulus range / levels | 0–18 mm, 1 mm steps | **0–17 mm, 36 levels** (`stimRange = linspace(0,17,36)`, about 0.49 mm steps); `priorAlphaRange = linspace(0,17,72)` |
| Psi β prior | uniform log(1)–log(16) | **`linspace(0,7,72)`**, log10 units in Palamedes, so β from 1 to 10⁷. The line matching the paper is commented out. |
| Psi λ | 0.02 | **0.03** |
| Psi trials | 100 | 100 (matches) |
| "QUEST" | QUEST, uniform prior, 2 × 30 interleaved | Procedure 4 = Palamedes **running-fit** (`PAL_AMRF`), α 0:1:17, xMin 1, β fixed 1.5, λ 0.02, posterior mean, 2 × 30 |
| Noise masking | rain noise over headphones | `playNoiseSound = 0` by default; the audio folder holds only a placeholder |
| Response windows | 3 s / 5 s | `RespT = 3`, `ConfT = 5` (matches) |
| Interval timing | 1500 ms prepare, 200 ms cue, 800 ms ring | `PrepareT = 1.5`, `inhaleT = 0.8`, plus `breathPauseT = 0.5`, `ISI = 2`, ITI 2–4 s |
| Breaks | ≥ 2 min every 20 trials | `pauseT = 120`, `PauseFreq = 20` with confidence ratings (30 without) |
| Tutorial | yes, first session | `runTutorial = 0` by default |
| Input | mouse | `InputDevice = 2` (mouse) |
| ITI wedge jitter | random position each ITI | `moveResp2ITIpos`: 50 ± 30 % (matches the intent) |

## 13. Changes from preprint (v2) to published version
These came in with the revision. Use the published values.
- Martin Snejbjerg Jensen added as an author.
- Stimulus grid stated explicitly (1 mm steps, α [0:1:18]); Psi 100 trials stated; guess and lapse fixed "based on piloted values"; suggestion of sub-mm steps.
- 1500 ms prepare-to-breathe phase and the interval cue ("first/second inhale") specified.
- Masking motivated by piloting of motor-driver acceleration and noise sounds.
- Confidence binning changed to Fleming's quantile-normalised method plus an explicit exclusion example for extreme ratings; M-ratio defined.
- Added: Psi–QUEST mean comparison (t(55) = −0.97); exact symptom percentages; unpleasantness across 10 blocks (6 Psi + 4 QUEST); FDT comparison moved into the main text (§2.7, Table 1, Figs. 8–9).
- Added limitations: 2AFC attention and working-memory asymmetry; the need for multi-day test–retest.
- Medication exclusion reworded; respiratory illness history reported.

## 14. Implications for the Zurich build (Teensy 4.0 + TMC2209)
- **The stimulus axis is defined by physical anchors**: wedge just touching the tube (0) to barely possible to inhale (max), with the mm scale mapped linearly between them. Resistance is exponential above about 70%, and thresholds cluster around 66%, so an error in the top anchor distorts the stimulus most where it matters. The new firmware's endstop-referenced coordinates must be re-anchored to these definitions. Ideally, check the result with a constant-flow resistance curve (§8) and compare it with Fig. 7.
- **Decide before data collection, and pre-register, which parameterisation Zurich uses**: the paper's (0–18 mm in 1 mm steps, β prior log(1)–log(16), λ = 0.02, QUEST) or the code's (0–17 mm in 36 levels, β 1–10⁷, λ = 0.03, running fit). Only the paper's is directly comparable with §9.
- **Re-pilot cue masking**, because the motor sound and vibration profile has changed. Re-enable the rain noise (it isn't shipped in the repo) and the tutorial.
- **Consider recording pressure and flow**, as the authors recommend for interpreting type 1 results and excluding missed trials.
