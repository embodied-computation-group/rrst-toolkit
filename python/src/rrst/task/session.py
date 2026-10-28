"""The RRST 2.0 session: calibration, trials, breaks, ratings and saving.

Port of task/RRST_2-0/code/main.m (and the trial lists of loadParams.m). Everything the
participant sees or does goes through ui (rrst.task.psychopy_ui, or a scripted UI in
the tests); every move goes through stim (rrst.Stimulator) and is confirmed before the
countdown that follows it. Differences from main.m:
  - the staircase is Psi on questplus (rrst.psi.PsiStaircase);
  - Esc works on every screen (ui raises Aborted), not only in countdowns;
  - an invalid response is repeated even on the last trial (main.m ended the session
    after trial N regardless), so Psi always gets its num_trials responses;
  - every attempt is a CSV row (valid = 0 for a repeated one); main.m overwrote it.
Files: <prefix><stem>.json (configuration, Psi state, device summary with the full
serial transcript, all trials and ratings) and <prefix><stem>.csv (one row per
attempt, MATLAB column names), with prefix "Aborted_" or "Error_" when not complete.
"""
import csv
import datetime as dt
import json
import math
import platform
import traceback
from pathlib import Path

import numpy as np

from ..psi import PsiStaircase
from .texts import texts as get_texts

CSV_COLUMNS = ["trialN", "attempt", "valid", "Stim", "SignalInterval", "Resp", "RespLR", "RT",
               "ConfResp", "ConfRT", "ConfOn", "ConfOff", "trialSuccess", "StimSteps",
               "StimMoveT", "NullMoveT", "RestLevel", "RestMoveT", "ITI", "threshold", "slope"]


class Aborted(Exception):
    """Escape was pressed."""


def _stem(cfg, subject, now):
    stem = f"RRST_{subject:04d}_{cfg['procedure']}_{now:%Y-%m-%d_%H%M}"
    return ("MOCK_" + stem) if cfg["device"]["mock"] else stem


