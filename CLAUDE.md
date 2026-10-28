# Project: RRST Toolkit 2.0

## Question
- General-purpose RRST toolkit: run the task on any calibrated Teensy 4.0 + TMC2209 device so that every requested obstruction level is delivered, confirmed by the firmware, and logged.
- Keep the toolkit study-agnostic. Study-specific settings (grid, priors, timing) are configuration, not code changes. Zurich is the first deployment.

## Scientific context
- Methods source: `docs/methods_paper_notes.md` (Nikolova et al., 2022), plus the integration review `docs/integration_review_2026-10-28.md`.
- Stimulus anchors are physical and per device: 0 = wedge just touching the tube, full scale = barely possible to inhale. They are measured at the bench, never derived or guessed in code.
- Open scientific decisions are listed in `TASKS.md` under "Open questions". Do not resolve them in code; leave a visible `{{PLACEHOLDER}}` instead.
- Do not change expected test values to make code pass.

## Environment
- MATLAB R2021a or later. Device-layer tests need no toolboxes.
- Run tests from the repo root: `matlab -batch "addpath('device'); results = runtests('tests'); disp(table(results)); assertSuccess(results)"`
- On this Windows machine, run MATLAB batch through PowerShell `Start-Process` with redirected output; it takes about 30-60 s.

## Hardware rules
- Never send `c`, `a`, `e`, `y` or any setting command (`f g i u p r t v w z`) to a real device without the user's go-ahead in the current session. `s` (status) is read-only and allowed.
- Never flash firmware without explicit approval.
- Firmware replies are the source of truth for a move or calibration. Code must check them, never assume success.

## Data
- Develop against `rrst.MockPort` and fictional data in `data/generated/` (labelled FICTIONAL).
- `data/raw/` and `data/processed/` hold study data: off limits, never in Git.
- Firmware transcripts in `tests/fixtures/` must state their origin: "constructed from source" or "captured from device <ID> on <date>".

## Working cycle
- Plan substantial changes first; small focused commits; stage files explicitly.
- Test first: commit failing tests, then the implementation, with the outcome in the message.
- No AI attribution lines in commits or files.
- Ask before pushing, creating remotes, or contacting anyone.
- Update `TASKS.md` before a restart or compaction.

## Data definitions
- Step coordinates are the firmware's: 0 = min endstop (wedge fully retracted); steps increase toward the max endstop (more obstruction); `MaxPosition` is measured by every `c`.
- Anchors are stored as offsets from `MaxPosition` (`zeroOffset` > `fullOffset` >= 0), so they follow recalibration.
- Obstruction values outside [0, scaleMax] are an error, never clipped (the old `rescale` clipping put the ITI rest at full obstruction).
- Stimulus unit (mm with scaleMax 17 or 18, or percent): {{STIMULUS_UNIT}}. Undecided.

## Known issues
- Serial replies end in CRLF, and the prompt `Valve>` has no line terminator. Frame replies on the prompt, not on line endings.
- `c` energises the driver but does not set the firmware's enabled flag, so driver-fault monitoring stays off until `e` is sent.
