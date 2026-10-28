"""The task's trial logic (rrst.task.session), driven by a scripted UI with a fake clock and
the simulated device. No screen, no sound, no hardware.

Scripted responses: "L"/"R" = first/second breath, None = no response in the window,
"esc" = Escape. Confidence: a number 0-100, None = no rating, "esc"."""
import csv
import json

import numpy as np
import pytest

from rrst.config import PILOT, load_config
from rrst.device import Device
from rrst.mock import MockPort
from rrst.records import load_device_record
from rrst.stimulator import Stimulator
from rrst.task.session import Aborted, run_session

MOCK_ID = "0123456789ABCDEF"


class ScriptedUI:
    """Records every screen; answers from scripts; time passes only in waits."""

    def __init__(self, port, breaths, confidences=(), esc_at=None):
        self.port = port
        self.t = 0.0
        self.breaths = list(breaths)
        self.confidences = list(confidences)
        self.esc_at = esc_at                 # event kind at which Escape is "pressed"
        self.events = []

    def _event(self, kind, **kw):
        self.events.append({"kind": kind, "t": self.t, "written": len(self.port.written), **kw})
        if kind == self.esc_at:
            raise Aborted()

    def clock(self):
        return self.t

    def show(self, text, ring=False):
        self._event("show", text=text, ring=ring)

    def wait(self, seconds):
        self._event("wait", seconds=seconds)
        self.t += seconds

    def wait_until(self, t):
        self.wait(max(0.0, t - self.t))

    def wait_space(self):
        self._event("space")

    def countdown(self, prefix, seconds, unit="sec."):
        self._event("countdown", prefix=prefix, seconds=seconds)
        self.t += seconds

    def breath(self, text, inhale, pause):
        self._event("breath", text=text)
        self.t += 2 * pause + inhale

    def ask_breath(self, prompt, timeout):
        self._event("ask_breath")
        r = self.breaths.pop(0)
        if r == "esc":
            raise Aborted()
        self.t += 0.5
        return ({"L": 0, "R": 1}[r], 0.5) if r else (None, float("nan"))

    def slider(self, question, anchors, timeout):
        self._event("slider", question=question)
        r = self.confidences.pop(0) if self.confidences else 50
        if r == "esc":
            raise Aborted()
        self.t += 1.0
        return (r, 1.0) if r is not None else (None, float("nan"))


class FakeNoise:
    def __init__(self):
        self.started = self.stopped = 0

    def start(self):
        self.started += 1

    def stop(self):
        self.stopped += 1


def small_cfg(n=4, pause_every=20, confidence=True, ratings=False):
    cfg = load_config(PILOT)
    cfg["psi"]["num_trials"] = n
    cfg["timing"]["pause_every"] = pause_every
    cfg["confidence"] = confidence
    cfg["probe_task_satisfaction"] = ratings
    cfg["collect_experience_ratings"] = ratings
    return cfg


def setup(devices_dir, tmp_path, cfg, breaths, **ui_kw):
    port = MockPort(max_position=45000)
    stim = Stimulator(Device(port), load_device_record(MOCK_ID, devices_dir),
                      motion=cfg["device"]["motion"], seed=1)
    ui = ScriptedUI(port, breaths, **ui_kw)
    noise = FakeNoise()
    return port, stim, ui, noise


def run(cfg, stim, ui, noise, tmp_path, seed=3):
    return run_session(cfg, stim, ui, noise, subject=9999, language="e", seed=seed, out_dir=tmp_path)


def correct_answers(result):
    """Scripted answers that are always correct, from the saved signal order."""
    return ["L" if s == 1 else "R" for s in result["signal"]]


# --- a complete session ---------------------------------------------------------------

def test_complete_session_saves_one_row_per_trial(devices_dir, tmp_path):
    cfg = small_cfg(n=4)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "R", "R", "L"])
    res = run(cfg, stim, ui, noise, tmp_path)
    assert res["status"] == "complete"
    rows = list(csv.DictReader(open(res["csv"], encoding="utf-8")))
    assert [int(r["trialN"]) for r in rows] == [1, 2, 3, 4]
    saved = json.loads(open(res["json"], encoding="utf-8").read())
    assert saved["status"] == "complete"
    assert len(saved["psi"]["response"]) == 4
    assert noise.started == 1 and noise.stopped == 1
    assert port.position == stim.park_step                     # wedge parked open at the end


