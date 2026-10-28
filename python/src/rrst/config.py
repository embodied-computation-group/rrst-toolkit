"""Task configuration: a TOML file, loaded and checked before anything moves.

    cfg = load_config(PILOT)     # python/configs/pilot.toml
    validate(cfg)                # raises BadConfig with the reason

load_config expands grids ({start, stop, n} -> numpy.linspace, or an explicit list) and
resolves paths from the repository root. Unknown keys are an error, so a misspelt
setting cannot be silently ignored. validate mirrors task/RRST_2-0/config/validateConfig.m
and adds what the Python port cannot run: procedures other than Psi, metacognition
trials, an alpha grid that reaches 0, a missing masking-sound file. Device-dependent
limits (mm levels vs the device's range) are checked again by
Stimulator.validate_levels once the device record is known.
"""
import tomllib
from pathlib import Path

import numpy as np

from . import errors

REPO = Path(__file__).resolve().parents[3]
PILOT = REPO / "python" / "configs" / "pilot.toml"

# Every key a configuration may contain; None marks a value, a dict a table.
_SCHEMA = {
    "label": None, "procedure": None, "metacog_trials": None, "confidence": None,
    "input_device": None, "run_tutorial": None, "probe_task_satisfaction": None,
    "collect_experience_ratings": None, "small_window": None,
    "device": {"mock": None, "port": None, "recalibrate_at_breaks": None,
               "motion": {"speed": None, "acceleration": None, "chopperMode": None}},
    "stim": {"unit": None, "rest_range": None, "calibration_tolerance": None},
    "psi": {"num_trials": None, "stim_range": None, "prior_alpha_range": None,
            "prior_log10_beta_range": None, "prior_gamma_range": None, "prior_lambda_range": None},
    "tutorial": {"easy_stim": None, "hard_stim": None, "example_stimuli": None, "stim_in_alt": None},
    "timing": {k: None for k in ("fixed_timing", "prepare", "inhale", "breath_pause", "response",
                                 "confidence", "isi", "iti_min", "iti_max", "pause", "pause_every",
                                 "experience_question")},
    "noise": {"enabled": None, "source": None, "file": None, "volume": None, "colour": None,
              "fs": None, "dur_s": None},
    "output": {"dir": None, "devices_dir": None},
}
_GRIDS = ("stim_range", "prior_alpha_range", "prior_log10_beta_range",
          "prior_gamma_range", "prior_lambda_range")
_NOISE_COLOURS = ("white", "pink", "brown")


def _bad(msg):
    raise errors.BadConfig(f"Configuration: {msg}")


def _check_keys(data, schema, where=""):
    for key, value in data.items():
        if key not in schema:
            _bad(f'unknown setting "{where}{key}". Check the spelling against python/configs/pilot.toml.')
        if isinstance(schema[key], dict):
            if not isinstance(value, dict):
                _bad(f'"{where}{key}" must be a table.')
            _check_keys(value, schema[key], f"{where}{key}.")
    missing = [k for k in schema if k not in data]
    if missing:
        _bad(f"missing settings: {', '.join(where + k for k in missing)}.")


def _grid(name, spec):
    if isinstance(spec, dict):
        if set(spec) != {"start", "stop", "n"}:
            _bad(f"{name} must be {{ start, stop, n }} or a list; got keys {sorted(spec)}.")
        if not (isinstance(spec["n"], int) and spec["n"] >= 1):
            _bad(f"{name}.n must be a positive integer.")
        return np.linspace(spec["start"], spec["stop"], spec["n"])
    if isinstance(spec, list) and spec and all(isinstance(v, (int, float)) for v in spec):
        return np.asarray(spec, dtype=float)
    _bad(f"{name} must be {{ start, stop, n }} or a non-empty list of numbers.")


def load_config(path):
    path = Path(path)
    with path.open("rb") as f:
        cfg = tomllib.load(f)
    _check_keys(cfg, _SCHEMA)
    for name in _GRIDS:
        cfg["psi"][name] = _grid(f"psi.{name}", cfg["psi"][name])
    cfg["noise"]["file"] = REPO / cfg["noise"]["file"]
    cfg["output"]["dir"] = REPO / cfg["output"]["dir"]
    cfg["output"]["devices_dir"] = REPO / cfg["output"]["devices_dir"]
    cfg["source"] = path.resolve()
    return cfg


def validate(cfg):
    m = cfg["device"]["motion"]
    if m.get("chopperMode") not in ("SpreadCycle", "StealthChop"):
        _bad(f'device.motion.chopperMode must be "SpreadCycle" or "StealthChop" (got {m.get("chopperMode")!r}).')
    for name in ("speed", "acceleration"):
        v = m.get(name)
        if not (isinstance(v, int) and not isinstance(v, bool) and v > 0):
            _bad(f"device.motion.{name} must be a positive integer.")
    if m["chopperMode"] == "StealthChop" and m["speed"] > 16000:
        # Martin's reliability tests, 2026-10-28: StealthChop lost steps at peak speeds of
        # 20000 steps/s (once in two runs) and 25000 and above (every run).
        _bad(f"StealthChop loses steps above about 16000 steps/s (got {m['speed']}). "
             "Use SpreadCycle or slow down.")

    unit = cfg["stim"]["unit"]
    if unit not in ("percent", "mm"):
        _bad(f'stim.unit must be "percent" or "mm" (got "{unit}").')
    if cfg["procedure"] != "psi":
        _bad(f'procedure "{cfg["procedure"]}" is not ported to Python (use "psi").')
    if cfg["metacog_trials"] != 0:
        _bad("metacognition trials are not ported to Python (metacog_trials must be 0).")
    if cfg["run_tutorial"]:
        _bad("the tutorial is not ported to Python yet (run_tutorial must be false).")
    if cfg["input_device"] not in ("mouse", "keyboard"):
        _bad(f'input_device must be "mouse" or "keyboard" (got "{cfg["input_device"]}").')

    psi = cfg["psi"]
    if psi["num_trials"] % 2:
        _bad(f"the total number of trials ({psi['num_trials']}) must be even, so the stimulus is "
             "in the first and second breath equally often.")
    levels = np.asarray(psi["stim_range"], dtype=float)
    rest = np.asarray(cfg["stim"]["rest_range"], dtype=float)
    if np.any(levels < 0):
        _bad("stimulus levels must be >= 0.")
    if unit == "percent" and np.any(np.r_[levels, rest] > 100):
        _bad(f"percent levels must be <= 100 (got max {np.r_[levels, rest].max():g}).")
    if np.any(np.asarray(psi["prior_alpha_range"]) <= 0):
        _bad("psi.prior_alpha_range must be > 0: the Weibull is undefined at alpha = 0.")
    if cfg["run_tutorial"] and unit == "percent":
        t = cfg["tutorial"]
        if np.any(np.r_[t["easy_stim"], t["hard_stim"], t["example_stimuli"]] > 100):
            _bad("tutorial levels must be <= 100 percent.")
    if cfg["timing"]["iti_min"] > cfg["timing"]["iti_max"]:
        _bad("timing.iti_min must not exceed timing.iti_max.")

    noise = cfg["noise"]
    if noise["enabled"]:
        if noise["source"] == "file":
            f = Path(noise["file"])
            if not f.is_file():
                _bad(f"noise.file {f} does not exist.")
        elif noise["source"] == "generated":
            if noise["colour"] not in _NOISE_COLOURS:
                _bad(f'noise.colour must be one of {", ".join(_NOISE_COLOURS)} (got "{noise["colour"]}").')
        else:
            _bad(f'noise.source must be "file" or "generated" (got "{noise["source"]}").')
