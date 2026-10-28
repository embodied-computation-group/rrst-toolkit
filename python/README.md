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