def test_signal_is_in_each_breath_equally_often(devices_dir, tmp_path):
    cfg = small_cfg(n=6)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L"] * 6)
    res = run(cfg, stim, ui, noise, tmp_path)
    assert sorted(res["signal"]) == [1, 1, 1, 2, 2, 2]


def test_accuracy_compares_the_answer_with_the_signal_breath(devices_dir, tmp_path):
    cfg = small_cfg(n=4)
    probe = run(cfg, *setup(devices_dir, tmp_path / "a", cfg, ["L"] * 4)[1:], tmp_path / "a")
    answers = correct_answers(probe)
    answers[1] = "R" if answers[1] == "L" else "L"             # one wrong answer
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, answers)
    res = run(cfg, stim, ui, noise, tmp_path)                  # same seed: same signal order
    rows = list(csv.DictReader(open(res["csv"], encoding="utf-8")))
    assert [int(r["Resp"]) for r in rows] == [1, 0, 1, 1]
    assert [int(r["RespLR"]) for r in rows] == [{"L": 0, "R": 1}[a] for a in answers]
    assert json.loads(open(res["json"]).read())["psi"]["response"] == [1, 0, 1, 1]


def test_each_breath_moves_first_then_counts_down(devices_dir, tmp_path):
    # The ISI countdown starts only after the move is confirmed: every countdown is
    # preceded by an 'a' move sent since the previous breath.
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    run(cfg, stim, ui, noise, tmp_path)
    last = 0
    for e in ui.events:
        if e["kind"] == "countdown":
            sent = port.written[last:e["written"]]
            assert "a" in sent, f"no move before the countdown at t={e['t']}"
        if e["kind"] in ("countdown", "breath"):
            last = e["written"]


