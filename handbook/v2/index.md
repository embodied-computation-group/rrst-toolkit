# RRST 2.0 (2026)

!!! warning "Draft: needs the engineer's review"
    This section is a first draft, assembled from Martin Snejbjerg Jensen's firmware
    repository, his hardware-modification checklist (2026-09-22) and the toolkit's own
    code. Every `TODO(Martin)` box marks something only he can confirm. Photos of the
    2.0 devices are still to be taken (see the [roadmap](../roadmap.md)).

## What changed from the legacy device

| | Legacy (v3-0, 2022) | RRST 2.0 |
|---|---|---|
| Microcontroller | Teensy 3.1/3.2 (discontinued) | **Teensy 4.0** |
| Stepper driver | TMC2100 (current set by trimpot) | **TMC2209** (BigTreeTech v1.2), configured over UART |
| Motor current | Fixed by the trimpot; the motor holds at full current between trials and runs hot | Run current, hold current (% of run), microstepping and chopper mode set in software and saved to EEPROM |
| Stepper motor | E3D "Super Whopper" (no longer sold, see [GitHub issue #1](https://github.com/embodied-computation-group/RespiroceptionMethodsPaper/issues/1)) | Motech MT-1705HS200AE (rated 2.0 A) per the checklist. `TODO(Martin)`: confirm for all units |
| Calibration | Homes to the min endstop, then finds the max endstop | The same, with a fast approach then a slow re-approach for a repeatable trigger point; reports `MaxPosition` and a computed first-contact position |
| Safety | None | Driver-fault monitoring; auto-correction of unexpected endstop hits, then a safety disable; the driver switches off if the serial connection drops; soft limits on moves |
| Supply protection | None | Bulk capacitor, series Schottky diode and TVS diode on the motor rail (bench modification) |
| Tools | Arduino IDE | **RRST Control Panel** desktop app: live status, tuning, a speed/acceleration sweep test, and one-click firmware flashing (no Arduino install needed) |
| Task software | `RRS_2-2` / `RRS_3-0` (fire-and-forget moves) | RRST Toolkit 2.0 task: every calibration and move is confirmed and logged; stimulus anchors measured per device. *In development* |
| Telemetry | — | Device ID, firmware version, lifetime run time, distance and endstop hits, optional heat-sink temperature (DS18B20) |

The mechanics are unchanged: the housing, wedge, leadscrew, rods, bearings and
breathing circuit are the same as the legacy v3-0 device. Build those parts from
[Legacy → Build](../legacy/build.md), then follow the 2.0 pages for the electronics.

## Pages

1. [Parts](parts.md): what differs from the legacy parts list.
2. [Electronics (TMC2209 conversion)](electronics.md): converting a v3-0 board.
3. [Firmware and Control Panel](firmware.md): flashing, the serial protocol and tuning.
4. [Bench check and calibration](bench-check.md): what to verify before any participant
   sits down.

!!! todo "TODO(Martin): new PCB?"
    Martin's README says the TMC2209 is currently hand-wired onto the existing board,
    with a clean PCB respin planned (switchable fan, reverse-polarity protection, a
    connector for the temperature sensor). Is there a respun board, and if so where are
    its Gerbers? The Eagle schematic in `hardware/RRST_eagle_schematics.sch` is dated to
    the modification checklist.
