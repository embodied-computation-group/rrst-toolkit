# RRST Toolkit 2.0: Python port

Python port of the RRST 2.0 task (`task/RRST_2-0`) and its device layer (`device/+rrst`),
with PsychoPy for the display and QUEST+ (`questplus`) for the Psi staircase.
Work in progress on the `python-port` branch.

## Setup

Needs [uv](https://docs.astral.sh/uv/). Python 3.11 is pinned: PsychoPy 2026.2 needs
Python < 3.13, and on Windows its dependency `pywinhook` has wheels only up to 3.11.

```
cd python
uv sync                 # device layer and staircase (tests need nothing else)
uv sync --extra task    # adds PsychoPy, to run the task
uv run pytest
```

The tests reuse the firmware transcripts in `../tests/fixtures/` and the device records in
`../devices/`, so the MATLAB and Python layers are checked against the same replies.

## Running the task

```
cd python
uv run --extra task python -m rrst.task.run --mock            # simulated device: try this first
uv run --extra task python -m rrst.task.run --list-audio      # names for noise.speaker
uv run --extra task python -m rrst.task.run --port COM7       # real device ("auto": the only Teensy)
```

Settings are in `configs/pilot.toml` (copy it for a study; `--config path`). Unknown keys
are an error. It asks for the subject ID (9999 = test) and language (`e`/`d`), shows the
device and its settings, and waits for Enter before calibrating. Esc parks the wedge and
saves what was collected. Output, in `../data/raw/` (never committed):

- `RRST_<id>_psi_<date>_<time>.csv`: one row per attempt, MATLAB column names
  (`trialN`, `Stim`, `Resp`, `RespLR`, `RT`, `ConfResp`, ...) plus `attempt`, `valid`,
  `ITI`, `threshold`, `slope`;
- the `.json` next to it: configuration, Psi state, ratings, and the device summary with
  every serial line sent and received.

`MOCK_`, `Aborted_` and `Error_` prefixes mark mock, aborted and failed runs.

Differences from the MATLAB task (`rrst/task/session.py` lists them): Psi on questplus
with the threshold grid starting above 0; an invalid response is repeated even on the
last trial; every attempt is a row; Esc works on every screen; masking is the rain loop
(`../task/helpers/audio/`). The tutorial, metacognition trials and the quest procedure
are not ported.
