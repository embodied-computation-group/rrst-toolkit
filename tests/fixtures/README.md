# Firmware transcript fixtures

Each `.txt` file holds the exact bytes the firmware sends in reply to one command, up to
and including the `Valve>` prompt. Line endings are mixed on purpose and must stay that
way. `println` sends CRLF, but `printf("...\n")` and `F("\n...")` send a bare LF.
`.gitattributes` marks these files `-text` so Git never normalises them.

**Origin: constructed from source.** All files were transcribed by hand from the format
strings in `RRST_Teensy_4_version_TMC2209.ino` at Msnejbjerg/RRST commit `c298eed`. None
was captured from hardware. The numbers are fictional: `MaxPosition` 45123, device ID
`0123456789ABCDEF`. The usage-statistics lines in `status_calibrated.txt` are
illustrative.

At the first bench session, capture real replies and save them next to these files as
`<name>__device_<id>__<date>.txt`. The parser tests should then run on both.

| File | Command sent |
|---|---|
| `calibrate_ok.txt`, `calibrate_ok_first.txt` | `c` (with and without a previously saved max) |
| `calibrate_fail_min.txt`, `calibrate_fail_max.txt` | `c`, endstop not found |
| `move_ok.txt` | `a`, then `32500` |
| `move_ok_with_warning.txt` | `a` + `32500`, with one auto-corrected endstop hit |
| `move_out_of_bounds.txt`, `move_not_calibrated.txt` | `a` + value, refused |
| `move_safety_disable.txt` | `a` + value, three unexpected hits, then the driver is disabled |
| `move_connection_lost.txt` | `a` + value, `CheckSerialConnection()` fails mid-move (e.g. DTR not asserted): no `Move complete.` and no ERROR line |
| `enable.txt`, `disable.txt` | `e`, `d` |
| `status_calibrated.txt`, `status_uncalibrated.txt` | `s` |
| `status_uncalibrated__fw_Vigilant-Piston__2026-10-28.txt` | `s`. **Captured from device** (first 2.0 unit, firmware "Vigilant-Piston (Oct  1 2026 11:30:50)", which predates the device ID line) on 2026-10-28, uncalibrated after power-up. Starts with the firmware's echo of `s` |
| `status_uncalibrated__device_2E4441D76D5F2996__2026-10-28.txt` | `s`. **Captured from device** 2E4441D76D5F2996 (the same unit) on 2026-10-28, right after flashing Patient-Regulator; uncalibrated |
| `calibrate_ok__device_2E4441D76D5F2996__2026-10-28.txt`, `enable__device_2E4441D76D5F2996__2026-10-28.txt` | `c` then `e`. **Captured from device** 2E4441D76D5F2996 on 2026-10-28 by `bench/calibrateAndCapture.m`, no tube fitted |
| `status_uncalibrated_raw_bytes__device_2E4441D76D5F2996__2026-10-28.txt` | `s`. **Captured from device** 2E4441D76D5F2996 on 2026-10-28 with pyserial and written byte for byte (the other captures went through MATLAB `char`). Starts with the echo of `s`; includes the usage statistics and endstop lines. Shows that `²` arrives as UTF-8 (C2 B2) |
