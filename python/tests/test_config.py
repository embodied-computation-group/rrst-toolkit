"""Task configuration (TOML): loading, grids and validation.
Port of the configuration tests in tests/TestTaskSupport.m, plus the Python-only checks
(unknown keys, the alpha grid, the masking-sound file)."""
import math

import numpy as np
import pytest

from rrst import errors
from rrst.config import PILOT, load_config, validate

REPO = PILOT.parents[2]


def pilot():
    return load_config(PILOT)


def test_pilot_config_is_valid():
    cfg = pilot()
    validate(cfg)
    assert cfg["label"] == "PILOT"


def test_pilot_grids_match_pilotConfig_m():
    cfg = pilot()
    assert np.allclose(cfg["psi"]["stim_range"], np.linspace(0, 100, 41), atol=1e-12)
    assert np.allclose(cfg["psi"]["prior_log10_beta_range"], np.linspace(0, math.log10(16), 72), atol=1e-12)
    # MATLAB's linspace(0, 100, 72) without its alpha = 0 point (the Weibull is undefined there)
    assert np.allclose(cfg["psi"]["prior_alpha_range"], np.linspace(0, 100, 72)[1:], atol=1e-9)


def test_pilot_motion_matches_pilotConfig_m():
    assert pilot()["device"]["motion"] == {"speed": 16000, "acceleration": 10000, "chopperMode": "SpreadCycle"}


def test_paths_resolve_from_the_repo_root():
    cfg = pilot()
    assert cfg["output"]["dir"] == REPO / "data" / "raw"
    assert cfg["output"]["devices_dir"] == REPO / "devices"
    assert cfg["noise"]["file"] == REPO / "task" / "helpers" / "audio" / "rain_loop_30s.wav"


def test_grid_can_be_an_explicit_list(tmp_path):
    p = tmp_path / "c.toml"
    p.write_text(PILOT.read_text(encoding="utf-8").replace(
        "stim_range = { start = 0, stop = 100, n = 41 }", "stim_range = [0, 50, 100]"), encoding="utf-8")
    assert load_config(p)["psi"]["stim_range"].tolist() == [0, 50, 100]


def write_variant(tmp_path, old, new):
    text = PILOT.read_text(encoding="utf-8")
    assert text.count(old) == 1, old
    p = tmp_path / "c.toml"
    p.write_text(text.replace(old, new), encoding="utf-8")
    return p


@pytest.mark.parametrize("old,new", [
    ("isi = 2", "isii = 2"),                                    # misspelt key
    ("[timing]", "[timing]\nextra = 1"),                         # unknown key
    ("stim_range = { start = 0, stop = 100, n = 41 }", "stim_range = { start = 0, stop = 100 }"),
    ("stim_range = { start = 0, stop = 100, n = 41 }", "stim_range = { start = 0, stop = 100, n = 0 }"),
])
def test_unknown_keys_and_bad_grid_specs_are_rejected_on_load(tmp_path, old, new):
    with pytest.raises(errors.BadConfig):
        load_config(write_variant(tmp_path, old, new))


def set_(cfg, path, value):
    *head, last = path.split(".")
    d = cfg
    for k in head:
        d = d[k]
    d[last] = value
    return cfg


@pytest.mark.parametrize("path,value", [
    ("psi.num_trials", 99),                                  # odd total: stimulus not balanced over breaths
    ("psi.stim_range", np.linspace(0, 110, 45)),             # percent above 100
    ("stim.rest_range", [20, 120]),
    ("psi.stim_range", np.array([-5.0, 50.0])),
    ("psi.prior_alpha_range", np.linspace(0, 100, 72)),      # alpha = 0: Weibull undefined
    ("procedure", "quest"),                                   # not ported to Python
    ("metacog_trials", 10),                                   # not ported to Python
    ("timing.iti_min", 5),                                    # > iti_max
    ("stim.unit", "inches"),
    ("device.motion", {"speed": 20000, "acceleration": 10000, "chopperMode": "StealthChop"}),
    ("device.motion", {"speed": 16000, "acceleration": 0, "chopperMode": "SpreadCycle"}),
    ("device.motion", {"speed": 16000, "acceleration": 10000, "chopperMode": "Silent"}),
    ("noise.file", REPO / "task" / "helpers" / "audio" / "missing.wav"),
    ("input_device", "joystick"),
])
def test_configurations_that_cannot_run_are_rejected(path, value):
    with pytest.raises(errors.BadConfig):
        validate(set_(pilot(), path, value))


def test_stealthchop_at_16000_is_accepted():
    validate(set_(pilot(), "device.motion", {"speed": 16000, "acceleration": 20000, "chopperMode": "StealthChop"}))


def test_generated_noise_needs_a_known_colour():
    cfg = set_(pilot(), "noise.source", "generated")
    validate(cfg)
    with pytest.raises(errors.BadConfig):
        validate(set_(cfg, "noise.colour", "purple"))
