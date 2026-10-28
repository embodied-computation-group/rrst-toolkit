"""Run the RRST 2.0 task in Python. Port of task/RRST_2-0/runRRST.m.

    uv run --extra task python -m rrst.task.run                  # pilot config, real device
    uv run --extra task python -m rrst.task.run --mock           # simulated device
    uv run --extra task python -m rrst.task.run --port COM7 --subject 12 --language d

Before anything moves this checks the configuration, connects to the device, loads its
record from devices/ (by the ID the firmware reports), checks every configured level
against the device's range, and asks the operator to confirm the tube is seated. Data go
to the configuration's output.dir (data/raw/, never committed). Esc during the task
parks the wedge open and saves what was collected.
"""
import argparse
import sys

from ..config import PILOT, load_config, validate
from ..device import Device, list_ports, list_teensy_ports, open_port
from ..mock import MockPort
from ..records import choose_port, load_device_record
from ..stimulator import Stimulator

MOCK_ID = "0123456789ABCDEF"


def connect(cfg):
    """Open the device (or the simulated one) and build the Stimulator. Sends only 's'."""
    d = cfg["device"]
    if d["mock"]:
        port = MockPort(max_position=45000, device_id=MOCK_ID)
    else:
        available = list_teensy_ports() if d["port"] == "auto" else list_ports()
        port = open_port(choose_port(d["port"], available))
    dev = Device(port)
    status = dev.status()
    rec = load_device_record(status.device_id, cfg["output"]["devices_dir"])
    stim = Stimulator(dev, rec, unit=cfg["stim"]["unit"], rest_range=cfg["stim"]["rest_range"],
                      calibration_tolerance=cfg["stim"]["calibration_tolerance"], motion=d["motion"])
    stim.validate_levels(cfg["psi"]["stim_range"])
    return stim, port, status


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--config", default=str(PILOT))
    ap.add_argument("--mock", action="store_true", help="simulated device, no hardware moves")
    ap.add_argument("--port", help='serial port, e.g. COM7 (default: the config\'s, "auto")')
    ap.add_argument("--subject", type=int)
    ap.add_argument("--language", choices=["e", "d"])
    ap.add_argument("--seed", type=int)
    args = ap.parse_args(argv)

    cfg = load_config(args.config)
    if args.mock:
        cfg["device"]["mock"] = True
    if args.port:
        cfg["device"]["port"] = args.port
    validate(cfg)
    subject = args.subject if args.subject is not None else int(input("Subject ID (e.g. 1; 9999 = test)? ") or 9999)
    language = args.language or (input("Language? (e English, d Danish) ").strip() or "e")

    stim, port, st = connect(cfg)
    if cfg["device"]["mock"]:
        print("\n*** MOCK DEVICE: no hardware is moved. For testing the task only. ***\n", file=sys.stderr)
    m = cfg["device"]["motion"]
    print(f"Device {st.device_id}, firmware {st.software_version}, git commit {st.git_commit or '-'}")
    print(f"Device settings before the session: {st.speed:g} steps/s, {st.acceleration:g} steps/s^2, "
          f"{st.chopper_mode} (set to {m['speed']}, {m['acceleration']}, {m['chopperMode']} at calibration)")
    a = stim.record["anchors"]
    if a.get("provisional"):
        print(f"Note: this device's anchors are provisional: {a.get('provisionalReason', '')}", file=sys.stderr)
    print(f"Scale: 0-{stim.scale_max:g} {stim.unit} (zero = wedge touching the tube, max = barely possible to inhale)")
    input(f"\nCalibration runs with the tube {a.get('calibrationCondition', '?').replace('tube ', '')}, "
          "as in the device record.\nThe wedge will close fully, then open. Press Enter when ready...")

    from .psychopy_ui import Noise, PsychoPyUI      # PsychoPy only when a session really runs
    from .session import run_session
    ui = PsychoPyUI(cfg)
    try:
        res = run_session(cfg, stim, ui, Noise(cfg), subject=subject, language=language, seed=args.seed)
    finally:
        ui.close()
        port.close()                                # the firmware disables the motor when the link drops
    print(f"Run {res['status']}. Saved {res['json']} and {res['csv']}")
    if stim.calibrations and res["status"] == "complete":
        import json
        psi = json.loads(res["json"].read_text(encoding="utf-8"))["psi"]
        print(f"Threshold estimate: {psi['threshold'][-1]:.2f} {stim.unit}; "
              f"slope (beta): {10 ** psi['slope'][-1]:.2f}")


if __name__ == "__main__":
    main()