def test_signal_breath_gets_the_psi_level_and_the_other_breath_zero(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    res = run(cfg, stim, ui, noise, tmp_path)
    saved = json.loads(open(res["json"]).read())
    kinds = [m["kind"] for m in saved["device"]["moves"]]
    assert kinds.count("stim") == 2 and kinds.count("null") == 2
    stim_moves = [m for m in saved["device"]["moves"] if m["kind"] == "stim"]
    assert [m["level"] for m in stim_moves] == saved["psi"]["x"]
    assert all(m["level"] == 0 for m in saved["device"]["moves"] if m["kind"] == "null")


def test_rest_move_between_trials(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    res = run(cfg, stim, ui, noise, tmp_path)
    kinds = [m["kind"] for m in json.loads(open(res["json"]).read())["device"]["moves"]]
    # rest after the instructions, then per trial: two breaths and a rest; park at the end
    assert kinds == ["rest", "stim", "null", "rest", "stim", "null", "rest", "park"] or \
        kinds == ["rest", "null", "stim", "rest", "stim", "null", "rest", "park"] or \
        kinds[0] == "rest" and kinds[-1] == "park" and kinds.count("rest") == 3


def test_motion_settings_are_applied_before_calibration(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    run(cfg, stim, ui, noise, tmp_path)
    assert port.written[:3] == ["s", "c", "e"]                 # pilot motion = what the mock runs


# --- invalid responses ----------------------------------------------------------------

def test_no_response_repeats_the_trial_without_updating_psi(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", None, "R"])
    res = run(cfg, stim, ui, noise, tmp_path)
    rows = list(csv.DictReader(open(res["csv"], encoding="utf-8")))
    assert [int(r["trialN"]) for r in rows] == [1, 2, 2]
    assert [r["valid"] for r in rows] == ["1", "0", "1"]
    assert rows[1]["Stim"] == rows[2]["Stim"]                  # same level when repeated
    assert len(json.loads(open(res["json"]).read())["psi"]["response"]) == 2


def test_an_invalid_last_trial_is_repeated(devices_dir, tmp_path):
    # main.m ended the session after trial N even if its response was invalid.
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", None, "R"])
    res = run(cfg, stim, ui, noise, tmp_path)
    assert json.loads(open(res["json"]).read())["psi"]["stop"] is True


def test_trial_success_needs_a_confidence_rating(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"], confidences=[70, None])
    res = run(cfg, stim, ui, noise, tmp_path)
    rows = list(csv.DictReader(open(res["csv"], encoding="utf-8")))
    assert [r["trialSuccess"] for r in rows] == ["1", "0"]
    assert rows[0]["ConfResp"] == "70"


def test_no_confidence_screen_when_disabled(devices_dir, tmp_path):
    cfg = small_cfg(n=2, confidence=False)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    run(cfg, stim, ui, noise, tmp_path)
    assert not any(e["kind"] == "slider" for e in ui.events)


# --- breaks ---------------------------------------------------------------------------

def test_break_recalibrates_and_is_not_held_after_the_last_trial(devices_dir, tmp_path):
    cfg = small_cfg(n=4, pause_every=2, ratings=True)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L"] * 4)
    res = run(cfg, stim, ui, noise, tmp_path)
    assert port.written.count("c") == 2                        # start + one break (after trial 2)
    saved = json.loads(open(res["json"]).read())
    assert saved["calibrations"] == 2
    assert len(saved["ratings"]["taskSatisfaction"]) == 2      # at the break and at the end
    assert sorted(r["label"] for r in saved["ratings"]["experience"]) == \
        ["Asthma", "Breathless", "Dizzy", "TaskGeneral"]


def test_break_waits_out_the_pause_counting_the_calibration(devices_dir, tmp_path):
    cfg = small_cfg(n=4, pause_every=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L"] * 4)
    run(cfg, stim, ui, noise, tmp_path)
    pause = [e for e in ui.events if e["kind"] == "countdown" and e["prefix"].startswith("Take a short break")]
    assert len(pause) == 1 and pause[0]["seconds"] == pytest.approx(cfg["timing"]["pause"])


# --- abort and errors -----------------------------------------------------------------

def test_escape_parks_the_wedge_and_saves_an_aborted_run(devices_dir, tmp_path):
    cfg = small_cfg(n=4)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "esc"])
    res = run(cfg, stim, ui, noise, tmp_path)
    assert res["status"] == "aborted"
    assert res["json"].name.startswith("Aborted_")
    assert port.position == stim.park_step
    assert noise.stopped == 1
    rows = list(csv.DictReader(open(res["csv"], encoding="utf-8")))
    assert len(rows) == 1                                       # the completed trial is kept


def test_escape_during_a_countdown_aborts(devices_dir, tmp_path):
    cfg = small_cfg(n=4)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L"] * 4, esc_at="countdown")
    assert run(cfg, stim, ui, noise, tmp_path)["status"] == "aborted"
    assert port.position == stim.park_step


def test_device_error_saves_an_error_run_and_reraises(devices_dir, tmp_path):
    cfg = small_cfg(n=4)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L"] * 4)
    port.queue_unsolicited("\nERROR: Driver fault detected - stepper disabled.\r\n")
    with pytest.raises(Exception) as exc:
        run(cfg, stim, ui, noise, tmp_path)
    assert getattr(exc.value, "identifier", "") == "rrst:deviceFault"
    saved = sorted(tmp_path.glob("Error_*.json"))
    assert len(saved) == 1
    body = json.loads(saved[0].read_text(encoding="utf-8"))
    assert body["status"] == "error" and "deviceFault" in body["error"] or "Driver fault" in body["error"]


def test_existing_data_for_a_subject_is_not_overwritten(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    run_session(cfg, stim, ui, noise, subject=7, language="e", seed=1, out_dir=tmp_path)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    with pytest.raises(FileExistsError):
        run_session(cfg, stim, ui, noise, subject=7, language="e", seed=1, out_dir=tmp_path)


def test_danish_texts_are_used(devices_dir, tmp_path):
    cfg = small_cfg(n=2)
    port, stim, ui, noise = setup(devices_dir, tmp_path, cfg, ["L", "L"])
    run_session(cfg, stim, ui, noise, subject=9999, language="d", seed=1, out_dir=tmp_path)
    assert any("Hvilket åndedrag" in (e.get("text") or "") for e in ui.events
               if e["kind"] == "show") or any(e["kind"] == "ask_breath" for e in ui.events)
