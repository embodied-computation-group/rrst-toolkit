# RRST Toolkit 2.0

A general-purpose respiroception toolkit built around the Respiratory Resistance
Sensitivity Task (RRST): task code, a confirmed and logged device layer, firmware, and
the device Control Panel for the Teensy 4.0 + TMC2209 RRST devices. The first deployment
is a study in Zurich. The toolkit itself is study-agnostic; study-specific choices
(stimulus grid, priors, timing) belong in each study's configuration and
preregistration.

It combines two sources:

- the MATLAB/Psychtoolbox task from
  [RespiroceptionMethodsPaper](https://github.com/embodied-computation-group/RespiroceptionMethodsPaper)
  (Nikolova et al., 2022, *Biological Psychology* 170:108325; GPL-3.0);
- the Teensy 4.0 + TMC2209 firmware, Control Panel app and device helpers by Martin
  Snejbjerg Jensen (CFIN).

**Status:** work in progress.
- **Device layer** (`device/+rrst`): written. It is tested against a simulated device,
  not yet against hardware.
- **Task, firmware and Control Panel:** imported unmodified from their sources.
- **Next:** the 2.0 task built on the device layer (from RRS_3-0), and per-device
  calibration records (see `TASKS.md`).

## Question

Provide an RRST that runs on any calibrated Teensy 4.0 + TMC2209 device and delivers,
confirms and logs every requested obstruction level, with stimulus anchors measured on
each physical device. Studies configure it; they don't fork it.

## Environment

- MATLAB R2021a or later (`serialport` and `matlab.unittest` are required).
- The task will also need Psychtoolbox 3 and Palamedes. Neither is needed for the
  device-layer tests.

## Run the tests

From the repository root:

```
matlab -batch "addpath('device'); results = runtests('tests'); disp(table(results)); assertSuccess(results)"
```

The tests use `rrst.MockPort`, which simulates the firmware's serial replies. No
hardware is required.

## Layout

| Path | Contents |
|---|---|
| `device/+rrst/` | Device layer: obstruction-to-step mapping, firmware reply parsers, `Device` class, `MockPort` simulator, `openPort` for real hardware |
| `task/` | `RRS_3-0` (base for the 2.0 task, unmodified so far), shared `helpers/`, and the old 3-0 and 4-0 device helpers kept for reference |
| `firmware/` | Teensy 4.0 + TMC2209 firmware source |
| `control_panel/` | Martin's Python Control Panel app, with the bundled `.hex` and flasher |
| `hardware/` | Eagle schematic and the TMC2209 modification checklist |
| `bench/` | Hardware bench scripts (`readStatus.m` sends only `s`) |
| `tests/` | `matlab.unittest` tests; `tests/fixtures/` holds firmware transcripts |
| `docs/` | Methods-paper notes, integration review (2026-10-28), Control Panel manual, firmware session-protocol notes |
| `data/` | `raw/` and `processed/` are for study data (never in Git, denied to the agent); `generated/` is for fictional data |

## Provenance and credits

- **Task:** Niia Nikolova and the Embodied Computation Group,
  RespiroceptionMethodsPaper at `a0330917`. Cite Nikolova et al. (2022).
- **Firmware, Control Panel and device design:** Martin Snejbjerg Jensen, CFIN, Aarhus
  University, from Msnejbjerg/RRST at `c298eed`.
- **Integration and device layer (`device/+rrst`):** this repository.

The files were imported verbatim at those commits. Later changes are separate commits.
`PROVENANCE.md` lists every imported path, the files not imported, the third-party
licences and the firmware SHA-256 sums.

## Licence

GPL-3.0 (`LICENSE`). Bundled third-party components keep their own licences (MIT for
TeensyStep4 and SerialMenuCmd; GPL-3.0 for teensy_loader_cli). See `PROVENANCE.md`.
