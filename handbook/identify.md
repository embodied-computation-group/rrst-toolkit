# Which device do I have?

Open the bottom shell and look at the board.

| You see | Generation | Go to |
|---|---|---|
| **Teensy 4.0** and a **BigTreeTech TMC2209** module, with extra wires and components soldered near the driver socket | RRST 2.0 (2026) | [RRST 2.0](v2/index.md) |
| **Teensy 4.0** and a TMC2100 driver | Interim Teensy 4 build (2026, before the TMC2209 conversion) | [RRST 2.0](v2/index.md). Convert the driver: see [Electronics](v2/electronics.md) |
| **Teensy 3.1/3.2** and a **TMC2100 SilentStepStick**, one PCB labelled "Martin Snejbjerg Jensen CFIN v1.0", **two** endstop switches | Legacy, hardware v3-0 (May 2022 onwards) | [Legacy device](legacy/index.md) |
| Teensy 3.1, **one** endstop switch, hand-wired (no PCB), vice-clamp housing | Legacy, hardware v2-2 (2021, used in the methods paper) | [Legacy device](legacy/index.md) |

You can also ask the firmware. Connect over USB at 115200 baud, then send `s`, followed
by Enter:

- **2.0 firmware** prints a `--- SYSTEM STATUS ---` block. It includes `Software Version`
  (a codename such as "Patient-Regulator" plus the build date) and a 16-digit
  `Device ID`.
- **Legacy v3-0 firmware** answers to single-letter commands (`m` shows the menu), but
  has no codename or device ID.
- **Legacy v2-2 firmware** accepts only a bare number (a target position) and has no
  menu.

!!! todo "TODO(Martin): confirm the identification table"
    Confirm which generations exist in the field, and whether any 2.0 units were built on
    a new PCB rather than converted v3-0 boards.
