# RRST integration review: original task (RRS_3-0) versus the Snejbjerg Teensy 4.0 + TMC2209 device

Date: 2026-10-28. Read-only review of
`C:\Users\Micah\vibes\respiroception\original\` (RespiroceptionMethodsPaper, GPL-3.0, HEAD a033091) and
`C:\Users\Micah\vibes\respiroception\snejbjerg\` (HEAD c298eed, 213 commits).
No device attached; no serial port opened; nothing flashed; nothing modified in either repo.

## 0. What could and could not be verified

**Could not be run: MATLAB.** `C:\Program Files\MATLAB\R2021a\bin\matlab.exe -batch` fails with
"License Manager Error -10: Your license for MATLAB has expired". Every statement below about
MATLAB semantics (`rescale`, `isfield`, `serialport` `readline` timeout behaviour, DTR on open,
`clear all` versus globals) is therefore reasoned from the documented behaviour of those
functions, not executed. The one arithmetic claim that matters most (finding F2) is reproduced
from `rescale`'s documented formula in
`C:\Users\Micah\AppData\Local\Temp\claude\C--Users-Micah-vibes-respiroception\fdb9a3ab-5b19-4b23-a830-f522b78aeb03\scratchpad\rescale_check.py`;
it should be re-run as `rescale([0 50 17], 12000, 38000)` in a licensed MATLAB before anyone
acts on it.

**Verified from source** (read in full): the current firmware
`RRST_Teensy_4_version_TMC2209.ino` (1618 lines) and its command parser `LocalMenuCmd.cpp`;
the 3-0 and 4-0 MATLAB helpers; `main.m`, `loadParams.m`, `experimentLauncher.m`,
`respiroceptionTutorial.m`, `experimentEnd.m`; the original firmware `Resp_valve_3-0.ino`,
`RRST_Arduino.ino` and the zipped intermediate Teensy 4 build (`Software = "2026r5"`); the
Control Panel serial layer; the design specs for the 4-0 helpers, retract distance, serial
disconnect safety and the single-endstop rebuild; the session-protocol HTML.

**Run here:** the Control Panel's own test suite (`python -m pytest tests/ -p no:cacheprovider`):
62 passed in 0.92 s with system Python 3.13, pyserial 3.5, pytest 9.0.2.

**Only confirmable on hardware:** whether MATLAB's `serialport` asserts DTR (the firmware's
disconnect safety depends on it, F6); the real `MaxPosition` of the Zurich unit; the physical
meaning of first-contact and max on that unit; real move durations; `readline` timeout
return type; thermal behaviour over a 45-minute session.

**Which device is in Zurich.** The brief says Teensy 4.0 + TMC2209 dual-endstop. The Snejbjerg
repo also contains a Teensy 3.1 single-endstop rebuild (`legacy/`) with a completely different,
frozen protocol (bare integer lines, no commands, 9600 baud, hard-coded `MAXPOSITION 5000`;
`legacy/RRST_TMC2209_singleEndstop.ino:35,63,207`). Nothing in this review applies to that
device. The acceptance checklist (section 6) starts by sending `s` and reading the firmware
codename and Device ID so the assumption is checked rather than believed.

## 1. Findings ranked by severity

| ID | Severity | Where | One line |
|---|---|---|---|
| F1 | High | `snejbjerg/task/respDeviceHelpers_4-0/scale2motorstep.m:31-32` (verbatim copy of `original/task/respDeviceHelpers_3-0/scale2motorstep.m:31-32`) | Step range 12000-38000 is the 2022 "Green device"; the new device's calibrated range is whatever `cmd3_Calibrate` measures (`.ino:948`) and is never read. Every stimulus level is on an unknown scale; moves above `MaxPosition` are refused by the firmware (`.ino:1216-1217`). |
| F2 | High (pre-existing) | `original/task/respDeviceHelpers_3-0/moveResp2ITIpos.m:11-14` with `scale2motorstep.m:37,42`; copied to 4-0 | In mm mode (the Psi default, `loadParams.m:64`) the ITI "resting" position is always 38000 = maximum obstruction, because `rescale([0 x 17],...)` with x = 20..80 maps x to the top of the range. Participants sit at full obstruction through the confidence rating and ITI. |
| F3 | High | `original/task/RRS_3-0/code/main.m:255,263,436` | The task discards `moveResp`'s `moved` output. With the 4-0 helpers a refused, timed-out or safety-disabled move returns `moved = 0` and the trial runs anyway with the wedge wherever it was; the data file records the intended stimulus, not the delivered one. |
| F4 | Medium-high | `loadParams.m:188` (ISI 2 s) versus `.ino:21-22` (SPEED 16000, ACCEL 10000) | A move of more than ~10000 steps takes longer than 2 s (12000 steps: 2.19 s; 24000: 3.10 s; 26000: 3.23 s). With 3-0 fire-and-forget helpers the inhale cue can start before the wedge arrives; with 4-0 blocking helpers the ISI silently becomes 2 s plus move time and nothing records it. |
| F5 | Medium (safety) | `.ino:535-537` with `.ino:904`, `.ino:1231` | `cmd3_Calibrate` energises the driver without setting `StepperStatus = 1`; `CheckDriverFaults` returns early unless `StepperStatus == 1`. A session that only ever sends `c` and `a` (both 3-0 and 4-0 helpers) runs the whole study with over-temperature and short-circuit monitoring switched off. The USER_MANUAL calls this quirk "cosmetic only"; it is not. |
| F6 | Medium (hardware-confirm) | `.ino:582` (`if (Serial ...)`), `.ino:818,842,853,885,1096` | Firmware aborts any move or calibration the moment the host has not asserted DTR. pyserial asserts DTR on open; whether MATLAB `serialport` does is unverified here. If it does not, `initResp` will always report "Calibration failed: ERROR: Min endstop not found". Fix is one line (`setDTR(dev, true)`) but must be tested. |
| F7 | Medium | `original/task/RRS_3-0/code/respiroceptionTutorial.m:458` | Calls `resetResp`, which exists only in `respDeviceHelpers_2-2`; `experimentLauncher.m:69` adds only `respDeviceHelpers_3-0`. Running with `vars.runTutorial = 1` crashes at the end of the tutorial (caught by `main.m:727` and saved as `Error_`). Default is 0 (`loadParams.m:20`). |
| F8 | Medium | `original/task/RRS_3-0/code/main.m:457` | `experimentEnd(keys, Results, scr, vars)`: wrong argument order and `stair` missing. Pressing Esc during a confidence rating throws inside `experimentEnd`; the outer `catch` then saves the run, so data survive, but the abort path is not the one the code intends. |
| F9 | Medium | `main.m:295,362,452,492,530,580,715` then `experimentEnd` closes the window; 4-0 `closeResp.m:29` | Every abort/break/end path sends `c` (a 20-30 s blocking calibration ending with the wedge at the max endstop) and then tears down. On the new firmware, closing the port mid-calibration disconnects, triggers `CheckSerialConnection`, and leaves the wedge wherever it stopped with the driver disabled. Neither repo ever moves the wedge to no-load before disabling. |
| F10 | Medium | `.ino:371-385`, `cmd18_SaveSettings .ino:1532`, `cmd12_Microsteps .ino:1372` | Speed, acceleration and microsteps persist in EEPROM and are applied at boot. Microsteps change steps/mm (F1's scale) and speed/accel change move time (F4). The task never reads them. A Control Panel session that saved tuning changes the study's stimulus scale without any trace in the data. |
| F11 | Medium | `initResp.m:56`, `moveResp.m:54-64`, `closeResp.m:43` | 4-0 helpers return before the firmware has finished printing (the prompt, "First-contact position", blank lines) so leftover lines are consumed by the next call; `WARNING: Unexpected ... endstop hit` lines (`.ino:1181`) are silently skipped; `MaxPosition` and first-contact in the `c` reply are discarded; a line consisting only of `\r` satisfies `strlength > 0` in `closeResp`. |
| F12 | Low-medium | `snejbjerg/RRST_Control_Panel/app.py:21`, `.ino:455-463` | Firmware identity is a codename derived from `__DATE__ __TIME__`, not a commit. The bundled `.hex` reports a build at 08:45:06 on 7 Oct; the last `.ino` commit (13abac7) is 08:45:26. Plausibly built from that tree, but unprovable. Library versions for TMCStepper, OneWire, DallasTemperature are not recorded anywhere; only TeensyStep4 is vendored. |
| F13 | Low | `.ino:329` (115200), `main.m:45` (9600), `README.md:153` | Baud mismatch. Irrelevant over USB CDC (the Teensy ignores the host's baud except 134, which `firmware_flasher.py:17-18` uses to reboot into the bootloader), but the number should be made consistent and the 134 trap documented. |
| F14 | Low | `Print::println` emits CRLF; MATLAB `readline` default terminator is LF | Every reply line carries a trailing `\r`. `startsWith` matching survives it; exact-match or `strcmp` would not. Configure the terminator as `"CR/LF"` or strip. |
| F15 | Low-medium | `.ino:1161-1166` | A move to exactly `MaxPosition` is a deliberate endstop strike counted as a hit. If 100% obstruction maps to `MaxPosition`, every 100% trial slams the switch. Map 100% to `MaxPosition` minus a margin. |
| F16 | Low | `main.m:241` `isfield('vars', ...)` | Char instead of struct: always false, so the metacognition-trial branch can never run. Inert while `NMetacogTrials = 0` (`loadParams.m:52`). |
| F17 | Low | `setupResp.m:24` `global respDevice`; `main.m:702` `fclose('all')` | The port handle is also held in a global, so the serial port stays open after `main` returns. A second launch in the same MATLAB session may fail to open the port. `closeResp` (4-0) fixes this only if it is actually called. |
| F18 | Low | `loadParams.m:17` `sPort = "COM5"` | Hard-coded port; no check that the thing on COM5 is an RRST device. The firmware offers a 64-bit Device ID (`.ino:1230`) that is never used. |
| F19 | Low (documentation) | `snejbjerg/docs/rrst-session-protocol.html` | States the task "needed zero changes", that the Enabled flag quirk is cosmetic, and that the ITI load is "~50%±30%". F1, F5 and F2 contradict these. |
| F20 | Note | `snejbjerg` git history | Several commits carry `Co-Authored-By: Claude ...` trailers (e.g. a334df3, 94a236b, 1c13175). Relevant to how history is imported given the organisation's attribution rule (section 5.2). |

## 2. The protocol as actually implemented

### 2.1 Transport

| Aspect | Task / helpers | Firmware | Verdict |
|---|---|---|---|
| Port open | `serialport(sPort, 9600)` (`setupResp.m:28`, `initResp.m:23`) | `Serial.begin(115200)` (`.ino:329`); USB CDC, host baud ignored | Works; make consistent (F13). Never open at 134 baud: that reboots the board into the bootloader (`firmware_flasher.py:17-18`). |
| Host-present detection | nothing | `if (Serial)` = USB configured and DTR asserted (`.ino:582`) | Must assert DTR (F6). |
| Command framing | `writeline` appends LF | `UserRequest` (`LocalMenuCmd.cpp:236-343`): one printable char stored, executed on CR or LF; a second printable char before the terminator is "too many arguments"; after execution a 2 ms wait swallows a trailing CR/LF | Compatible. A bare number sent with no pending command is rejected as a bad command. |
| Numeric argument | second `writeline` with `%d` (4-0) or `%03d` (3-0) | `WaitForCommandInput` (15 s, `.ino:44,686-700`) then `Serial.parseInt()` (`.ino:1212`), terminating LF left in the buffer and later consumed as an empty command (prints a prompt) | Compatible. The 3-0 helpers send five-digit numbers; `%03d` is cosmetic. |
| Reply framing | 3-0: never reads. 4-0: `readline`, LF terminator | `println` = CRLF; some lines start with an embedded `\n` (`.ino:902,1206`) | Trailing `\r` on every line; empty lines before real text (F14; 4-0 code already loops over them). |
| Unread output | 3-0 never drains the input buffer | Firmware prints menu at boot, prompt after every command, 25-line status for `s` | 3-0: input buffer grows for the whole session (hardware-check whether anything is dropped). 4-0: residual lines bleed into the next call (F11). |

### 2.2 Commands the task uses, traced end to end

**`c` (calibrate).** Firmware `cmd3_Calibrate` (`.ino:900-976`): prints `\nStarting calibration...`;
`EnablePin` LOW (driver energised) **without** `StepperStatus = 1`; `CalibrationStatus = 0`; seeks
the MIN endstop with `SeekEndstopPrecise(-1, ...)` (fast approach at 8000 steps/s, 3 mm back-off,
slow 1000 steps/s re-approach; `.ino:803-898`); `setPosition(0)`; prints
`Min Endstop found. Position set to 0.`; 500 ms blind delay; seeks the MAX endstop the same way;
`MaxPosition = position`, `CalibrationStatus = 1`; persists `MaxPosition` to EEPROM if changed;
prints `Max Endstop found. Max Position: N (previous saved: M, diff: +d)` or
`(no previous saved value to compare)`, then
`First-contact position (retract 15.000 mm): N-24000`, a blank line, then the prompt `\nValve>`.
On failure prints `ERROR: Min endstop not found - calibration aborted.` or the Max variant and
leaves `CalibrationStatus = 0`. **The carriage ends resting on the MAX endstop**, i.e. at maximum
compression, with the switch triggered. Original `Resp_valve_3-0.ino:297-318` instead ended at
`STARTPOS 20000`; the task's first action after calibration is `moveResp2ITIpos` (`main.m:173`),
so on the new firmware the first move starts from the max endstop (grace-window suppression at
`.ino:1080-1086` handles the switch still being pressed).

Task side: 3-0 sends `c` and shows a fixed 65 s countdown (`main.m:141-166`); the firmware's real
time is roughly 20-35 s at the compiled-in homing speeds (two seeks: fast ≤ 100000 steps at
8000/s bounded by travel, back-off 4800 steps, slow re-approach 5000 steps at 1000/s ≈ 5 s each),
and nothing is read. 4-0 `initResp` waits up to 120 s for the `Max Endstop found` line and returns
`init = 1` without parsing `N`.

**`a` + integer (absolute move).** `cmd6_AbsoluteMove` (`.ino:1204-1223`): prints
`\nEnter absolute target position (steps):`; waits ≤ 15 s for input; `parseInt`; refuses with
`Error: Must calibrate ('c') before moving.` if `CalibrationStatus != 1`, or
`Error: Target out of calibrated bounds!` if `target < 0 || target > MaxPosition`; otherwise prints
`Moving to absolute position: N` and runs `MoveAbsWithEndstopGuard` (`.ino:1067-1202`), which is
**blocking**: the loop polls both endstops with 5 ms debounce; a clean arrival prints
`Move complete.`; an unexpected hit prints
`WARNING: Unexpected MIN|MAX endstop hit! Position auto-corrected to N.` then
`Resuming toward original target...` and retries; three consecutive hits print
`ERROR: Repeated unexpected endstop hits - stepper disabled. Investigate before re-enabling (e).`
and set `CalibrationStatus = 0`, after which every further `a` is refused until a new `c`.
A target equal to 0 or `MaxPosition` that trips the switch is treated as a normal arrival
(`.ino:1161-1166`). The firmware does not report the position reached.

Task side: 3-0 sends `a` then the number and returns immediately. 4-0 `moveResp` waits ≤ 30 s for
`Move complete.` or any line starting with `Error`/`ERROR` and returns `moved`, which `main.m`
never looks at (F3).

**Coordinate system.** Steps from the MIN endstop (0) to the MAX endstop (`MaxPosition`,
measured per calibration, default placeholder 45000 at `.ino:132`). Increasing steps = more
compression (consistent with the original: `scale2motorstep.m:25-26` "minimum = just touching,
max = barely possible to inhale", and the new retract spec: first contact = `MaxPosition - 15 mm`,
`docs/superpowers/specs/2026-09-24-retract-distance-setting-design.md:22-34`). Steps per mm =
100 × microsteps = 1600 at the default 16 microsteps (`.ino:754-759`). The usable stimulus range
on the new mechanics is therefore ~24000 steps (15 mm) from first contact to max, whereas the
2022 scaling assumes 26000 steps for a nominal 17 mm. **The two scales are not the same and
neither repo converts between them** (F1).

**`d`, `e`, `s`, `y`.** `d` disables and invalidates calibration (`.ino:779-790`); `e` enables and
sets `StepperStatus = 1` (`.ino:770-777`, the only path that turns fault monitoring on, F5);
`s` prints a 25-line block including `Software Version`, `Device ID`, `Current Position`,
`Max Range Limit`, `Calibrated`, `First-Contact`, speed, acceleration, current, microsteps and
lifetime stats (`.ino:1225-1313`); if a DS18B20 is fitted, `s` blocks ~750 ms for the temperature
conversion (`.ino:1265`), so do not send `s` inside a trial. `y` retracts to first contact
(`.ino:1042-1054`). None of these is used by either task version.

### 2.3 Timing

Move durations at the compiled-in defaults (trapezoidal profile, V = 16000, A = 10000; script
`scratchpad/move_time.py`):

| Distance (steps) | Time (s) |
|---|---|
| 1000 | 0.63 |
| 5000 | 1.41 |
| 12000 | 2.19 |
| 24000 (first contact to max) | 3.10 |
| 26000 (old 12000-38000 span) | 3.23 |
| 45000 (full travel) | 4.41 |

The trial structure (`main.m:230-323`) sends the move at the start of a 2 s countdown and then
runs the inhale cue (0.5 s pause + 0.8 s inhale + 0.5 s pause, `loadParams.m:183-185`). With F2
in force, every trial's first move starts from full obstruction, so half of all first-interval
moves (the no-load ones) are ~26000 steps and cannot finish inside the 2 s ISI on the original
helpers (F4). EEPROM-saved tuning (F10) changes all of these numbers.

### 2.4 Errors and recovery

| Event | Firmware | 3-0 task | 4-0 helpers |
|---|---|---|---|
| Out-of-range target | refused, `Error: ...` | unaware | `moved = 0` (ignored by task) |
| Unexpected endstop hit | auto-corrects up to 3 times, prints WARNING | unaware | WARNING swallowed, `moved = 1` |
| 3 hits | disabled, calibration invalid, `ERROR` | next `c` at a break recovers; all trials in between are refused | `moved = 0` |
| Driver fault (thermal/short) | only detected if `StepperStatus == 1` (F5) | never | never |
| Host closes port / DTR drops | emergency stop, disable, invalidate (`.ino:580-589`) | next `c` recovers | `initResp` recovers |
| Input never arrives after `a` | 15 s timeout, `ERROR: timed out waiting for input` | n/a | caught as `Error` |

### 2.5 Shutdown

3-0: `calibrateResp` (sends `c`), then `sca`, `fclose('all')` (does not close a `serialport`),
return; the global in `setupResp.m:24` keeps the port open; the firmware's calibration either
completes with the wedge at the MAX endstop or, if MATLAB exits, is aborted by the disconnect
check with the wedge stopped mid-travel and the driver disabled (F9). 4-0: `closeResp` sends `d`
and deletes the port; the wedge stays wherever the last trial left it. Neither leaves the tube
unobstructed. The right sequence is: move to no-load (first contact or 0), confirm, `d`, close.

## 3. Assessment of the `respDeviceHelpers_4-0` helpers

What is right: the move from fire-and-forget to confirmed completion is the correct design and
matches the firmware's actual strings (`initResp.m:56,61`; `moveResp.m:54,60`); the error-prefix
match is case-insensitive, which covers both `Error:` and `ERROR:` spellings; timeouts are
bounded by elapsed time, not per line; `closeResp` always deletes the port; the functions keep
the 3-0 signatures so `main.m` can swap them in.

What is wrong or missing before a task can rely on them:

1. `scale2motorstep.m` is the 2022 constants verbatim (F1). The device layer must derive the
   scale from the device: parse `Max Position: N` and `First-contact position ... : M` from the
   `c` reply (or `Max Range Limit` and `First-Contact` from `s`), and map 0-100% onto
   `[M, N - margin]`. `initResp` currently throws both numbers away.
2. `moveResp2ITIpos.m` is copied with F2 intact.
3. No `e` after `c` (F5). One extra `writeline(dev, 'e')` plus waiting for
   `Stepper enabled in normal mode` turns fault monitoring on.
4. No DTR assertion (F6).
5. Terminator: configure `"CR/LF"` so lines arrive without `\r` (F14), or strip in one place.
6. Replies are not returned to the caller. `moveResp` should return the lines it consumed (or at
   least a flag) so the task can log `WARNING` lines against the trial number. The lifetime hit
   counters prove the firmware authors expect hits to happen.
7. Buffer hygiene: drain pending input before sending a command, and after `Move complete.`
   keep reading until the `Valve>` prompt so the next call starts clean (F11).
8. `closeResp` should not be the only shutdown step; a `parkResp` (move to no-load, confirm) must
   precede it (F9).
9. `isa(respDevice, 'serialport')` in `closeResp.m:21` blocks any mock. Check for the methods
   instead, or accept an interface.
10. `readline` timeout semantics are asserted in the spec
    (`2026-10-08-respdevicehelpers-4-0-init-close-design.md:119-122`: returns empty with a
    warning) but not demonstrated; if it instead returns `[]`, `startsWith` throws and the
    try/catch reports a "communication error" (initResp) — functional but misleading, and the
    warnings will spam the command window during a session.
11. No session-start `s` capture (firmware version, Device ID, MaxPosition, microsteps, speed,
    acceleration, retract distance) — exactly the fields needed to defend the stimulus scale
    later (F10, F12).
12. No tests, no mock; the specs' test plans are hardware-only.

Verdict: usable as a starting point for the protocol handling, not usable as a stimulus
delivery layer until items 1, 2, 3, 6 and 8 are done.

## 4. Integrated repository plan

### 4.1 Layout

```
rrst/                                   # new repo, GPL-3.0 (see 4.2)
├── README.md                           # question, hardware, one-command run, test command, outputs
├── CLAUDE.md                           # short; data rules, device rules, run/test commands
├── LICENSE                             # GPL-3.0 (from original/LICENSE)
├── PROVENANCE.md                       # what came from where, at which commit, under which licence
├── CITATION.cff                        # Nikolova et al. 2022 + device credit
├── TASKS.md, VERIFICATION.md           # lab-book conventions
├── .gitignore, .gitattributes, .claude/settings.json
├── task/                               # MATLAB + Psychtoolbox task (GPL-3.0, Nikolova et al.)
│   ├── RRS_4-0/                        # experimentLauncher.m, code/main.m, loadParams.m, tutorial
│   ├── helpers/                        # from original/task/helpers (unchanged where possible)
│   └── device/                         # the device layer (replaces respDeviceHelpers_*)
│       ├── RRSTDevice.m                # class: open/calibrate/enable/move/park/status/close
│       ├── obstruction2steps.m         # pure: (% , calibration struct) -> steps
│       ├── parseStatusBlock.m          # pure: cell of lines -> struct
│       ├── parseCalibrationReply.m     # pure: lines -> MaxPosition, firstContact
│       └── MockRRSTDevice.m            # firmware simulator with fault injection
├── task/tests/                         # matlab.unittest; runtests('task/tests')
├── firmware/
│   ├── RRST_Teensy_4_version_TMC2209/  # source, vendored TeensyStep4 (MIT), LocalMenuCmd (MIT)
│   ├── releases/<codename>-<date>/     # .hex, sha256, source commit, toolchain + library versions
│   └── BUILD.md                        # exact arduino-cli invocation, how to embed the git hash
├── control_panel/                      # RRST_Control_Panel (Python, pytest), pyproject + uv.lock
├── devices/                            # per-device calibration records (see 4.4)
│   ├── README.md
│   └── <device_id>.json
├── docs/
│   ├── protocol.md                     # section 2 of this review, kept current with the firmware
│   ├── bench/                          # hardware-in-the-loop checklist + recorded results
│   ├── acceptance/                     # pre-study acceptance checklist + signed-off runs
│   └── design/                         # snejbjerg docs/superpowers specs, as history
├── data/raw|processed|generated/       # task output goes to data/raw/<study>/; FICTIONAL examples only in generated/
└── legacy/                             # original RRS_2-2, RRS_3-0, respDeviceHelpers_2-2/3-0, old firmware: read-only reference
```

`src/` is deliberately absent until two scripts share Python code; the Control Panel already has
its own module layout and tests.

### 4.2 Provenance and licensing

- The task is a derivative of a GPL-3.0 work, so the integrated repo is GPL-3.0. Keep
  `original/LICENSE` verbatim as `LICENSE`; keep every `% Niia Nikolova` header; add a
  `CITATION.cff` with the Nikolova et al. 2022 reference from `original/README.md:7-9`.
- The Snejbjerg repo has no LICENSE file. Firmware and Control Panel need an explicit licence
  from Martin Snejbjerg Jensen before redistribution: GPL-3.0 (simplest, one licence for the
  repo) or MIT/BSD (GPL-compatible, keeps the firmware reusable elsewhere). Record the choice in
  `PROVENANCE.md` and in each directory's header. Third-party pieces already have licences:
  TeensyStep4 (MIT, luni64), SerialMenuCmd/LocalMenuCmd (MIT, Armand Rolland), TMCStepper (MIT,
  not vendored), pyserial (BSD).
- Import as snapshots, not history: copy each directory at a recorded commit
  (`original` a033091, `snejbjerg` c298eed) and write the mapping into `PROVENANCE.md`
  (source URL, commit, path, licence, authors). Reasons: the original history is public anyway;
  the Snejbjerg history contains `Co-Authored-By: Claude` trailers (F20) that the organisation's
  rule says must not appear in this repo, and rewriting another person's history is not ours to
  do. Keep the two clones beside the new repo as the reference copies.
- Palamedes and Psychtoolbox are not vendored. Record the versions used in Zurich in
  `README.md` and in the per-session run record; Palamedes' licence should be checked before
  vendoring, so prefer a pinned download instruction.

### 4.3 Firmware pinning and versioning

- One directory per release under `firmware/releases/`: the `.hex`, its SHA-256, the firmware
  source commit, `arduino-cli version`, Teensyduino core version, and the versions of
  TMCStepper, OneWire and DallasTemperature (currently unrecorded, F12).
- Embed the source commit in the build so the device reports it: add
  `-DRRST_GIT_HASH="\"$(git rev-parse --short HEAD)\""` via
  `arduino-cli compile --build-property "compiler.cpp.extra_flags=..."` and print it in
  `BuildCodename()`/`cmd7_Status`. Until that firmware change is made and flashed, the pin is
  the codename-plus-timestamp string (`Patient-Regulator (Oct  7 2026 08:45:06)`) and the hex
  SHA-256.
- The task records the `Software Version` line from `s` in every data file; the acceptance
  checklist requires it to equal the pinned string. The Control Panel's
  `BUNDLED_FIRMWARE_VERSION` (`app.py:21`) is updated from the same release file, not by hand.
- Freeze the firmware for the duration of the study. The only firmware changes worth making
  before the freeze are the ones that remove task-side workarounds: set `StepperStatus = 1` in
  `cmd3_Calibrate` (F5), and report `Position:` in the `Move complete.` line. Both are small;
  both need the device to verify.

### 4.4 Per-device calibration: storage and application

Two numbers define the stimulus scale on a given unit and session: `MaxPosition` (measured by
`c`) and the first-contact offset (`RetractDistanceMm`, stored in the firmware's EEPROM, set per
unit with `r` + `v`). The task must not hard-code either.

`devices/<device_id>.json` (Device ID from the `s` line `Device ID: XXXXXXXXXXXXXXXX`, `.ino:1230`):

```json
{
  "device_id": "0123456789ABCDEF",
  "label": "Zurich unit 1",
  "firmware_pin": "Patient-Regulator (Oct  7 2026 08:45:06)",
  "microsteps": 16,
  "steps_per_mm": 1600,
  "retract_mm": 15.0,
  "max_position_steps": 45120,
  "max_position_tolerance_steps": 200,
  "first_contact_steps": 21120,
  "pct100_margin_steps": 400,
  "speed_steps_per_s": 16000,
  "accel_steps_per_s2": 10000,
  "physical_checks": {
    "pct0_paper_slip_held": true,
    "pct100_barely_inhale": true,
    "checked_by": "initials",
    "date": "2026-11-xx"
  },
  "notes": ""
}
```

Application at session start (`RRSTDevice.open`): assert DTR; drain; `s` → parse; refuse to run
if `Device ID` is not in `devices/` or `Software Version` differs from the pin or microsteps,
speed, acceleration or retract distance differ from the record; `c` → parse `MaxPosition` and
first contact; refuse if `|MaxPosition - record| > tolerance`; `e`; compute
`cal.first_contact = M`, `cal.pct100 = N - margin`; `obstruction2steps(p, cal) =
round(M + p/100 * (cal.pct100 - M))`, clamped and validated (error, not clip, on p outside
0-100). Write the whole parsed `s` block, the calibration reply and `cal` into `Results.device`
and the run record. The staircase keeps working in percent; the mm option goes away unless the
scientist wants it, in which case mm = steps / 1600 from first contact.

Re-calibration during breaks: keep it (it re-anchors drift) but compare the new `MaxPosition`
with the session's first value and log the difference; abort the session if it exceeds the
tolerance. Replace the fixed 65 s screen with a wait on the reply plus a 120 s ceiling.

ITI/resting position: replace `moveResp2ITIpos` with a jittered position in the lower part of the
range (e.g. 0-15% from first contact) or the firmware's `y` retract; the scientist decides the
intended resting load (F2 is a bug, but what the design intended must be confirmed with the
task's authors).

### 4.5 Test-first verification

Known-answer tests (pure MATLAB functions, no hardware; `runtests` needs a licensed MATLAB):

| Function | Known answers (hand-worked) |
|---|---|
| `obstruction2steps` | cal M=21120, pct100=44720: 0 → 21120; 50 → 32920; 100 → 44720; 25 → 27020; 100.5 and -1 → error; NaN → error |
| `obstruction2steps` with the 2022 constants (regression against the old scale) | 0% → 12000; 50% → 25000; 100% → 38000 (matches `rescale`) |
| the mutation that must fail | temporarily swap in the old `rescale`-based mapping: with cal M=12000, pct100=38000 and input 50 in mm mode it returns 38000 (silent clip to maximum, F2); the test asserts an error for any input outside 0-100, so the mutation fails the test |
| `parseCalibrationReply` | the literal firmware strings with and without `(previous saved: ...)`, with trailing `\r`, with the leading empty line; the two ERROR strings |
| `parseStatusBlock` | a literal 25-line `s` block → struct; Device ID preserved as a string; `(stale - not calibrated)` → `calibrated = false` |
| move-time estimate (used for the ISI budget) | 12000 steps → 2.19 s; 24000 → 3.10 s |

Mock device (`MockRRSTDevice.m`): a handle class with `writeline`, `readline`, `Timeout`,
`NumBytesAvailable`, `flush`, `delete`, `setDTR`, holding a byte queue and emulating the parser
in `LocalMenuCmd.cpp:236-343` and the replies in section 2.2 verbatim (CRLF, embedded leading
newlines, prompt). Configurable `MaxPosition`, `RetractDistanceMm`, microsteps, move time per
step, and fault injection: refuse out-of-range, one WARNING then complete, three hits then
ERROR, no DTR, drop the link mid-move, never reply. The device-layer tests then cover every row
of the section 2.4 table without a device, and the task can be run end-to-end against the mock
with `vars.RRSTdevice = 1` and Psychtoolbox in a window. A Python twin of the same mock is cheap
(the Control Panel's `port_factory` hook already supports it) and lets the two implementations
be compared on the same scripted conversation.

Hardware-in-the-loop bench checklist (`docs/bench/CHECKLIST.md`, results recorded as
`docs/bench/results/<date>-<device_id>.md` with raw serial logs attached):

1. Identify: `s` → codename equals the pin; Device ID recorded; microsteps/speed/accel/retract
   equal the device record.
2. DTR: open with MATLAB, send `c`; must not print `Serial connection lost`.
3. Calibrate three times; `MaxPosition` repeatable within tolerance; record the times.
4. Physical mapping: move to 0% and check the paper-slip test; move to 100% and confirm "barely
   possible to inhale" by the experimenter; move to 50% and record the airflow resistance if a
   manometer/flow meter is available (this is the only check that ties steps to the construct).
5. Move timing: time 0→100%, 100→0%, 0→50%, from the serial log timestamps; compare with the
   model; set the ISI/countdown accordingly.
6. Error paths: out-of-range `a` refused; disable then `a` refused; unplug mid-move → firmware
   message and MATLAB `moved = 0`; re-init recovers.
7. Endstop strike at 100%: confirm the margin keeps `Total Max Hits` constant across 20 moves.
8. Thermal: 45 minutes of trial-like motion; `x` diagnostics and heat-sink temperature at 0, 15,
   30, 45 min; fault monitoring active (`Stepper Enabled: YES` after `e`).
9. Shutdown: park at no-load, `d`, close; port reopens without restarting MATLAB.
10. Full dry run of the task on the device with `subNo = 9999`, Psi, confidence on; inspect the
    saved `Results.device` and per-trial move logs.

Pre-study acceptance checklist (`docs/acceptance/`): the bench checklist passed on the Zurich
unit within the last N days, firmware pin matches, device record committed, task version tag,
Psychtoolbox and Palamedes versions recorded, a 9999 dry run saved and reviewed, the
scientist's sign-off on the resting-load decision (F2) and the 100% margin (F15), and the
`VERIFICATION.md` entries ticked with links.

### 4.6 Data separation

Task output stays out of Git (`data/raw/<study>/`), with the lab `.gitignore` and
`.claude/settings.json` deny rules. The dry-run file from subject 9999 is the only committed
example and is labelled FICTIONAL. The data dictionary documents `Results` fields, adding
`device.*` and per-trial `moveLines`, `moveDuration_s`, `stepsCommanded`.

## 5. Ordered implementation plan

Steps marked [device] need the physical Zurich unit; the rest run on this machine (MATLAB
licence permitting) or any machine with Python.

| # | Step | Acceptance criteria | Device |
|---|---|---|---|
| 1 | Scaffold the repo (layout 4.1, LICENSE, PROVENANCE.md, CITATION.cff, CLAUDE.md, TASKS.md, VERIFICATION.md, .gitignore, deny rules) and import snapshots of both repos into `legacy/`, `firmware/`, `control_panel/`, `task/helpers/`, `docs/design/`. | `git ls-files` shows no data; PROVENANCE lists both commits; `uv run pytest control_panel` passes 62 tests; no attribution trailers in history. | no |
| 2 | Pin the firmware: `firmware/releases/Patient-Regulator-20261007/` with the hex, SHA-256, source commit 13abac7, and a BUILD.md; `app.py:21` reads the pin. Record the unknown library versions as TODO. | SHA-256 recorded; README states the pin; TODO list names the three unrecorded libraries. | no |
| 3 | Write `docs/protocol.md` from section 2 and the pure parsers' known answers (section 4.5) as failing tests (test-first commit). | `runtests` reports the expected failures; expected strings are copied from the firmware source with line references. | no (MATLAB licence) |
| 4 | Implement `parseCalibrationReply`, `parseStatusBlock`, `obstruction2steps`; mutation check (restore the old `rescale` clip and watch the test fail). | All known-answer tests pass; mutation detected; VERIFICATION.md updated. | no |
| 5 | Implement `MockRRSTDevice` (and the Python twin) from the firmware parser and reply strings; scripted-conversation tests for every error path in 2.4. | Device-layer tests pass against the mock, including DTR-missing, out-of-range, WARNING+complete, 3-hit ERROR, disconnect, timeout. | no |
| 6 | Implement `RRSTDevice` (open with DTR, drain, `s`, `c`, `e`, confirmed `move`, `park`, `close`; returns consumed lines; configurable timeouts; CR/LF terminator). | Passes the mock suite; `moveResp`-compatible wrappers exist for the transition; no hard-coded step constants anywhere (`grep 12000`, `38000` empty outside `legacy/`). | no |
| 7 | Create `RRS_4-0` from `RRS_3-0`: fix F3 (abort or repeat the trial on `moved = 0`, log it), F7 (`resetResp` → `park`), F8 (argument order), F16 (`isfield`), F17 (no global), F18 (device discovery by Device ID), replace the 65 s screen with a reply wait, record `Results.device` and per-trial move logs, make the ISI countdown start after `Move complete.` and log the actual move duration, replace `moveResp2ITIpos` with the scientist's chosen resting position, park-then-disable on every exit path. | Full task runs end to end against the mock with Psychtoolbox in a window; the saved file contains device metadata and per-trial move durations; an injected refused move produces a logged repeat, not a silent trial. | no (Psychtoolbox install) |
| 8 | Device record and calibration procedure: `devices/README.md`, JSON schema, `scripts/record_device.m` that runs `s` + `c` and writes the record; set `r` + `v` on the unit via the Control Panel. | A record for the Zurich unit is committed; MaxPosition repeatability measured; physical 0%/100% checks recorded with initials. | **yes** |
| 9 | Bench checklist run (4.5 items 1-9), results committed with raw logs. Resolve F6 (DTR), real move times, thermal behaviour. Decide ISI from measured move times. | Every item has a recorded result; DTR behaviour stated as fact; move-time table updated from measurements. | **yes** |
| 10 | Optional firmware patch before freeze: `StepperStatus = 1` in `cmd3_Calibrate` (F5); `Move complete. Position: N`; embedded git hash. Rebuild, re-pin, re-run steps 8-9. | New pin recorded; `s` reports the hash; fault monitoring active after `c` alone (`x` shows live readings while enabled). | **yes** |
| 11 | Dry run of the full task on the device (subject 9999, Psi, confidence on, tutorial on), review the data file and move logs, time the session. | File reviewed by the scientist; no refused or warned moves, or each one explained; session length acceptable. | **yes** |
| 12 | Pre-study acceptance checklist signed; tag the repo; write the AI-assistance record; freeze. | Tag exists; acceptance document links bench results, device record, firmware pin, task tag. | **yes** |

Decisions that belong to the scientist, not the implementer: the intended resting load between
trials (F2); whether 100% should sit at a margin below the endstop (F15) and how large; whether
to keep the mm stimulus scale; whether re-calibration at breaks stays; the ISI value once move
times are measured; the thermal limits for a session.

## 6. Minimal first-contact script for the Zurich unit

Run before anything else, by hand, in MATLAB with the device attached (this is the first item of
the bench checklist and resolves the device-identity and DTR questions in one minute):

```matlab
d = serialport("COMx", 115200); configureTerminator(d, "CR/LF"); setDTR(d, true);
d.Timeout = 3; flush(d);
writeline(d, "s"); pause(2); while d.NumBytesAvailable > 0, disp(readline(d)); end
% Expect: "Software Version: Patient-Regulator (Oct  7 2026 08:45:06)", a Device ID line,
% "Calibrated: NO". If the reply is a bare number echo or nothing, this is not the
% dual-endstop firmware.
```

## Appendix A. Scratch files

- `scratchpad/rescale_check.py`: reproduction of F2 from the documented `rescale` formula.
- `scratchpad/move_time.py`: trapezoidal move-time model for the F4 table.
- `scratchpad/matlab_checks.m`: the MATLAB batch checks that could not run (licence expired);
  run it in a licensed MATLAB to confirm F2, F16, the global-after-`clear all` question and the
  `readline` timeout behaviour.
- `scratchpad/session_protocol.txt`: text extraction of `docs/rrst-session-protocol.html`.
- `scratchpad/orig_teensy4_zip/`: the unpacked intermediate Teensy 4 firmware from
  `original/task/arduino/RRST_Arduino/RRST_Teensy_4_version.zip` (reports `2026r5`; already has
  `Move complete.` and the calibration gate, no endstop guard, no EEPROM).

## Appendix B. Line references used above (firmware = `snejbjerg/RRST_Teensy_4_version_TMC2209/RRST_Teensy_4_version_TMC2209.ino`)

21-22 SPEED/ACCELERATION defaults; 31 DefaultRetractDistanceMm; 44 CommandInputTimeoutMs;
51-54 homing speeds; 132 MaxPosition default; 329 Serial.begin(115200); 371-385 EEPROM tuning
applied at boot; 455-463 BuildCodename; 535-537 fault monitor gated on StepperStatus; 580-589
CheckSerialConnection; 686-700 WaitForCommandInput; 754-768 StepsPerMm/RetractSteps; 770-777
cmd1 enable; 779-790 cmd2 disable; 803-898 SeekEndstopPrecise; 900-976 cmd3_Calibrate; 1042-1054
cmd22_Retract; 1067-1202 MoveAbsWithEndstopGuard; 1204-1223 cmd6_AbsoluteMove; 1225-1313
cmd7_Status; 1372-1404 cmd12_Microsteps; 1532-1548 cmd18_SaveSettings.
`LocalMenuCmd.cpp`: 236-343 UserRequest (single-char commands, CR/LF execution).
Task: `original/task/RRS_3-0/code/main.m` 44-57 device init, 141-166 65 s wait, 173 first move,
230-323 trial moves and ISI, 241 isfield bug, 436 ITI move, 457 experimentEnd bug, 700-716 end;
`loadParams.m` 17 COM5, 64 RDunitscale=1 for Psi, 75 stimRange 0-17 mm, 183-188 timing;
`respiroceptionTutorial.m` 458 resetResp; `respDeviceHelpers_3-0/scale2motorstep.m` 31-42;
`moveResp2ITIpos.m` 11-14; `setupResp.m` 24 global.
