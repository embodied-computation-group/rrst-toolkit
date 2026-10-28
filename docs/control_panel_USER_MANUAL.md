# RRST Control Panel — User Manual

This manual explains every feature of the RRST Control Panel app, panel
by panel. For build/install instructions see [`README.md`](README.md).
If you're trying to understand how the `RRS_3-0` MATLAB research task
drives the device directly over serial (not through this app), see
[`docs/rrst-session-protocol.html`](docs/rrst-session-protocol.html)
instead.

## Connecting to a device

1. Plug the device in via USB. Click **Refresh Ports** if it doesn't
   appear in the **Port** dropdown.
2. Select the port and click **Connect**. The dot in the top-right
   turns green ("● Connected") once the serial link is open.
3. Click **Connect** again (now labeled **Disconnect**) to close the
   link. All other controls are grayed out while disconnected.

Every control in the app works by sending a single-character command
over serial (shown in parentheses below, e.g. "sends `'c'`") — the same
protocol you'd use typing directly into a terminal. The **Live Status**
panel polls the device automatically every 1.5 seconds while connected,
so most fields update on their own without any action from you.

### Flash Firmware

Flashes the firmware bundled with this app release onto a connected
Teensy 4.0 — no separate Arduino toolchain needed. The button's tooltip
always shows exactly which build is bundled (e.g. "Flash Firmware
(bundled: Patient-Regulator, Oct 7 2026)").

- Disconnects automatically first if you're currently connected — the
  serial port can't be held open by two things at once.
- Refuses to proceed if more than one Teensy is connected, since there's
  no way to target a specific one — disconnect all but the device you
  want to flash first.
- Refuses to proceed if no Teensy is found at all.
- Refuses to proceed if a Sweep Test is currently running (both use the
  serial connection).
- **macOS:** after clicking, you'll be prompted to press the small
  physical button on the Teensy board to enter programming mode —
  automatic reboot isn't supported on this platform.
- **Windows:** the reboot into programming mode happens automatically;
  the button press is only needed as a fallback if that doesn't work.

## Motor Control

| Control | What it does |
|---|---|
| **Enable** | Energizes the stepper driver (sends `'e'`). The motor holds position and responds to moves. |
| **Disable** | De-energizes the driver (sends `'d'`). Removes holding torque — the mechanism can then be moved by hand, which means calibration is no longer trusted afterward. |
| **Calibrate** | Homes to the min endstop, then finds the max endstop (sends `'c'`). Required before any absolute move. Reports the calibrated range and compares it against the last saved calibration, so you can spot mechanical drift. |
| **Home** | Moves to position 0 (sends `'h'`). Requires calibration first. |
| **Retract** | Moves to the calibrated **First-Contact** position (sends `'y'`) — a step short of the hard max endstop, intended as the resting position between trials. Requires calibration first. |
| **Safe Mode** | Verifies the software soft-limits are active (sends `'o'`). |
| **Move to (steps)** | Enter a target absolute step position and click **Set** (sends `'a'`) to move there. Refused if the target falls outside the calibrated range. Requires calibration first. |

**A stepper motor has no absolute position feedback** — "Current
Position" is only trustworthy once calibrated, and calibration is lost
any time the driver is disabled (including a lost serial connection or
a safety disable from repeated unexpected endstop hits).

## Tuning

| Field | What it sets |
|---|---|
| **Speed (steps/s)** | Maximum stepper speed (sends `'f'`). |
| **Acceleration (steps/s²)** | Stepper acceleration/deceleration rate (sends `'g'`). |
| **Run Current (mA)** | TMC2209 RMS run current, 1–2000 mA (sends `'i'`). The driver quantizes this to its nearest supported step, so the confirmed value may differ slightly from what you typed. |
| **Microsteps** | Microstepping resolution — 0 (full-step), 2, 4, 8, 16, 32, 64, 128, or 256 (sends `'u'`). |
| **Hold Current (%)** | Holding current as a percentage of run current, 0–100 (sends `'p'`). Applied automatically whenever the stepper is enabled but not moving — this is what lets the device stay cool when idle between trials, unlike older TMC2100-based devices where hold current was effectively stuck at run current. |
| **Retract Distance (steps)** | Distance back from the max endstop used to compute the "First-contact position" safety target (sends `'r'`). Must be greater than 0. The field next to it shows the equivalent distance in mm at the device's currently reported microstepping. |

Buttons below the tuning fields:

- **Save Settings** — saves run current, hold %, speed, acceleration,
  microsteps, chopper mode, and retract distance to the device's EEPROM
  (sends `'v'`) so they reload automatically on the next power-up.
- **Reset to Defaults** — after a confirmation dialog, clears the
  endstop log and resets run current, hold %, speed, acceleration,
  microsteps, chopper mode, and retract distance to their compiled-in
  defaults (sends `'z'`), overwriting the saved EEPROM settings. Also
  resets the lifetime **Peak Heat Sink Temp** to "never recorded" — the
  one lifetime statistic this clears, since a fresh start after
  swapping a heat sink or fan is a real use case the others don't have.
  Calibration and Saved Max Pos are **not** affected.

## Modes / Diagnostics

| Control | What it does |
|---|---|
| **Toggle Chopper Mode** | Switches between **SpreadCycle** (louder, full torque/speed headroom) and **StealthChop** (near-silent, reduced high-speed torque) (sends `'t'`). |
| **Toggle Fan Mode** | Cycles the cooling fan between **Auto** (temperature-based), **Forced ON**, and **Forced OFF** (sends `'w'`). |
| **Driver Diagnostics** | Reads the TMC2209's latched fault flags — overtemperature, short-to-ground, short-to-supply (sends `'x'`). Flags stay latched until the driver is disabled and re-enabled. |
| **Endstop Log** | Shows how many times each endstop was hit unexpectedly during a move, and when (sends `'l'`). |
| **Menu** | Prints the device's own command menu to the raw log (sends `'m'`). |

## Live Status

Auto-refreshes every 1.5 seconds while connected (paused automatically
during a Sweep Test, since both use the serial connection). Hover any
field name for its tooltip. Laid out as two side-by-side columns to
keep the window compact.

| Field | Meaning |
|---|---|
| Firmware Version | The connected device's firmware build codename and timestamp — confirm which build is actually running, e.g. after a flash. |
| Git Commit | The git commit the running firmware was built from, with `-dirty` added if the build included uncommitted changes, or `unknown` if it wasn't built with `build_firmware.sh`. Log this with experiment data to record exactly which firmware ran. |
| Enabled | Whether the driver is energized. Disabled by `'d'`, a driver fault, a lost serial connection, or repeated unexpected endstop hits. |
| Position | Currently tracked position in steps. Not trustworthy until calibrated. |
| Max Range | The calibrated maximum position (the far endstop's location) from the last successful calibration this session. |
| Calibrated | Whether the device has been calibrated since it was last enabled. |
| Saved Max Pos | The max position from the last calibration saved to EEPROM — compare against the current one to spot mechanical drift (a loosening coupler, worn lead screw). |
| Retract Distance | How far back from the max endstop the First-Contact target sits. |
| First-Contact | The position Retract (and calibration) targets — max endstop minus retract distance. Unavailable until calibrated. |
| Speed | Currently active maximum speed, steps/s. |
| Acceleration | Currently active acceleration, steps/s². |
| Run Current | Currently active RMS run current, mA. |
| Hold Current | Currently active hold current, % of run current. |
| Microsteps | Currently active microstepping resolution. |
| Chopper Mode | SpreadCycle or StealthChop, currently active. |
| Fan Mode | Auto, Forced ON, or Forced OFF. |
| Fan State | Whether the cooling fan is currently running. |
| Min Endstop | Live switch read. "ok" when idle; "TRIGGERED" means the switch is closed — also happens if its wire comes loose (these switches fail safe). |
| Max Endstop | Same as Min Endstop, for the max switch. |
| Soft Limit Guard | The software layer (separate from the physical switches) that refuses any move outside the calibrated range. Only active once calibrated. |
| Total Run Time | Cumulative motor-enabled time across the device's whole life. Persists across power cycles. |
| Session Run Time | Motor-enabled time since this power-on. Resets to 0 every boot. |
| Total Distance | Cumulative lead-screw travel, in meters, across the device's whole life — a proxy for mechanical wear. |
| Total Min Hits | Cumulative physical actuations of the min endstop, across the device's whole life — a proxy for switch wear. |
| Total Max Hits | Same as Total Min Hits, for the max endstop. |
| Heat Sink Temp | Live driver heat-sink reading from an optional DS18B20 sensor, auto-detected at boot. Unavailable if no sensor is installed. |
| Device ID | The Teensy's factory-programmed 64-bit unique hardware ID — lets you tell physical devices apart independent of USB port names or firmware version. |
| Peak Heat Sink Temp | The highest heat-sink temperature ever recorded on this device, across its whole life. Persists across power cycles; reset only by Reset to Defaults. Shows "never recorded" on a device with no sensor installed. |
| Safe Limits | Not live device data — the safety-margined speed/acceleration recommendation from the last completed Sweep Test, per chopper mode. Stays here until a new sweep actually finishes; an aborted or empty run doesn't clear it. |

## Sweep Test

Automatically finds the maximum reliable speed and acceleration for a
matrix of run currents × chopper modes you specify.

**Inputs:**

- **Currents (mA, comma-separated)** — e.g. `600,800,1000`. The sweep
  runs for every current × selected chopper mode.
- **SpreadCycle / StealthChop** checkboxes — at least one must be
  checked.
- **Speed sweep (start/end/step)** — the speed range to test, in
  steps/s. A label next to the end-speed field shows the acceleration
  actually required to reach it given the calibrated travel — below
  that, a candidate speed can't be reached at all.
- **Fixed acceleration during speed sweep** — held constant while speed
  is being swept.
- **Accel sweep (start/end/step)** — the acceleration range to test, in
  steps/s².
- **Fixed speed during acceleration sweep** — held constant while
  acceleration is being swept.
- **Repeatability tolerance (steps)** — the max allowed position drift
  between a test move and a trusted baseline for a step to still count
  as passing.
- **Test move stops short of max (steps)** — how far short of the
  calibrated max endstop the far end of the test move stops (default
  4800, i.e. 3 mm). With a tube fitted, resistance is highest just before
  it closes, so lower this to test your real full-scale point — e.g. 2900
  to end near step 38000 on a unit that calibrates to about 40900. The
  near-min end always keeps its fixed 3 mm margin.

**Running it:** click **Run Sweep**. For each current × mode combo, the
sweep runs one baseline calibration, then increments speed (then
acceleration), making a round-trip test move and re-verifying position
against the baseline at each step — not just "did a safety disable
trip," but "did the carriage actually arrive where it should have." A
step keeps going until one fails or the available travel is exhausted.

While running, the progress line shows what's being tested right now,
and the instant each step finishes, its result (drift and pass/fail, or
the reason it failed) is appended to that same line *and* logged to the
Raw device log — so you can scroll back through every step afterward,
not just see the final summary. Click **Abort** to stop immediately,
mid-step.

**Results table** (one row per current × mode combo):

- **Speed Limit / Accel Limit** — the last value that *passed*, one step
  from where it actually broke.
- **Recommended Speed / Recommended Accel** — the limit above, with a
  safety margin applied (blank when the sweep simply reached its
  configured range without ever failing, since that isn't a real edge
  to apply a margin to).
- **Notes** — drift figures, "ran warm during testing," or why a combo
  was skipped (e.g. travel too short).

Click **Export CSV** (enabled once at least one result exists) to save
the table to a file.

**Important caveat:** speed and acceleration are swept independently,
each holding the other fixed — the two reported values have **not**
been tested together. Confirm with a real run at your chosen
combination before relying on it operationally.

The **verdict** below the table names the best combo per chopper mode,
ranked by: not having run warm during testing (beats any score
difference), then recommended speed × recommended acceleration, then
lower current on ties. This same recommendation also appears in Live
Status under **Safe Limits**.

## Raw device log

Shows every line the device sends that isn't part of a Live Status poll
(those are suppressed here to avoid flooding the log every 1.5
seconds) or a sweep step result. Useful for seeing exact command
responses, errors, and diagnostic output as they happen.
