"""Write Psi reference runs from pypalamedes into tests/fixtures/psi/ (FICTIONAL observers).

pypalamedes cannot share the project environment (it needs numpy >= 2.5.1, which needs
Python >= 3.12; PsychoPy needs 3.11 on Windows), so run this in a separate one:
    uv venv -p 3.12 .venv-pal && uv pip install -p .venv-pal pypalamedes==1.11.13
    .venv-pal/Scripts/python tools/make_psi_reference_pypalamedes.py
tests/reference/makePsiReference.m writes the same format from MATLAB Palamedes.

Each run: a simulated Weibull observer answers; the responses, the stimulus chosen on
every trial and the posterior means after every trial are saved. Replaying the responses
through another Psi implementation must reproduce the stimuli and the estimates.
"""
import json
import sys
from importlib.metadata import version
from pathlib import Path

import numpy as np
import pypalamedes.ampm as ampm

OUT = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "psi"

PILOT = dict(stimRange=np.linspace(0, 100, 41).tolist(),
             priorAlphaRange=np.linspace(0, 100, 72)[1:].tolist(),   # alpha = 0 is undefined for the Weibull at x = 0
             priorBetaRange=np.linspace(0, np.log10(16), 72).tolist(),  # log10 beta
             priorGammaRange=[0.5], priorLambdaRange=[0.02], numTrials=100)
LAPSE = dict(stimRange=np.linspace(0, 100, 21).tolist(),
             priorAlphaRange=np.linspace(5, 100, 20).tolist(),
             priorBetaRange=np.linspace(0, np.log10(16), 12).tolist(),
             priorGammaRange=[0.5], priorLambdaRange=[0.0, 0.02, 0.04, 0.06], numTrials=60)
RUNS = [("pilot_seed1", PILOT, 1, 62.0, 3.0), ("pilot_seed2", PILOT, 2, 85.0, 6.0),
        ("pilot_seed3", PILOT, 3, 40.0, 1.5), ("lapse_grid_seed4", LAPSE, 4, 70.0, 4.0)]


def run(cfg, seed, a_true, b_true):
    pm = ampm.setup_pm('prior_alpha_range', np.array(cfg["priorAlphaRange"]),
                       'prior_log_beta_range', np.array(cfg["priorBetaRange"]),
                       'prior_gamma_range', np.array(cfg["priorGammaRange"]),
                       'prior_lambda_range', np.array(cfg["priorLambdaRange"]),
                       'num_trials', cfg["numTrials"], 'pf', 'weibull',
                       'stim_range', np.array(cfg["stimRange"]))
    u = np.random.default_rng(seed).random(cfg["numTrials"])
    x, r = [], []
    for k in range(cfg["numTrials"]):
        xk = float(pm['x_current'].item())
        p = 0.5 + (1 - 0.5 - 0.02) * (1 - np.exp(-(xk / a_true) ** b_true))
        x.append(xk); r.append(int(u[k] < p))
        pm = ampm.update_pm(pm, r[-1])
    s = pm['summ_stats']
    return dict(x=x, response=r, threshold=s['a'].tolist(), slope=s['b'].tolist(),
                lapse=s['l'].tolist(), stop=bool(pm['stop']))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, cfg, seed, a, b in RUNS:
        res = run(cfg, seed, a, b)
        doc = dict(origin=f"pypalamedes {version('pypalamedes')}, "
                          f"Python {sys.version.split()[0]}, python/tools/make_psi_reference_pypalamedes.py",
                   note="FICTIONAL simulated observer. slope = posterior mean of log10(beta), as Palamedes PM.slope.",
                   observer=dict(alpha=a, beta=b, gamma=0.5, lapse=0.02, seed=seed),
                   pf="weibull", config=cfg, **res)
        f = OUT / f"pypalamedes__{name}.json"
        f.write_text(json.dumps(doc, indent=1))
        print(f.name, "first x", res["x"][:5], "final threshold", round(res["threshold"][-1], 4))