def _jsonable(x):
    if isinstance(x, dict):
        return {k: _jsonable(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_jsonable(v) for v in x]
    if isinstance(x, np.ndarray):
        return x.tolist()
    if isinstance(x, (np.floating, np.integer)):
        return x.item()
    if isinstance(x, Path):
        return str(x)
    if isinstance(x, float) and not math.isfinite(x):
        return None
    return x


def run_session(cfg, stim, ui, noise, *, subject, language="e", seed=None, out_dir=None):
    """Run one session. Returns {"status", "json", "csv", "signal"}; re-raises errors
    after saving an Error_ file. subject 9999 is the test ID and may be reused."""
    out_dir = Path(out_dir or cfg["output"]["dir"])
    out_dir.mkdir(parents=True, exist_ok=True)
    if subject != 9999 and any(out_dir.glob(f"*RRST_{subject:04d}_*.json")):
        raise FileExistsError(f"Data for subject {subject:04d} already exist in {out_dir}. Use a different ID.")
    seed = int(np.random.SeedSequence().entropy % 2**32) if seed is None else seed
    rng = np.random.default_rng(seed)
    tx = get_texts(language, cfg["confidence"])
    t = cfg["timing"]
    p = cfg["psi"]
    psi = PsiStaircase(stim_range=p["stim_range"], alpha_range=p["prior_alpha_range"],
                       log10_beta_range=p["prior_log10_beta_range"], gamma_range=p["prior_gamma_range"],
                       lambda_range=p["prior_lambda_range"], num_trials=p["num_trials"])
    n = p["num_trials"]
    signal = rng.permutation([1] * (n // 2) + [2] * (n // 2)).tolist()
    iti = rng.uniform(t["iti_min"], t["iti_max"], n).tolist()
    question_order = rng.permutation(len(tx.questions)).tolist()
    started = dt.datetime.now()
    rec = {"status": None, "subject": subject, "language": language, "seed": seed,
           "started": started.isoformat(timespec="seconds"), "signal": signal, "iti": iti,
           "calibrations": 0, "trials": [], "ratings": {"taskSatisfaction": [], "experience": []},
           "error": None}
    stem = _stem(cfg, subject, started)

    def rate(label, question, anchors, kind):
        pos, rt = ui.slider(question, anchors, t["experience_question"])
        rec["ratings"][kind].append({"label": label, "position": pos, "rt": rt,
                                     "answered": pos is not None})
        ui.wait(0.2)

    try:
        ui.show(tx.calib)
        stim.calibrate()
        rec["calibrations"] = 1
        ui.show(tx.task)
        ui.wait_space()
        level, mv = stim.rest()
        noise.start()
        ui.show(tx.start)
        ui.wait(0.2)
        ui.wait_space()
        t_session = ui.clock()
        ui.show(tx.get_ready)
        ui.wait(3)

        trial, attempt = 1, 0
        while not psi.stop:
            attempt += 1
            row = {"trialN": trial, "attempt": attempt, "Stim": psi.x_current,
                   "SignalInterval": signal[trial - 1], "ITI": iti[trial - 1]}
            for alt in (1, 2):
                prefix = tx.isi if alt == 2 else tx.prepare_first
                ui.show(f"{prefix}{t['isi']:g} sec.", ring=True)
                if signal[trial - 1] == alt:
                    mv = stim.present(psi.x_current)
                    row["StimSteps"], row["StimMoveT"] = stim.log[-1]["steps"], mv.elapsed
                else:
                    mv = stim.null()
                    row["NullMoveT"] = mv.elapsed
                ui.countdown(prefix, t["isi"])               # from the confirmed move
                ui.breath(tx.inhale1 if alt == 1 else tx.inhale2, t["inhale"], t["breath_pause"])

            ui.wait(0.4)
            choice, rt = ui.ask_breath(tx.question, t["response"])
            valid = choice is not None
            row.update(valid=int(valid), RespLR=choice, RT=rt,
                       Resp=int(choice + 1 == signal[trial - 1]) if valid else None)
            if valid:
                psi.update(row["Resp"])
                row["threshold"], row["slope"] = psi.threshold[-1], psi.slope[-1]

            if cfg["confidence"]:
                row["ConfOn"] = ui.clock() - t_session
                pos, crt = ui.slider(tx.conf, tx.conf_anchors, t["confidence"])
                row["ConfOff"] = ui.clock() - t_session
                row["ConfResp"], row["ConfRT"] = pos, crt
                if pos is not None:
                    ui.wait(0.2)
                row["trialSuccess"] = int(valid and pos is not None)
            else:
                row["trialSuccess"] = int(valid)

            ui.show("")
            t_iti = ui.clock()
            row["RestLevel"], mv = stim.rest()
            row["RestMoveT"] = mv.elapsed
            rec["trials"].append(row)
            ui.wait_until(t_iti + iti[trial - 1])

            if not valid:
                continue
            done = trial
            trial, attempt = trial + 1, 0
            if done % t["pause_every"] == 0 and done != n:
                if cfg["probe_task_satisfaction"]:
                    label, q, anchors = tx.questions[0]
                    rate(label, q, anchors, "taskSatisfaction")
                t_pause = ui.clock()
                ui.show(f"{tx.pause}{math.ceil(t['pause'] / 60)} min.")
                if cfg["device"]["recalibrate_at_breaks"]:
                    stim.calibrate()
                    rec["calibrations"] += 1
                stim.rest()
                ui.countdown(tx.pause, t_pause + t["pause"] - ui.clock(), unit="min.")
                ui.show(tx.pause_start)
                ui.wait_space()

        stim.park()
        noise.stop()
        if cfg["probe_task_satisfaction"]:
            label, q, anchors = tx.questions[0]
            rate(label, q, anchors, "taskSatisfaction")
        if cfg["collect_experience_ratings"]:
            ui.show(tx.eq_intro)
            ui.wait_space()
            for k in question_order:
                rate(*tx.questions[k], "experience")
        rec["status"] = "complete"
        ui.show(tx.end)
    except Aborted:
        rec["status"] = "aborted"
        _park_quietly(stim, rec)
        noise.stop()
    except Exception:
        rec["status"] = "error"
        rec["error"] = traceback.format_exc()
        _park_quietly(stim, rec)
        try:
            noise.stop()
        except Exception:
            pass
        _save(cfg, rec, psi, stim, out_dir, stem)
        raise
    paths = _save(cfg, rec, psi, stim, out_dir, stem)
    return {"status": rec["status"], "signal": signal, **paths}


def _park_quietly(stim, rec):
    try:
        stim.park()
    except Exception as e:                                   # the device may be gone
        rec["parkError"] = f"{type(e).__name__}: {e}"


def _save(cfg, rec, psi, stim, out_dir, stem):
    prefix = {"complete": "", "aborted": "Aborted_", "error": "Error_"}[rec["status"]]
    j, c = out_dir / f"{prefix}{stem}.json", out_dir / f"{prefix}{stem}.csv"
    body = {**rec, "config": cfg, "psi": psi.state(), "device": stim.summary(),
            "software": {"python": platform.python_version(), "platform": platform.platform()}}
    j.write_text(json.dumps(_jsonable(body), indent=1, ensure_ascii=False), encoding="utf-8")
    with c.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=CSV_COLUMNS, extrasaction="ignore")
        w.writeheader()
        for row in rec["trials"]:
            w.writerow({k: ("" if row.get(k) is None or (isinstance(row.get(k), float) and
                                                         not math.isfinite(row[k])) else row[k])
                        for k in CSV_COLUMNS})
    return {"json": j, "csv": c}
