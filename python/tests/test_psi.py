"""PsiStaircase (QUEST+ with a Weibull and minimum expected entropy, i.e. the Psi method).

Hand-worked known answer (Weibull, beta = 1, gamma = 0.5, lambda = 0, one stimulus x = 10,
two thresholds with equal prior):
  P(correct | alpha = 10) = 0.5 + 0.5 * (1 - exp(-1))   = 0.816060
  P(correct | alpha = 20) = 0.5 + 0.5 * (1 - exp(-0.5)) = 0.696735
  after a correct response: p(10) = 0.816060 / 1.512795 = 0.539439
    -> posterior mean threshold = 10 * 0.539439 + 20 * 0.460561 = 14.6056
  after an incorrect response: p(10) = 0.183940 / 0.487205 = 0.377541
    -> posterior mean threshold = 10 * 0.377541 + 20 * 0.622459 = 16.2246
Reference runs: tests/fixtures/psi/*.json (pypalamedes, and MATLAB Palamedes once
tests/reference/makePsiReference.m has been run with Palamedes installed).
"""
import json
import math

import numpy as np
import pytest

from conftest import FIXTURES
from rrst import errors
from rrst.psi import PsiStaircase

PSI_REFERENCES = sorted((FIXTURES / "psi").glob("*.json"))


def tiny(**kw):
    args = dict(stim_range=[10], alpha_range=[10, 20], log10_beta_range=[0],
                gamma_range=[0.5], lambda_range=[0.0], num_trials=5)
    args.update(kw)
    return PsiStaircase(**args)


def test_posterior_after_correct_response_hand_worked():
    psi = tiny()
    psi.update(1)
    assert psi.threshold[-1] == pytest.approx(14.6056, abs=1e-4)


def test_posterior_after_incorrect_response_hand_worked():
    psi = tiny()
    psi.update(0)
    assert psi.threshold[-1] == pytest.approx(16.2246, abs=1e-4)


def test_slope_is_reported_as_log10_beta():
    psi = tiny(log10_beta_range=[0.5])
    psi.update(1)
    assert psi.slope[-1] == pytest.approx(0.5)


def test_uninformative_stimulus_is_never_chosen():
    # At x = 0 every hypothesis predicts chance (gamma), so it carries no information.
    psi = PsiStaircase(stim_range=[0, 50], alpha_range=np.linspace(10, 90, 9),
                       log10_beta_range=[0.3], num_trials=4)
    for r in (1, 0, 1, 1):
        assert psi.x_current == 50
        psi.update(r)


def test_records_presented_stimuli_responses_and_stops():
    psi = tiny(num_trials=3)
    for r in (1, 0, 1):
        assert not psi.stop
        psi.update(r)
    assert psi.stop
    assert psi.x == [10, 10, 10]
    assert psi.response == [1, 0, 1]
    assert len(psi.threshold) == len(psi.slope) == len(psi.lapse) == 3


def test_update_after_stop_is_an_error():
    psi = tiny(num_trials=1)
    psi.update(1)
    with pytest.raises(RuntimeError):
        psi.update(1)


@pytest.mark.parametrize("response", [2, -1, 0.5, None, True])
def test_response_must_be_0_or_1(response):
    with pytest.raises(ValueError):
        tiny().update(response)


@pytest.mark.parametrize("bad", [
    dict(alpha_range=[0, 10, 20]),            # Weibull: alpha = 0 is undefined at x = 0
    dict(alpha_range=[-5, 10]),
    dict(stim_range=[-1, 10]),                # Weibull: negative stimulus undefined
    dict(stim_range=[10, math.nan]),
    dict(stim_range=[20, 10]),                # must increase
    dict(stim_range=[10, 10]),
    dict(log10_beta_range=[math.inf]),
    dict(gamma_range=[1.0]),
    dict(lambda_range=[-0.1]),
    dict(gamma_range=[0.5], lambda_range=[0.5]),   # gamma + lambda must stay below 1
    dict(stim_range=[]),
    dict(num_trials=0),
    dict(pf="logistic"),
])
def test_grids_the_weibull_cannot_evaluate_are_rejected(bad):
    with pytest.raises(errors.BadGrid):
        tiny(**bad)


def test_inverse_gives_the_stimulus_for_a_performance_level():
    # 2IFC Weibull: P = g + (1 - g - l)(1 - exp(-(x/a)^b)). With the posterior
    # concentrated on alpha = 20, beta = 1, g = .5, l = 0: P(x) = 0.75 at
    # x = 20 * ln 2 = 13.8629.
    psi = tiny(stim_range=[5, 10], alpha_range=[20], log10_beta_range=[0])
    assert psi.inverse(0.75) == pytest.approx(20 * math.log(2), abs=1e-6)


def test_state_is_json_serialisable():
    psi = tiny()
    psi.update(1)
    json.dumps(psi.state())


@pytest.mark.parametrize("path", PSI_REFERENCES, ids=lambda p: p.stem)
def test_reproduces_reference_run(path):
    ref = json.loads(path.read_text())
    c = ref["config"]
    psi = PsiStaircase(stim_range=c["stimRange"], alpha_range=c["priorAlphaRange"],
                       log10_beta_range=c["priorBetaRange"], gamma_range=c["priorGammaRange"],
                       lambda_range=c["priorLambdaRange"], num_trials=c["numTrials"])
    for k, r in enumerate(ref["response"]):
        assert psi.x_current == pytest.approx(ref["x"][k], abs=1e-9), f"stimulus differs at trial {k + 1}"
        psi.update(r)
    assert psi.threshold == pytest.approx(ref["threshold"], abs=1e-6)
    assert psi.slope == pytest.approx(ref["slope"], abs=1e-6)
    assert psi.lapse == pytest.approx(ref["lapse"], abs=1e-6)
    assert psi.stop == ref["stop"]


def test_reference_runs_exist():
    assert len(PSI_REFERENCES) >= 4
