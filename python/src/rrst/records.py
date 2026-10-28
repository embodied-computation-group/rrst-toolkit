"""Device records and serial-port choice. Port of rrst.loadDeviceRecord and rrst.choosePort."""
import json
from pathlib import Path

from . import errors

ANCHOR_FIELDS = ("maxPositionAtMeasurement", "zeroOffset", "fullOffset")


def load_device_record(device_id, devices_dir):
    """Read the bench-measured record devices/<device_id>.json. A device without a
    record has no measured anchors, so that is an error, never a default."""
    f = Path(devices_dir) / f"{device_id}.json"
    if not f.is_file():
        raise errors.NoDeviceRecord(
            f"No record for device {device_id} (looked for {f}). Measure its anchors at the "
            f"bench (bench/anchorSession.m) and save them in devices/ before running the task.")
    rec = json.loads(f.read_text(encoding="utf-8"))
    if not all(k in rec.get("anchors", {}) for k in ANCHOR_FIELDS):
        raise errors.NoDeviceRecord(f"Record {f} has no complete anchors ({', '.join(ANCHOR_FIELDS)}).")
    return rec


def choose_port(requested, available):
    """Pick the device's serial port without guessing: "auto" is accepted only when
    exactly one port is available."""
    available = list(available)
    if requested == "auto":
        if not available:
            raise errors.NoPort("No serial port is available. Is the device plugged in?")
        if len(available) > 1:
            raise errors.AmbiguousPort(
                f"Several serial ports are available ({', '.join(available)}). "
                f"Set device.port in the configuration to the device's port.")
        return available[0]
    if requested in available:
        return requested
    raise errors.NoPort(f"Port {requested} is not available (available: {', '.join(available + ['none'])}).")
