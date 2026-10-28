# RRST Zurich

Integration of the Respiratory Resistance Sensitivity Task (RRST) for the Zurich study.
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
- **Next:** the Zurich task (RRS_4-0) built on the device layer, and per-device
  calibration records (see `TASKS.md`).

## Question

Can the RRST run on the new Teensy 4.0 + TMC2209 devices so that each requested
obstruction level is delivered, confirmed and logged, with stimulus anchors measured on
each physical device?

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
| `task/` | `RRS_3-0` (base for the Zurich task, unmodified so far), shared `helpers/`, and the old 3-0 and 4-0 device helpers kept for reference |
| `firmware/` | Teensy 4.0 + TMC2209 firmware source |
| `control_panel/` | Martin's Python Control Panel app, with the bundled `.hex` and flasher |
| `hardware/` | Eagle schematic and the TMC2209 modification checklist |
| `bench/` | Hardware bench scripts (`readStatus.m` sends only `s`) |
| `tests/` | `matlab.unittest` tests; `tests/fixtures/` holds firmware transcripts |
| `docs/` | Protocol notes and the decisions log |
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
