# Roadmap

## Documentation

- [ ] **Photos of the 2.0 devices**: exterior, interior, the TMC2209 conversion
      close-ups, the endstops and the Control Panel.
- [ ] **Engineer review** of every RRST 2.0 page (all `TODO(Martin)` items).
- [ ] **Parts sourcing survey**: availability and replacements, with dates and links.
- [ ] Replacements reported by other labs.
- [ ] Rod and leadscrew cut lengths, print settings, and the purpose of the printed
      couplers.

## Hardware

- [ ] **PCB respin for 2.0**: the TMC2209 on a native footprint, switchable fan,
      reverse-polarity protection, and a connector for the DS18B20 temperature sensor.
      This replaces today's hand-wired modification.
- [ ] A validated replacement motor for the legacy housing.

## Firmware

- [ ] Report the source commit (git hash) in the status output, as well as the build
      codename.
- [ ] Set the "enabled" flag after calibration, so driver-fault monitoring runs without
      an explicit `e`.
- [ ] Recommended quiet-running settings (StealthChop vs SpreadCycle, speed and
      acceleration), validated with the sweep test.

## Task software (RRST Toolkit 2.0)

- [x] Device layer that confirms and logs every calibration and move (tested against a
      simulated device).
- [x] Bench validation on hardware, with real firmware transcripts (first 2.0 unit,
      2026-10-28): calibration repeatable to about 0.02 mm, stimulus anchors measured.
- [x] The 2.0 task (`task/RRST_2-0/`), built from `RRS_3-0` with the known bugs
      fixed, settings in a configuration file, per-device stimulus anchors, the
      wedge parked open at the end, and generated masking noise. First run on a stim
      PC pending.
- [ ] **Python version** with PsychoPy and PyPalamedes (`pypalamedes` on PyPI,
      which includes the Psi method). Validate it against the MATLAB task: same
      priors and responses must give the same stimulus choices and estimates.
- [ ] Stimulus levels spaced by effect rather than by distance. Resistance rises
      steeply as the tube closes, so most of the wedge travel is imperceptible.

## Physiological measurement and control

The device sets a physical obstruction. What a participant actually experiences is
their own inspiratory pressure and flow, which they control. The task's visual design
tries to standardise breathing, but only measuring it can correct for it.

1. [x] **Flow sensor** in the breathing circuit, recorded on every breath with the task
       markers and physiology over LSL ([Airflow sensor](shared/airflow-sensor.md),
       [Recording](shared/recording.md); first 20-trial run 2026-10-28).
2. [ ] **Pressure sensor** near the mouth, on the same SensorBridge and in the same
       stream as flow, so every breath gives its actual resistance (pressure ÷ flow)
       and work of breathing.
3. [ ] **Pressure/flow calibration** of each device: resistance as a function of
       wedge position.
4. [ ] **Effort as a covariate.** Per trial, the load-minus-null difference in peak
       flow, volume or early flow, entered in the psychometric fit or used to predict
       errors near threshold. In the first 20-trial run, load breaths at 75 % or more
       had lower peak flow on 10 of 12 trials. Below 75 % they were lower on only 3
       of 8, and on three trials the load breath was the stronger one: spontaneous
       effort changes the stimulus.
5. [ ] **Flag mismatched breaths**: trials whose two breaths differ by more than a set
       amount in volume or peak flow without the load, for exclusion or sensitivity
       analyses.
6. [ ] **Guided breathing**: live flow feedback against a target band, so both breaths
       of a trial are matched. The flow stream is already live over LSL. Cost: it adds
       a motor task and may change what participants perceive.
7. [ ] **Staircasing on physiological variables**: the adaptive procedure targets and
       analyses measured resistance or pressure, and wedge position becomes the means
       of delivering it. Re-presenting trials with mismatched breaths is a simpler
       first step.

A tight, repeatable mechanical calibration is the baseline every later stage builds
on.

## Recording and analysis tools

- [x] **Standard figures for every recording**: session overview, breaths aligned on
      the inhale cue (load vs null), staircase with each trial's null and load peak
      flow and volume, and a per-trial breath gallery; the wedge-level figure for
      bench runs. Made by the Physio Recorder after Stop (2026-10-28).
- [ ] Confidence ratings as markers and in the by-trial figure. In the pilot,
      confidence followed both level and peak-flow drop.
- [ ] **Measure the PLUX Bluetooth delay** against the task markers with a hardware
      test, before any ECG-locked (cardiac phase) analysis.
- [x] **`plux-lsl` under version control**: private repository
      [embodied-computation-group/plux-lsl](https://github.com/embodied-computation-group/plux-lsl)
      (2026-10-28).
- [ ] **Fixed-level flow protocol** for effects below the perceptual threshold:
      randomised fixed levels (e.g. 20/40/60/80 %), each paired with a null breath.
      The staircase keeps levels near threshold, so it can't test this.
- [ ] **Flow streamer watchdog**: fail with a clear message, instead of hanging, if
      the SensorBridge's USB link stops responding.

## Site

- [x] Published on GitHub Pages (2026-10-28): <https://www.the-ecg.org/rrst-toolkit/>
