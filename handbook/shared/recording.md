# Recording physiology and airflow (LSL)

The task, the physiology and the airflow are recorded together over
[Lab Streaming Layer](https://labstreaminglayer.org) (LSL). Each source publishes a
stream on the PC, and LabRecorder writes all of them into **one `.xdf` file** on a
shared clock. Trials are cut out afterwards using the task's markers. No OpenSignals
and no photodiode triggers are needed.

| Stream | Type | From | Content |
|---|---|---|---|
| `RRST` | Markers | the RRST 2.0 task (MATLAB) | one text marker per task event, stamped at the event's own time |
| `PLUX` | Biosignals | `plux_lsl.py` (biosignalsplux hub, Bluetooth) | ECG, respiration belt: raw ADC counts (int32), 1000 Hz by default, column 0 = `nSeq`. Channels are named by sensor type and hub port, e.g. `RESP1`, `ECG2` |
| `Flow` | Airflow | `flow_lsl.py` ([airflow sensor](airflow-sensor.md)) | flow (slm), temperature (°C), 1000 Hz, column 0 = `nSeq` |
| `SessionMarkers` | Markers | the Physio Recorder app | `<task>_start` / `<task>_end`, or `<task>_end_early` (stopped early, connection lost, or the app closed mid-recording): the recording window |

`nSeq` is the device's own sample counter, so a lost sample shows up as a gap.

## Software on the stim laptop

| | Where | Notes |
|---|---|---|
| Physio Recorder (`plux-lsl`) | `Desktop\cannabodies\plux-lsl` | Python 3.13 environment in `.venv` (PLUX's API has no Python 3.11 build). Holds `physio_app.py`, the stream programs, the quality checks and the analysis scripts. Its `README.md` has the RA checklists and the setup for a new PC. Private repository: [embodied-computation-group/plux-lsl](https://github.com/embodied-computation-group/plux-lsl). Desktop shortcut: **Physio Recorder** |
| LabRecorder 1.18 | `plux-lsl\LabRecorder` | started by the app (`LabRecorderCLI.exe`) |
| liblsl-Matlab v1.14.0 | `C:\toolbox\liblsl-Matlab` | **with `bin\lsl.dll` replaced by liblsl 1.18** (see below) |

!!! warning "liblsl-Matlab needs a newer lsl.dll"
    liblsl-Matlab's latest release (v1.14.0, 2020) ships liblsl 1.14. LabRecorder 1.18
    and pylsl use liblsl 1.18, and with the 1.14 DLL they repeatedly lost the task's
    marker stream ("Stream transmission broke off ... requested integer size exceeds
    type size"). Rename `bin\lsl.dll` to `lsl_1.14.dll` and copy in a liblsl 1.18
    `lsl.dll` (for example pylsl's `pylsl\lib\lsl.dll`). Tested 2026-10-28: 481 of 481
    markers over 4 minutes arrived in LabRecorder and pylsl.

## PLUX hub

- **Hub:** biosignalsplux, MAC 00:07:80:4B:3F:25, firmware 3.7. It is paired in the
  Windows Bluetooth settings as "biosignalsplux". Windows also gives it a serial port
  (COM8), which isn't used directly. It uses the laptop's built-in Bluetooth.
- **USB dongle:** PLUX's Bluetooth dongle isn't needed. Windows runs one Bluetooth
  radio at a time, so the dongle shows as "Generic Bluetooth Radio" in an error state
  while the built-in radio is active. It's a fallback for a room with dropouts:
  disable the built-in radio in Device Manager (needs admin), then pair again.
- **Ports:** four analog ports and one digital port (marked with an arrow; port 9 in
  the API, for SpO₂/fNIRS, which deliver two channels, RED and IR). Pilot layout:
  respiration belt on port 1, ECG on port 2. Sensors with an ID chip are detected
  automatically. Force others with `plux_lsl.py --ports 1,2`. The rate can be raised
  with `--rate` (up to 3000 Hz with four or five analog channels).
- **Software:** PLUX's native Python API (`plux.pyd` and two FTDI DLLs from
  pluxbiosignals/python-samples, `PLUX-API-Python3/Win64_313`, Apache-2.0), kept in
  `plux-lsl\vendor\plux` with its source commit. OpenSignals isn't needed. Only one
  program can use the hub at a time, so close OpenSignals before the app.
- **Units:** the stream holds raw ADC counts. The biosignalsplux transfer functions
  (VCC 3 V, 16 bit) are ECG mV = (ADC/2¹⁶ − 0.5) × 3 / 1019 × 1000, respiration
  (PZT) % = (ADC/2¹⁶ − 0.5) × 100, and EDA µS = (ADC/2¹⁶) × 3 / 0.12. They are
  implemented in `plux-lsl\quality.py` (`to_units`).

!!! warning "PLUX timing has an unmeasured constant delay"
    PLUX samples are timestamped when they arrive over Bluetooth, in chunks of 10
    back-dated at the nominal rate. Between PLUX and the task markers or Flow there is
    therefore a constant Bluetooth delay, probably tens of milliseconds and **not yet
    measured**. Dejittering in pyxdf removes the jitter but not this offset. It doesn't
    matter for breathing or heart-rate variability. It does matter for analyses locked
    to the ECG (e.g. cardiac phase) until a hardware test has measured it.
    `TODO(plux-latency)`.

## Task markers

With `cfg.markers.lsl = true` (the pilot default), `runRRST` opens the `RRST` stream
at launch, **before the first prompt**, and sends `RRST_ready`. A recorder only picks
up streams that exist when recording starts. The Physio Recorder's RRST preset waits
for the stream and starts recording by itself when it appears.

With `cfg.markers.requireRecorder = true` (the default), RRST also waits before
calibration until a recorder is receiving its markers. If none is, it prints
**NOTHING IS RECORDING** and continues by itself once recording starts, so a session
can't run unrecorded by accident. A recorder counts once it has connected to the
stream; LabRecorder does so when recording starts. Set it to `false` for a quick mock
run without a recorder.

| Marker | Event |
|---|---|
| `tutorial_start`, `tutorial_end` | tutorial |
| `session_start` | participant pressed space to begin |
| `trial_<n>_interval<k>_ready` | wedge move confirmed; ISI countdown starts (k = 1, 2) |
| `trial_<n>_interval<k>_onset_load` / `_onset_null` | inhale cue: the expanding ring appears |
| `trial_<n>_level_<x>` | load level of the trial (at the load interval's `_ready`) |
| `trial_<n>_response` / `trial_<n>_noresponse` | answer, or none in time (the trial is repeated with the same n) |
| `trial_<n>_correct` / `trial_<n>_wrong` | whether the answer named the load breath |
| `trial_<n>_confidence` | confidence rating confirmed |
| `trial_<n>_iti` | ITI starts, wedge goes to rest |
| `break_start`, `break_end` | break |
| `session_end_complete` / `_aborted` / `_error` | end of the run |

Each trial sends about 9 markers, 2 of them onsets. Markers carry the event's own
time: the Psychtoolbox flip or `GetSecs` time, moved onto the LSL clock. Some are sent
a moment after the event (the onset markers after the breathing ring finishes), so
**use the timestamps, not the order of arrival**. The level presented on each trial is
in the `trial_<n>_level_<x>` marker and in the task's `.mat` / `.csv` (`Stim`,
`SignalInterval`, by trial number).

## Running a session with recording

The RA checklist is in `plux-lsl\README.md` ("RA checklist: RRST (with flow sensor)").

!!! success "Verified 2026-10-28"
    A 20-trial RRST run on the stim laptop with the respiration belt (PLUX), the flow
    sensor and the Physio Recorder's RRST preset. Recording started automatically when
    RRST launched. Summary PASS: 149 markers (42 onsets), no dropped samples. ECG was
    not connected in that run.

In short:

1. Plug in the RRST device, the SensorBridge and the PLUX hub. Sensors on the
   participant.
2. Open the Physio Recorder, fill in Participant and Session, pick **RRST**, check
   the **Devices** boxes (below), click
   **Check signals**. ECG, respiration and flow should go green; ask for a test breath
   through the mouthpiece. The status line shows the hub's battery; below 20 % it
   turns red.
3. Start RRST in MATLAB:
   `cfg = pilotConfig(); cfg.device.port = "COM7"; runRRST(cfg)`.
   The Physio Recorder starts recording by itself (a bell and the banner "Recording
   started AUTOMATICALLY"). If it doesn't, for example because the flow sensor isn't
   connected, RRST says **NOTHING IS RECORDING** before calibration and waits: click
   **Start recording** in the app.
4. Run the task.
5. When the task ends, click **Stop recording** and check the **Last recording** panel
   (PASS / CHECK).

### Without PLUX or without the flow sensor

Each device is optional. In the Physio Recorder, the **Devices** row has a box for
"PLUX hub (ECG, breathing belt)" and one for "Flow sensor (RRST)". The choice is
remembered on that PC (`plux-lsl\devices.json`) and can only be changed while
disconnected. A device that is unticked is not started, not waited for and not
expected in the summary. RRST records with both devices, either one, or markers only.
The timed resting recordings need the hub.

Without any recorder, run RRST with `cfg.markers.requireRecorder = false` (markers
are still sent) or `cfg.markers.lsl = false` (no LSL at all).

## Analysis

From the `plux-lsl` folder:

```
.venv\Scripts\python.exe check_xdf.py <file>.xdf
.venv\Scripts\python.exe epoch.py <file>.xdf --stream Flow --events "interval\d_onset_" --pre 1 --post 3 --groups load null
```

After **Stop**, the Physio Recorder also makes the standard figures (`rrst_figures.py`)
in a `<recording>_figures` folder next to the file; **Open figures** shows them.
They are a session overview, every breath aligned on its inhale cue (load vs null),
the staircase with each trial's null and load peak flow and volume, and a gallery of
each trial's two breaths. For a wedge-level bench recording it makes the bench figure.
Without the flow sensor, only the belt figures are made.

`check_xdf.py` gives the PASS/CHECK summary. For RRST it also checks the markers:
there must be two onsets per trial (response or no response) and an end marker.
`epoch.py` cuts a window around every breath onset and averages load and null
intervals separately. Where a trial was repeated after no response, it keeps the last
occurrence of each marker. The same works for the `PLUX` stream; its `.npz` output
holds values converted to physical units, not raw counts. `segments.py` cuts
variable-length segments between a start and an end marker (used for the wedge-level
bench test). Files load in Python with
[pyxdf](https://github.com/xdf-modules/pyxdf) and in MATLAB with
[load_xdf](https://github.com/xdf-modules/xdf-Matlab).
