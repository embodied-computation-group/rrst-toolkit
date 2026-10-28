# Tasks

Current work, decisions and next steps. Update this before clearing or compacting a
session so a fresh session can continue from the files.

## Now

- [x] Device layer (`device/+rrst`), built test-first against a simulated device.
      41/41 tests pass; mutation checks recorded in VERIFICATION.md (2026-10-28).
- [x] Bench step 1: `bench/readStatus.m` (sends only `s`), first 2.0 unit on COM3,
      2026-10-28. Reply parsed; saved as a captured fixture (42/42 tests pass).
      Findings:
  - The firmware is **"Vigilant-Piston (Oct  1 2026 11:30:50)"**, older than the
    bundled "Patient-Regulator (Oct  7)". It has no device ID line, no `y` retract,
    no `k` verify and no usage statistics, and it was built from work that was
    uncommitted on Oct 1 (closest commit dcd4274, Oct 2). The calibrate and move
    reply strings match the fixtures.
  - The max endstop reads **TRIGGERED** at power-up. The switches are wired
    normally-closed (INPUT_PULLUP, HIGH = triggered), so either the carriage is
    resting on the max endstop (wedge at full obstruction) or the max switch wire is
    open. Inspect before calibrating.
  - Saved max position from an earlier calibration: 39963 steps, so first contact is
    about 15963 and the old hard-coded 12000-38000 range doesn't fit this unit.
  - Run current reads 795 mA (800 requested; the TMC2209 rounds the current scale).
- [ ] Bench session with the physical device (needs the user and the device):
  - decide whether to flash Patient-Regulator before calibrating;
  - check whether MATLAB `serialport` asserts DTR;
  - calibrate and record `MaxPosition`;
  - capture real transcripts into `tests/fixtures/`;
  - measure the physical 0 and full-scale anchors;
  - time real moves.

- [ ] Device handbook (`handbook/`, MkDocs Material, branch `handbook`). Drafted
      2026-10-28; open items are `TODO(<owner>)` tags (`grep -rn "TODO(" handbook/`).
      Waiting on Martin's review, the parts survey, and photos of the 2.0 devices.

## Next

- Generate the masking noise in Psychtoolbox (replacing the 60-min `32-Waterfall-60min.wav`).

- Build the 2.0 task from the imported RRS_3-0 on `rrst.Device`, with study settings
  moved into a configuration file and these fixes:
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

- 2026-10-28: Renamed from rrst-zurich to **rrst-toolkit** (RRST Toolkit 2.0): a general-purpose toolkit, with Zurich as its first deployment.

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
- Licence for Martin's code. Asked by email on 2026-10-28, together with questions on
  this unit's EEPROM state, anchors, the enabled flag after `c`, DTR, motor noise, move
  timing and firmware versioning (`../context/message_to_Martin_DRAFT.md`). Awaiting
  his reply.
- Which MATLAB/Psychtoolbox versions to support. The first deployment is the Zurich stimulus PC.
