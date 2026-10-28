# Psi reference runs

FICTIONAL simulated observers. Each JSON file holds one Psi run: the grids (`config`), the
response on every trial, the stimulus the method chose on every trial (`x`), and the
posterior means after every trial (`threshold`, `slope` = mean of log10 beta as in
Palamedes `PM.slope`, `lapse`). `python/tests/test_psi.py` replays the responses through
`rrst.psi.PsiStaircase` and requires the same stimuli and estimates.

| Files | Origin |
|---|---|
| `pypalamedes__*.json` | pypalamedes 1.11.13 (the Palamedes authors' Python port), written by `python/tools/make_psi_reference_pypalamedes.py` |
| `palamedes_matlab__*.json` | MATLAB Palamedes, written by `tests/reference/makePsiReference.m`, which replays the pypalamedes responses. **Not generated yet**: needs a machine with Palamedes (the stim laptop) |

The threshold grids start one step above 0 because the Weibull is undefined at
alpha = 0, x = 0 (0/0).
