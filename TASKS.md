# Tasks

Current work, decisions and next steps. Update this before clearing or compacting a
session so a fresh session can continue from the files.

## Now

- [ ] Device layer (`device/+rrst`), built test-first against a simulated device.
- [ ] Bench session with the physical device (needs the user and the device):
  - `s` status;
  - check whether MATLAB `serialport` asserts DTR;
  - calibrate and record `MaxPosition`;
  - capture real transcripts into `tests/fixtures/`;
  - measure the physical 0 and full-scale anchors;
  - time real moves.

## Next

- Import the task (RRS_3-0 as the base) at the recorded commit. Then build RRS_4-0 on
  `rrst.Device`, with these fixes:
  - check every move;
  - fix the ITI rest position;
  - fix the `resetResp` call in the tutorial;
  - fix the `experimentEnd` argument order;
  - fix `isfield('vars', ...)`;
  - park the wedge at no load before disabling.
- Per-device calibration records (`devices/<device_id>.json`).
- Firmware snapshot: hex, SHA-256, source commit, library versions.
- Hardware bench checklist and pre-study acceptance checklist in `docs/`.

## Decisions

- 2026-10-28: Project scaffolded from the lab-book conventions, adapted to MATLAB (no uv, no Python analysis).
- 2026-10-28: Replies are framed on the firmware prompt `Valve>`, because every command handler ends with `giveCmdPrompt()`. Unsolicited lines found before a command are logged, not discarded.
- 2026-10-28: Anchors are stored as offsets from `MaxPosition`, so they survive recalibration drift.
- 2026-10-28: Out-of-range obstruction requests raise errors instead of clipping.
- 2026-10-28: A failed move raises `rrst:moveFailed`. Callers must handle it, so a failure can't be ignored.

## Open questions

Scientific decisions for the scientist (see the decision sheet):

- Stimulus unit and range: paper (0-18 mm, 1 mm steps) or code (0-17 mm, 36 levels)?
- Psi priors: paper (beta log 1-16, lambda 0.02) or code (beta 0-7 log10, lambda 0.03)?
- Where the wedge rests between trials (the original code meant 50 +/- 30 %).
- How close full scale may come to the max endstop.
- The pause between breaths, given measured move times.
- Whether to record pressure and flow.
- Licence for Martin's code.
- Which MATLAB/Psychtoolbox versions the Zurich PC runs.
