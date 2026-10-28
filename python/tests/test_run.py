"""The launcher's device setup (rrst.task.run.connect), without PsychoPy or hardware."""
import pytest

from rrst import errors
from rrst.config import PILOT, load_config
from rrst.mock import MockPort
from rrst.task import run


def test_mock_session_uses_the_simulated_device_and_its_record():
    cfg = load_config(PILOT)
    cfg["device"]["mock"] = True
    stim, port, status = run.connect(cfg)
    assert isinstance(port, MockPort)
    assert stim.record["deviceId"] == "0123456789ABCDEF"
    assert stim.motion == cfg["device"]["motion"]
    assert port.written == ["s"]                       # only status before the session


def test_auto_port_ignores_non_teensy_ports(monkeypatch):
    cfg = load_config(PILOT)
    monkeypatch.setattr(run, "list_teensy_ports", lambda: [])
    with pytest.raises(errors.NoPort):
        run.connect(cfg)


def test_grid_beyond_the_device_range_is_rejected_before_anything_moves():
    cfg = load_config(PILOT)
    cfg["device"]["mock"] = True
    cfg["stim"]["unit"] = "mm"
    cfg["stim"]["rest_range"] = [2, 10]
    cfg["psi"]["stim_range"] = [0.0, 17.0]             # the mock record spans 15.5 mm
    with pytest.raises(errors.LevelOutOfRange):
        run.connect(cfg)
