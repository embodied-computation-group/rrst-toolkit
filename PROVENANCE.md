# Provenance

The files listed here were copied from the source repositories at the commits shown
(`git archive <commit> <paths>`). The import commits contain no content changes. The
one exception is line endings: text files are stored with LF because of
`.gitattributes`. Binaries (`.hex`, `.exe`, `.pdf`, the macOS flasher) are stored
unchanged; their SHA-256 sums are below.
Every later modification is a separate commit, so `git diff <import commit>` shows
exactly what changed.

## Licence

This repository is distributed under **GPL-3.0** (`LICENSE`). The original task is
GPL-3.0, so any combined work must be too. Martin Snejbjerg Jensen's firmware, Control
Panel and device helpers were written in the course of his employment at CFIN, Aarhus
University, and are included under GPL-3.0 by decision of the PI (Micah Allen,
2026-10-28). The bundled third-party components keep their own licences:

| Component | Path | Licence | Notes |
|---|---|---|---|
| TeensyStep4 (luni64) | `firmware/RRST_Teensy_4_version_TMC2209/TeensyStep4-main/` | MIT | `LICENSE.md` kept in place |
| SerialMenuCmd (Armand Rolland), local fixed version | `firmware/.../LocalMenuCmd.{h,cpp}`, `SerialMenuCmdLang.h` | MIT | notice kept in file headers |
| teensy_loader_cli (PJRC) | `control_panel/firmware/teensy_loader_cli{,.exe}` | GPL-3.0 | upstream ships `gpl3.txt`; source header says GPL v3. Martin built the `.exe` from v2.3 (`03fca41`), see `control_panel/README.md` |
| Psychtoolbox, Palamedes | not included | | installed separately |
| TMCStepper, OneWire, DallasTemperature (Arduino libraries the firmware builds against) | not included | | **versions not recorded upstream**; record them at the next firmware build |

## Sources

### RespiroceptionMethodsPaper (task)
- Repository: https://github.com/embodied-computation-group/RespiroceptionMethodsPaper
- Commit: `a0330917e57cb5e6a8706bd86eac751eb6863698`
- Authors: Niia Nikolova and the Embodied Computation Group. Cite Nikolova et al.
  (2022), *Biological Psychology* 170:108325.

| Source path | Destination | Notes |
|---|---|---|
| `task/RRS_3-0/` | `task/RRS_3-0/` | base for the 2.0 task |
| `task/helpers/` | `task/helpers/` | `expandingRing60.avi` (25 MB) **not imported**: only the commented-out movie stimulus (`showExpandingRing.m`) uses it; the task uses `showExpandingRingGenerated.m`. Get it from the source commit if needed. |
| `task/respDeviceHelpers_3-0/` | `task/respDeviceHelpers_3-0/` | reference only; replaced by `device/+rrst` |
| `LICENSE` | `LICENSE` | |
| `task/apparatus/version_2-2/`, `task/apparatus/version_3-0/` | `hardware/legacy/version_2-2/`, `hardware/legacy/version_3-0/` | legacy 3D-print STLs, PCB Gerbers/CAM files and layout PDF, build photos (2022); `.DS_Store` files dropped. Imported on the `handbook` branch |
| `figs/RRST_devicePhoto.png` | `hardware/legacy/RRST_devicePhoto.png` | |
| `task/arduino/RRST_Arduino/` | `firmware/legacy/` | Teensy 3.1 sketches (`RRST_Arduino.ino`, `Resp_valve_3-0.ino`) and the May-2026 `RRST_Teensy_4_version.zip` |

### Msnejbjerg/RRST (firmware, Control Panel, 4-0 helpers)
- Repository: https://github.com/Msnejbjerg/RRST (private)
- Commit: `c298eedcc77eb046d0b9fae253f2a3d6346d8bb0` (first import), updated to
  `8720abce198c3a587358664a4159fc307e2683f9` (2026-10-28, with Martin's reply to our
  questions: `context/sources/Martin_reply_2026-10-28.pdf`)
- Author: Martin Snejbjerg Jensen, CFIN, Aarhus University.
- Imported as a snapshot, without history. Each update is one commit with no content
  changes; `git -C <Msnejbjerg/RRST> diff <old> <new> -- <paths>` shows what changed.

| Source path | Destination | Notes |
|---|---|---|
| `RRST_Teensy_4_version_TMC2209/` | `firmware/RRST_Teensy_4_version_TMC2209/` | firmware source |
| `RRST_Control_Panel/` | `control_panel/` | Python app, tests and bundled firmware |
| `task/respDeviceHelpers_4-0/` | `task/respDeviceHelpers_4-0/` | reference only; replaced by `device/+rrst` |
| `build_firmware.sh` | `firmware/build_firmware.sh` | added at 8720abc; stamps the git commit into the build. Reference only: its paths are Martin's layout (`RRST_Control_Panel/`), not this repo's |
| `USER_MANUAL.md` | `docs/control_panel_USER_MANUAL.md` | |
| `docs/rrst-session-protocol.html` | `docs/rrst-session-protocol.html` | Some claims ("zero task changes needed", the enabled flag being "cosmetic", the ITI at "50 % ± 30 %") are contradicted by the 2026-10-28 integration review |
| `RRST_eagle_schematics.sch` | `hardware/` | |
| `docs/RRST_Hardware_Modification_Checklist.pdf` | `hardware/` | TMC2100 to TMC2209 bench modification |

Not imported: `legacy/` (the Teensy 3.1 single-endstop firmware for another study),
`docs/superpowers/` (design history; read it in the source repo at the commit above),
`IMG_0624.HEIC`. Martin's root `README.md` (its new build section is covered by `firmware/build_firmware.sh`).

## Firmware binaries (SHA-256)

| File | SHA-256 | Build |
|---|---|---|
| `control_panel/firmware/RRST_Teensy_4_version_TMC2209.hex` | `39edf48c20a65df3bcd4ba4f2c663cf9268dee12505aff01ced9c63e28415d3b` | "Precise-Piston (Oct 28 2026 12:07:57)", per `BUNDLED_FIRMWARE_VERSION` in `app.py`; Martin's commit `d447c06` says it was built from `aa8dd72` with `build_firmware.sh`. Checked here: the hex contains the string `aa8dd72` (the `Git Commit:` stamp) and the `Git Commit:` status line. Not independently rebuilt. Martin flashed this build onto his unit; **unit 2E4441D76D5F2996 still runs Patient-Regulator** (flashed 2026-10-28, see TASKS.md). |
| (previous bundled hex, until 8720abc) | `dcd17a6ce066fbed42259f09890a6be8f3fa7240d878d355a2f887e36f6e2e2b` | "Patient-Regulator (Oct  7 2026 08:45:06)", per `BUNDLED_FIRMWARE_VERSION` in `app.py`. Martin's source commit `13abac7` (2026-10-07 08:45:26) is the last firmware-source change before this build. The hex timestamp is 20 s earlier than that commit, so it was probably built from the working tree just before committing. Not independently rebuilt. |
| `control_panel/firmware/teensy_loader_cli.exe` | `9c3cff875c08994fd5cd31eee96a0a066148bd6e59164541387689c49e009756` | Windows build of PJRC v2.3 |
| `control_panel/firmware/teensy_loader_cli` | `edbd52fc415eac5303373d3c2b9652d29dd0a52f37a43b2a3337dd4bd7fcd4fb` | macOS build |
