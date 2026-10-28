# RRST Zurich

Integration of the Respiratory Resistance Sensitivity Task (RRST) for the Zurich study.
It combines two sources:

- the MATLAB/Psychtoolbox task from
  [RespiroceptionMethodsPaper](https://github.com/embodied-computation-group/RespiroceptionMethodsPaper)
  (Nikolova et al., 2022, *Biological Psychology* 170:108325; GPL-3.0);
- the Teensy 4.0 + TMC2209 firmware, Control Panel app and device helpers by Martin
  Snejbjerg Jensen (CFIN).

**Status:** work in progress. Only the device layer (`device/+rrst`) exists so far. It is
tested against a simulated device, not yet against hardware. The task itself, the
firmware snapshot and the per-device calibration records come next (see `TASKS.md`).

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
| `tests/` | `matlab.unittest` tests; `tests/fixtures/` holds firmware transcripts |
| `docs/` | Protocol notes and the decisions log |
| `data/` | `raw/` and `processed/` are for study data (never in Git, denied to the agent); `generated/` is for fictional data |

## Provenance

| Source | Repository | Commit |
|---|---|---|
| Task, helpers | embodied-computation-group/RespiroceptionMethodsPaper | `a0330917e57cb5e6a8706bd86eac751eb6863698` |
| Firmware, Control Panel, 4-0 helpers | Msnejbjerg/RRST (private) | `c298eedcc77eb046d0b9fae253f2a3d6346d8bb0` |

Nothing has been imported from either repository yet. The firmware reply strings used by
the parsers and the simulator were transcribed from
`RRST_Teensy_4_version_TMC2209.ino` at the commit above.

**Licence:** {{LICENCE}}. The original task is GPL-3.0. Martin's repository has no
licence file yet, so his code cannot be imported until he grants one.
