"""The Psi method (Kontsevich & Tyler, 1999) on QUEST+ (questplus).

QUEST+ with a Weibull psychometric function on a linear stimulus axis and
minimum-expected-entropy stimulus selection is the Psi method: the same likelihood
(g + (1 - g - l)(1 - exp(-(x/a)^b))), the same grid posterior and the same choice rule as
Palamedes PAL_AMPM. Estimates are reported under the Palamedes names, after every trial:
threshold (mean of alpha), slope (mean of log10 beta, as PM.slope), guess, lapse and
their posterior standard deviations.

    psi = PsiStaircase(stim_range=np.linspace(0, 100, 41),
                       alpha_range=np.linspace(0, 100, 72)[1:],
                       log10_beta_range=np.linspace(0, np.log10(16), 72),
                       gamma_range=[0.5], lambda_range=[0.02], num_trials=100)
    while not psi.stop:
        psi.update(correct)          # for the stimulus psi.x_current
"""
import math

import numpy as np
from questplus import QuestPlus

from . import errors


def _vector(name, values):
    v = np.atleast_1d(np.asarray(values, dtype=float))
    if v.ndim != 1 or v.size == 0 or not np.all(np.isfinite(v)):
        raise errors.BadGrid(f"{name} must be a non-empty vector of finite numbers; got {values!r}.")
    return v


class PsiStaircase:
    def __init__(self, stim_range, alpha_range, log10_beta_range, gamma_range=(0.5,),
                 lambda_range=(0.02,), num_trials=50, pf="weibull"):
        if pf != "weibull":
            raise errors.BadGrid(f'Only the Weibull is implemented (got pf="{pf}").')
        stim = _vector("stim_range", stim_range)
        alpha = _vector("alpha_range", alpha_range)
        log_beta = _vector("log10_beta_range", log10_beta_range)
        gamma = _vector("gamma_range", gamma_range)
        lam = _vector("lambda_range", lambda_range)
        if np.any(np.diff(stim) <= 0):
            raise errors.BadGrid("stim_range must be strictly increasing.")
        if np.any(stim < 0):
            raise errors.BadGrid("The Weibull is undefined for negative stimulus values.")
        if np.any(alpha <= 0):
            raise errors.BadGrid(
                "alpha_range must be > 0: the Weibull is undefined at alpha = 0 (0/0 at x = 0). "
                "Start the threshold grid above 0.")
        if np.any((gamma < 0) | (gamma >= 1)) or np.any((lam < 0) | (lam >= 1)) \
                or gamma.max() + lam.max() >= 1:
            raise errors.BadGrid("Need 0 <= gamma, 0 <= lambda and gamma + lambda < 1.")
        if not (isinstance(num_trials, (int, np.integer)) and num_trials > 0):
            raise errors.BadGrid(f"num_trials must be a positive integer; got {num_trials!r}.")

        self.stim_range = stim
        self.alpha_range = alpha
        self.log10_beta_range = log_beta
        self.gamma_range = gamma
        self.lambda_range = lam
        self.num_trials = int(num_trials)
        self.x, self.response = [], []
        self.threshold, self.slope, self.guess, self.lapse = [], [], [], []
        self.se_threshold, self.se_slope, self.se_guess, self.se_lapse = [], [], [], []
        self._qp = QuestPlus(
            stim_domain=dict(intensity=stim),
            param_domain=dict(threshold=alpha, slope=10 ** log_beta,
                              lower_asymptote=gamma, lapse_rate=lam),
            outcome_domain=dict(response=[1, 0]),
            func="weibull", stim_scale="linear", stim_selection_method="min_entropy")
        self.x_current = float(self._qp.next_stim["intensity"])

    @property
    def stop(self):
        return len(self.response) >= self.num_trials

    def update(self, response):
        """Record the response (1 correct, 0 incorrect) to x_current and choose the next stimulus."""
        if isinstance(response, bool) or response not in (0, 1):
            raise ValueError(f"response must be 0 or 1; got {response!r}")
        if self.stop:
            raise RuntimeError(f"The staircase has finished its {self.num_trials} trials.")
        self._qp.update(stim=dict(intensity=self.x_current), outcome=dict(response=int(response)))
        self.x.append(self.x_current)
        self.response.append(int(response))
        for name, values in (("threshold", self.alpha_range), ("slope", self.log10_beta_range),
                             ("guess", self.gamma_range), ("lapse", self.lambda_range)):
            mean, sd = self._marginal_moments(name, values)
            getattr(self, name).append(mean)
            getattr(self, f"se_{name}").append(sd)
        self.x_current = float(self._qp.next_stim["intensity"])

    def _marginal_moments(self, name, values):
        dim = {"threshold": "threshold", "slope": "slope", "guess": "lower_asymptote",
               "lapse": "lapse_rate"}[name]
        post = self._qp.posterior
        p = post.sum(dim=[d for d in post.dims if d != dim]).values
        p = p / p.sum()
        mean = float(np.sum(p * values))
        return mean, float(math.sqrt(np.sum(p * (values - mean) ** 2)))

    def estimates(self):
        """Current posterior means: threshold, slope (log10 beta), guess, lapse."""
        return {k: self._marginal_moments(k, v)[0] for k, v in (
            ("threshold", self.alpha_range), ("slope", self.log10_beta_range),
            ("guess", self.gamma_range), ("lapse", self.lambda_range))}

    def inverse(self, p_correct):
        """Stimulus at which the Weibull with the current posterior means gives
        P(correct) = p_correct, using the guess rate (2IFC: 0.5), not 0."""
        e = self.estimates()
        a, b, g, l = e["threshold"], 10 ** e["slope"], e["guess"], e["lapse"]
        c = (p_correct - g) / (1 - g - l)
        if not 0 < c < 1:
            raise ValueError(f"P(correct) = {p_correct} is outside the function's range ({g}, {1 - l}).")
        return a * (-math.log(1 - c)) ** (1 / b)

    def state(self):
        """Settings and per-trial history, JSON-serialisable, for saving with the data."""
        return {"method": "psi (questplus QUEST+, weibull, linear, min_entropy)",
                "stimRange": self.stim_range.tolist(), "priorAlphaRange": self.alpha_range.tolist(),
                "priorBetaRange": self.log10_beta_range.tolist(),
                "priorGammaRange": self.gamma_range.tolist(),
                "priorLambdaRange": self.lambda_range.tolist(), "numTrials": self.num_trials,
                "x": self.x, "response": self.response, "xNext": self.x_current, "stop": self.stop,
                "threshold": self.threshold, "slope": self.slope, "guess": self.guess,
                "lapse": self.lapse, "seThreshold": self.se_threshold, "seSlope": self.se_slope,
                "seGuess": self.se_guess, "seLapse": self.se_lapse}
