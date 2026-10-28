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
| `enable.txt`, `disable.txt` | `e`, `d` |
| `status_calibrated.txt`, `status_uncalibrated.txt` | `s` |
