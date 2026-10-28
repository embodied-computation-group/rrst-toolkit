# Bench check and calibration

Do this for **every 2.0 unit** before its first study, and again after any mechanical
work, firmware update or settings change. Record the results with the date and your
initials. They become that device's calibration record.

!!! todo "TODO(toolkit): device record format"
    The toolkit will store one record per device, keyed by the firmware's Device ID:
    firmware version, `MaxPosition` and its tolerance, the measured stimulus anchors, the
    saved settings and the checks below. The format is being designed in the
    repository's `TASKS.md`.

## 1. Read-only status

From MATLAB, with the toolkit on the path:

```matlab
st = readStatus("COM5")   % bench/readStatus.m: sends only 's'; nothing moves
```

Or use the Control Panel's **Live Status**. Record:

- `Software Version` and `Device ID`
- current, speed, acceleration, microsteps and chopper mode
- the retract distance

## 2. Calibrate and repeat

Run `c` several times (the Control Panel or the toolkit's `rrst.Device`) and record each
reported `Max Position`. Values should agree within a few steps.

!!! todo "TODO(bench): repeatability tolerance"
    Set the acceptable spread of `MaxPosition` across repeated calibrations, from the
    first bench measurements.

## 3. Measure the stimulus anchors

The task's obstruction scale is anchored to two **physical** positions on each device:

- **0 %: first contact.** The wedge just touches the tube; a sheet of paper between wedge
  and tube is just held in place.
- **100 %: full scale.** It is barely possible to inhale through the circuit.

Step the wedge with `a` + position and find both positions. Record each as **steps back
from `MaxPosition`**. The firmware's computed "first-contact position"
(`MaxPosition` − 15 mm) is only an estimate. Keep full scale short of the max endstop, so
the endstop isn't struck on high-load trials.

!!! todo "TODO(bench): anchor procedure"
    Define who judges "barely possible to inhale" (and how many people), the step size
    for searching, and whether to add a constant-flow resistance curve (paper §8:
    0.95 L/s, pressure and flow at 17 obstruction steps).

## 4. Move timing

Time moves across the range (the toolkit logs `elapsed` for every move). At the default
16000 steps/s and 10000 steps/s², a 24000-step move takes about 3.1 s. The pause between
breaths in the task must be longer than the slowest move.

## 5. Masking check

With the participant's headphones and masking noise on, check that a naive listener
can't tell the two motor moves apart (different distances and directions) at the
participant's seat.

## 6. MATLAB connection check

Confirm that calibration succeeds when the port is opened with `rrst.openPort`, which
asserts DTR. The firmware disables the driver if the host doesn't assert DTR.
