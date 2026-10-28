# Firmware and Control Panel

The 2.0 firmware (`firmware/RRST_Teensy_4_version_TMC2209/`) and the **RRST Control
Panel** (`control_panel/`) were written by Martin Snejbjerg Jensen. The Control Panel is
the normal way to flash, inspect and tune a device. The full feature guide is
`docs/control_panel_USER_MANUAL.md` in the repository.

## Flashing with the Control Panel (recommended)

The app bundles a pre-built `.hex` and the PJRC `teensy_loader_cli`, so **no Arduino
installation is needed**.

1. Run the Control Panel. You can use a built executable or run it from source:
   ```bash
   cd control_panel
   pip install -r requirements.txt
   python app.py
   ```
2. Connect to the device's serial port.
3. Click **Flash Firmware**. The app reboots the Teensy into its bootloader and uploads
   the bundled firmware. It refuses to flash when more than one device is connected, so
   it can't pick the wrong one.
4. Reconnect. **Live Status** should show the new `Software Version`.

The bundled build is **"Patient-Regulator" (Oct 7 2026 08:45:06)**. Its SHA-256 is
recorded in `PROVENANCE.md`.

!!! todo "TODO(Martin): building the executable"
    Document where lab members get a ready-built Control Panel for Windows and macOS, so
    they don't need Python.

## Building from source (developers)

```bash
cd firmware/RRST_Teensy_4_version_TMC2209
arduino-cli compile --fqbn teensy:avr:teensy40 --library ./TeensyStep4-main .
```

You also need the Teensy platform for `arduino-cli`, and the TMCStepper, OneWire and
DallasTemperature libraries.

!!! todo "TODO(Martin): pin library versions"
    Record the exact versions of TMCStepper, OneWire, DallasTemperature and the Teensy
    core used for the shipped build, so the `.hex` can be reproduced.

## Serial protocol (summary)

Connect at 115200 baud. The host must **assert DTR**: the firmware treats a port without
DTR as disconnected and switches the driver off. Commands are single characters followed
by newline. Commands that take a value expect the value on its own line next. Every
reply ends with the prompt `Valve>`.

| Key | Command | Key | Command |
|---|---|---|---|
| `s` | Status (read-only) | `c` | Calibrate: min endstop, then max endstop |
| `e` | Enable driver | `d` | Disable driver (invalidates calibration) |
| `a` + value | Move to an absolute position (steps) | `y` | Retract to the computed first-contact position |
| `f` / `g` | Set speed / acceleration | `i` / `p` | Set run current (mA) / hold current (%) |
| `u` | Set microsteps | `t` | Toggle SpreadCycle / StealthChop |
| `w` | Fan mode | `r` | Set retract distance |
| `v` | Save settings to EEPROM | `z` | Reset to defaults |
| `x` | Driver diagnostics | `l` | Endstop event log |
| `k` | Verify position against the max endstop | `h`, `o`, `m` | Home, safe-mode check, menu |

!!! warning "Settings persist"
    Anything saved with `v` (current, speed, acceleration, microsteps, chopper mode,
    retract distance) is reloaded at every boot. That silently changes motor timing and
    step scaling for every later session. Record the `s` output with each study, and
    don't change saved settings mid-study.

!!! note "After calibrating, enable"
    `c` powers the driver but doesn't set the firmware's "enabled" flag, and driver-fault
    monitoring only runs while that flag is set. The toolkit's task software sends `e`
    after every `c`. Do the same in any other software.

## Current tuning

The defaults are 800 mA run current, 50 % hold current, 16 microsteps and SpreadCycle.
The hold current applies whenever the motor is enabled but stationary, which is most of
a session. Following the modification checklist:

1. Send `x`. Every field should read OK, with no UART warning and no FAULT/SHUTDOWN.
2. With the wedge closed on the tube, lower the hold percentage with `p` step by step,
   and find the lowest value that still holds against the tube's back-pressure.
3. Save with `v` once you're satisfied. Record the value.

!!! todo "TODO(Martin): recommended defaults"
    Give recommended run current, hold %, speed, acceleration and chopper mode for the
    Motech motor, including whether StealthChop is quiet enough for participants and
    still reliable (the Control Panel's sweep test is the tool for this).
