# RRST 2.0 parts

Start from the [legacy parts list](../legacy/parts.md). Mechanics and accessories are
the same. The table below lists only what **changes or is added** for 2.0. Availability
is tracked on [Parts sourcing](../parts-sourcing.md).

| Part | Specification | Qty | Replaces | Notes |
|---|---|---|---|---|
| Microcontroller | **Teensy 4.0** (PJRC) | 1 | Teensy 3.1 | `TODO(Martin)`: pin headers; whether the USB-power trace is cut as on the legacy board (see [legacy build, step 3](../legacy/build.md#step-3-mount-the-components-on-the-pcb)) |
| Stepper driver | **BigTreeTech TMC2209 V1.2** (legacy pinout, drop-in StepStick) | 1 | TMC2100 SilentStepStick | Sense resistor 0.11 Ω; UART address 0 (MS1 = MS2 = GND) |
| Stepper motor | **Motech MT-1705HS200AE**, NEMA 17, rated 2.0 A | 1 | E3D Super Whopper | Named in the modification checklist. `TODO(Martin)`: confirm this is the standard motor for 2.0 units, its body length versus the housing, and the default run current (800 mA in firmware) |
| UART series resistor | ~1 kΩ | 1 | — | Teensy TX1 → driver PDN_UART (MS3 pad) |
| Enable pull-up | 10 kΩ (R1) | 1 | — | EN pad → 3.3 V, so the driver stays off during power transients |
| Bulk capacitor | 220 µF, 35 V, electrolytic, radial (C7) | 1 | — | Across VMOT/GND, close to the driver socket |
| Decoupling capacitor | 100 nF ceramic (C8) | 1 | — | In parallel with C7 |
| Series diode | **SS34** Schottky, 3 A / 40 V (D1) | 1 | — | Reverse-polarity protection in the barrel-jack → VMOTOR path |
| TVS diode | **SMBJ26A**, 26 V standoff (D2) | 1 | — | Across VMOTOR/GND. See the note below |
| Jumper wires / 0 Ω links | — | 2 | — | CFG1/CFG2 (MS1/MS2) pads to GND |
| Hook-up wire | — | 2 | — | UART RX/TX taps |
| Temperature sensor (optional) | DS18B20 on pin 4 | 0–1 | — | Detected automatically at boot |
| Fan | `TODO(Martin)` | 1 | 24 V fan | Firmware fan control (pin 2) is ready, but switching hardware arrives with the planned PCB respin |
| Power supply | `TODO(Martin)`: voltage and current rating for the 2.0 units | 1 | Multicomp Pro MP007794 | The TMC2209's absolute maximum supply is about 32–33 V; a 24 V supply leaves little margin |

!!! todo "TODO(Martin): reconcile the protection parts"
    The firmware repo README lists a **P6KE30A** TVS diode and says reverse-polarity
    protection is planned for a future PCB. The modification checklist (2026-09-22)
    specifies an **SMBJ26A** TVS and an **SS34** series Schottky, and explains why the
    SMBJ26A is preferred (the TMC2209's absolute maximum is about 33 V). Which is fitted
    on the shipped units?

!!! todo "TODO(parts): sourcing links"
    Add supplier links for each 2.0 part once [Parts sourcing](../parts-sourcing.md) has
    been checked.
