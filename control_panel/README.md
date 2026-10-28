# RRST Device Control Panel

A cross-platform desktop app (Windows/Mac/Linux) for testing the RRST
device without using the serial CLI directly. Every CLI command has a
button or a text-field-plus-button, and a live status panel shows the
device's state, auto-refreshing every 1.5 seconds while connected.

## Sweep Test

The device has no position feedback, so the only way to tell "this
speed/acceleration was too aggressive" is indirectly: a stepper that
misses steps can still finish a move, or even still trigger an endstop,
just at the wrong place. The Sweep Test panel automates finding real
operating limits by incrementing speed (or acceleration) step by step
and re-calibrating twice at each step - a step only counts as passing
if both calibrations complete without error and agree on position
within the configured tolerance. It runs this across every combination
of the currents and chopper modes you enter, reports each combination's
limits in a table as they finish, and can export the results to CSV.

A step failing is the expected, sought-after result, not an error - the
device is stepped back to a known-safe value and recalibrated before
moving on. A real driver fault or a dead serial link, on the other
hand, abort the entire run immediately.

## Running from source

Requires Python 3.9+.

```
pip install -r requirements.txt
python app.py
```

## Building a standalone executable

PyInstaller does not cross-compile - run this on each OS you want an
executable for:

```
pip install -r requirements.txt pyinstaller
python build.py
```

The executable is written to `dist/`.

## Running the tests

```
pip install -r requirements.txt pytest
pytest
```
