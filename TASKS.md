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
    open. Inspected 2026-10-28: the wedge is fully closed and the switch is pressed,
    so the reading is genuine. No tube was fitted.
  - Saved max position from an earlier calibration: 39963 steps, so first contact is
    about 15963 and the old hard-coded 12000-38000 range doesn't fit this unit.
  - Run current reads 795 mA (800 requested; the TMC2209 rounds the current scale).
- [ ] Bench session with the physical device (needs the user and the device):
  - [x] flashed Patient-Regulator (hex SHA-256 dcd17a6c..., matches PROVENANCE.md)
    with the bundled teensy_loader_cli 2.3 (`--mcu=TEENSY40 -w -v`, after a 134-baud
    reboot request), 2026-10-28. Device ID **2E4441D76D5F2996**. Saved settings and
    saved max (39963) survived; usage counters start at zero;
  - [x] DTR: `rrst.openPort` (MATLAB `serialport` + `setDTR(true)`) keeps the
    firmware connected; calibration completed with no "Serial connection lost".
  - [x] calibrated with `bench/calibrateAndCapture.m`, no tube, 2026-10-28:
    MaxPosition **40079** (previous saved 39963, +116 steps = 0.07 mm), computed
    first contact 16079, travel 25.0 mm at 1600 steps/mm, 25.6 s. The firmware
    saves the new max to EEPROM on `c`. `x` diagnostics all OK. Replies are now fixtures;
  - [x] `bench/openForSetup.m` (recalibrate, then park at 1600), 2026-10-28:
    move 41220 -> 1600 took **4.09 s** from command to "Move complete.", well over the
    ~2.5 s the old task allows before inhalation. **MaxPosition read 41220 (+1141
    steps, 0.7 mm)**: the tube was fitted during this calibration, so the wedge
    probably closed onto it and the motor lost steps (the tube cannot lengthen the
    real travel). Unconfirmed. To test: repeat `c` with and without the tube and
    compare. If confirmed, calibrate tube-out, or raise the run current, and ask
    Martin about this. Also seen: the move reply was followed by a second `Valve>`
    prompt; check how the firmware handles the value line;
  - [x] Tube effect on calibration, 2026-10-28 (`bench/repeatCalibration.m`,
    `bench/slipTest.m`). MaxPosition with the tube **out**: 39963 (Martin's), 40079,
    40111, 40099. Tube **in**: 41220, 41283, 41257, 41265. The tube adds about 1150
    steps (0.72 mm), consistently. Slip test (tube in): after calibrating, two cycles of
    open-to-1600 then `k` triggered the max endstop at 41295 and 41279 (+30, +14), with
    no warnings. With lost steps the count would have grown by about 1150 per close.
    **Conclusion: elastic compliance, no lost steps.** Positions are reliable; the
    calibration condition (tube in/out) must be the same every session;
  - capture real transcripts into `tests/fixtures/`;
  - [x] anchors measured 2026-10-28 (`bench/anchorSession.m`; record in
    `devices/2E4441D76D5F2996.json`; log in `bench/sessions/`). Calibrated tube in
    (max 41296). Zero (wedge touches tube) at **15696** (zeroOffset 25600). Full scale
    (barely possible to inhale) at **40496** (fullOffset 800). Range **15.5 mm**.
    PROVISIONAL: uncut, longer tube; re-measure full scale with the production tube.
    Breathing reports: no change up to about 12 mm past zero, first noticeable
    resistance at 12 mm, very difficult at 15 mm, barely possible at 15.5 mm. At the end
    of travel (41196) air still passes with maximum effort. The old hard-coded
    12000-38000 range doesn't fit (it starts 2.3 mm before touch and ends 2.5 mm short of
    full). The paper's 0-18 mm and the code's 0-17 mm don't fit either: only 15.5 mm is
    available;
  - time real moves.

- [ ] Device handbook (`handbook/`, MkDocs Material, branch `handbook`). Drafted
      2026-10-28; open items are `TODO(<owner>)` tags (`grep -rn "TODO(" handbook/`).
      Waiting on Martin's review, the parts survey, and photos of the 2.0 devices.

## Next

- Pilot idea (Micah, 2026-10-28): resistance rises very non-linearly as the tube
  closes. Most of the travel is imperceptible, and the useful range is the last 3-4 mm.
  Instead of a uniform mm grid, give Psi a non-uniform stimulus grid (Palamedes accepts
  any vector): densely spaced near closure (e.g. even in log of the remaining gap), or
  even in measured resistance after a pressure/flow calibration. Psi adapts which level
  to use, not the grid itself. Changing the stimulus axis changes what a threshold
  means, so decide before Zurich data collection.


- [x] 2.0 task built (`task/RRST_2-0/`, 2026-10-28): `rrst.Stimulator` on
  `rrst.Device`, settings in `config/pilotConfig.m`, every move confirmed, ITI rest
  fixed, `resetResp`/`experimentEnd`/`isfield` fixed, wedge parked open at the end,
  masking noise generated in code. Also found and fixed: RRS_3-0 rounded every Psi
  level to a whole number (`round(xCurrent)`), so its 0.49 mm grid was never used;
  that probably explains why the paper's stimulus levels are whole numbers.
- [ ] **First run on the stim laptop**: `cfg.device.mock = true` first, then the
  device. Not yet run under Psychtoolbox/Palamedes anywhere.
  - [x] Stim laptop toolboxes, 2026-10-28: MATLAB R2024b Update 10
    (24.2.0.3361896), Psychtoolbox 3.0.19 (Manual Install, build Jul 31 2024),
    Palamedes 1.11.13 at `C:\toolbox\Palamedes`. Tests: 74/74 pass on R2024b.
  - [x] Non-interactive smoke test (no device, no clicks), 2026-10-28: pilot Psi
    setup and 100 simulated updates (levels stay on the grid, simulated threshold 60
    recovered as 58.3), metacog list, quest setup/update, mock Stimulator, the small
    window with main.m's colour handling (background 0.537, white text, Danish
    characters render), the expanding ring, GetMouse (3 buttons), PsychPortAudio
    open/fill/close. Windowed mode fails the sync test (DWM compositor) and runs on
    because of `SkipSyncTests=1`.
  - [x] Fixed: experience-rating slideScale outputs were in the wrong order
    (inherited from RRS_3-0).
  - [ ] Interactive mock run (Micah clicks through): needs the MATLAB desktop,
    because `runRRST` asks for subject ID and language with `input`.
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

- Calibrate with the tube out or in? The tube adds about 1150 steps to MaxPosition, so
  mixing conditions shifts every anchor by about 0.7 mm. Recommendation: tube out
  (purely mechanical reference, 32 vs 63 steps spread). Ask Martin what he intended.

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
