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
  - [x] Unattended fullscreen mock run, 2026-10-28: `runRRST` with stubbed
    `KbCheck`, `KbReleaseWait`, `GetMouse` and `input` (stubs kept outside the repo),
    6 trials, one break. Found and fixed: endSession errored on every completed run
    with noise off (PsychPortAudio never loaded), and no CSV was ever written
    (struct2csv hid the error). After the fixes it completes: .mat plus an 18-column
    per-trial CSV, 2 calibrations, 2560x1440 at TextSize 28.
  - [ ] Not covered by the stubbed run: real clicks and key presses, Esc, how the
    text size looks on this screen. Esc does not abort while the "which breath"
    mouse prompt is up (inherited from RRS_3-0). A short manual check is still due.
  - [x] First run with the device, 2026-10-28 12:57: 10-trial Psi pilot, mouse,
    COM7 via hub. Device side clean (calibration 23 steps from the record, 32/32
    moves confirmed, parked open). Record and transcript in
    `bench/sessions/pilot__device_2E4441D76D5F2996__2026-10-28_1257/`.
  - [x] Fixed: a held mouse button answered both the breath question and the
    confidence scale (trial 3, RT 0.00 s / 0.01 s). `getResponse` and `slideScale`
    now count only a press that starts after the button has been released; held
    for the whole window means no response. Checked with stubbed GetMouse/GetSecs
    (held-then-released, held throughout, clean press, no press): the old helpers
    accept the held button, the new ones do not. Not yet clicked through for real.
  - [ ] Check: confidence 0 on 5 of 9 trials. Tester's choice, or slider start?
  - [x] Second pilot (tutorial on, Psi prior 50-100 %), 2026-10-28 13:22, aborted
    in the tutorial because no sound played: noise is off in pilotConfig. Device
    side: calibration 41257 (39 from the record), only `s`, `c`, `e` before the
    moves, so no `f`/`g`/`t` (unit settings unchanged since the morning). Esc
    parked at 1600 and closing the port disabled the motor (`s` afterwards:
    Stepper Enabled NO, position 1600, calibration cleared).
  - [x] Masking noise by ear (headphones, USB audio): pink at 0.5 was painfully
    loud and still harsh when turned down; brown is much easier to sit through.
    Pilot setting now brown at 0.2. Volume is relative to the system volume, which
    is not recorded yet. Not yet checked whether brown masks the motor whine.
  - [x] Third pilot, 2026-10-28 13:29: 10 Psi trials, prior 50-100 %, brown noise
    0.2, no tutorial. Device clean (no `f`/`g`/`t`/`v`; settings 16000 / 10000 /
    SpreadCycle / 795 mA / 50 % hold / 16 microsteps; MaxPosition 41266, 32/32
    moves). 10/10 valid, shortest RT 0.42 s (mouse fix holds). First trial 72.5 %,
    threshold 76.2 %. `bench/sessions/pilot__device_2E4441D76D5F2996__2026-10-28_1329/`.
  - [x] Rain loop for masking, 2026-10-28: `task/helpers/audio/rain_loop_30s.wav`
    (Freesound 650541, CC0, synthesised rain, 48 kHz stereo; checks and limits in
    that folder's README). Not wired into the task yet: MATLAB needs a file option
    in `startMaskingNoise` (`audioread`, the file's own 48 kHz rate).
  - [ ] Masking noise: brown had to be loud ("a bit eye watering") and the motor was
    still faintly audible next to the device. Try a blend of colours that sounds
    like rain (the RRS_3-0 rain recording masked well); measure the motor's
    spectrum first so the blend covers it.
  - [x] Fixed: stray backslash on the calibration screen (`\ Please wait`, from
    RRS_3-0).
  - [x] `bench/qcSession.m`: QC figure for a saved session (staircase with
    correct/incorrect and the Psi estimate, confidence, move times).
  - [x] Device not detected on the stim laptop, 2026-10-28. Plugged directly into
    either USB-A port of the X1 Carbon Gen 6, the unit produced no USB event at all
    (no VID_16C0 device, no unknown device, no Kernel-PnP event), with the cable
    that works on the desktop. The ports themselves are fine: a USB 2.0 stick
    enumerated in the same port on its High-Speed lane. Not drivers or policy
    (inbox xHCI drivers, no device control). Root cause unknown.
    **Fix: connect through a USB hub** (Genesys GL3523 hub, VID_05E3). It then
    enumerated at once as COM7 (serial 20933290), and a read-only `s` answered in
    73 ms: Device ID 2E4441D76D5F2996, Patient-Regulator (Oct  7 2026 08:45:06),
    Saved Max Pos 41296, both endstops ok, not calibrated. COM4/COM5 are the
    laptop's LTE modem (VID_8087&PID_0ACA), so `port = "auto"` stops with
    `rrst:ambiguousPort` here: set `cfg.device.port = "COM7"` after `pilotConfig()`.
    BIOS 1.50 could not be updated from Windows (Lenovo's flash driver
    `TdkLib64.sys` is on Microsoft's vulnerable-driver blocklist); not needed.
- Per-device calibration records (`devices/<device_id>.json`).
- Firmware snapshot: hex, SHA-256, source commit, library versions.
- Hardware bench checklist and pre-study acceptance checklist in `docs/`.

## Martin's answers (2026-10-28, `../context/sources/Martin_reply_2026-10-28.pdf`)

- [x] Imported Msnejbjerg/RRST 8720abc (firmware source, Control Panel with the
  Precise-Piston hex built from aa8dd72, 4-0 helpers with the `isSerialportHandle` fix,
  `recalibrateResp`, `waitForCalibration`). PROVENANCE updated.
- [x] Task sets speed, acceleration and chopper mode at every calibration
  (`cfg.device.motion`, `rrst.Device.applyMotion`), never saves with `v`. Pilot value =
  what this unit already runs (SpreadCycle 16000/10000), PROVISIONAL.
- [x] `Git Commit:` status line parsed and saved with the session.
- [x] Failed calibration now sends `d` (Martin left this to us; the conservative choice;
  revert `Device.calibrate` if unwanted).
- Already covered in 2.0, nothing to change: per-unit anchors (our zeroOffset 25600 =
  16.0 mm agrees with Martin's paper test, 16 mm on his unit); explicit `setDTR` in
  `rrst.openPort`; no `isa(port, 'serialport')` in `device/+rrst`. The 3-0/4-0
  `scale2motorstep` 12000-38000 constants are reference code only, unused by 2.0.
- Martin's figures (max 40900-40930, first contact about 15320) are for **his** unit.
  Ours: max 41296, zero 15696 (tube in).
- [ ] Flash Precise-Piston on 2E4441D76D5F2996? Gains fault monitoring after `c`, the Git
  Commit line, faster `s`. Needs Micah's approval; re-check anchors afterwards (default
  retract changes 15 -> 16 mm, but the toolkit uses its own anchors, not the retract).
- [ ] Re-run Martin's reliability check on our unit out to real full scale (his tests
  stopped about 3 mm short of max; tube load peaks about 900 steps short of max).
- [ ] Send Martin the masking sound (or the generated-noise settings) so he can test
  motor noise against it; `helpers/audio/32-Waterfall-60min.wav` is not in either repo.

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
- Motion settings ({{MOTION}}), from Martin's measurements on his unit (tube in, 24000-step
  move): SpreadCycle 16000/10000 is quietest (+17.3 dBA above room) but has a narrow
  whine near 14 kHz; StealthChop 16000/10000 +22.1 dBA (3.1 s), 16000/20000 +25.5 dBA
  (2.3 s), 16000/30000 +26.4 dBA (2.0 s). StealthChop loses steps above about 16000
  steps/s. The old TMC2100 device ran StealthChop 16000/10000. Relative levels at the
  device, one session, no masking, no headphones. The 2.0 task waits for the confirmed
  move before the countdown, so a slower move lengthens the trial, it never shortens
  the pause. Martin suggests a 3.5 s pause with 16000/10000, or 16000/20000 if 2.5 s
  must stay.
- Whether to record pressure and flow.
- Licence for Martin's code. Asked by email on 2026-10-28, together with questions on
  this unit's EEPROM state, anchors, the enabled flag after `c`, DTR, motor noise, move
  timing and firmware versioning (`../context/message_to_Martin_DRAFT.md`). Awaiting
  his reply.
- Which MATLAB/Psychtoolbox versions to support. The first deployment is the Zurich stimulus PC.
