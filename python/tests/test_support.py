"""Device records, port choice and masking noise. Port of the matching parts of
tests/TestTaskSupport.m (the task configuration is tested in test_config.py)."""
import numpy as np
import pytest

from rrst import errors
from rrst.noise import masking_noise
from types import SimpleNamespace

from rrst.records import choose_port, load_device_record, teensy_ports


# --- device records ------------------------------------------------------------------

def test_real_record_loads(devices_dir):
    rec = load_device_record("2E4441D76D5F2996", devices_dir)
    assert rec["anchors"]["zeroOffset"] == 25600
    assert rec["anchors"]["fullOffset"] == 800
    assert rec["anchors"]["maxPositionAtMeasurement"] == 41296


def test_missing_record_is_an_error(devices_dir):
    with pytest.raises(errors.NoDeviceRecord):
        load_device_record("FFFFFFFFFFFFFFFF", devices_dir)


def test_record_without_anchors_is_an_error(tmp_path):
    (tmp_path / "AAAA.json").write_text('{"deviceId": "AAAA", "anchors": {"zeroOffset": 1}}')
    with pytest.raises(errors.NoDeviceRecord):
        load_device_record("AAAA", tmp_path)


# --- port choice -----------------------------------------------------------------------

def test_explicit_port_is_used():
    assert choose_port("COM7", ["COM3", "COM7"]) == "COM7"


def test_explicit_port_must_exist():
    with pytest.raises(errors.NoPort):
        choose_port("COM9", ["COM3"])


def test_auto_picks_the_only_port():
    assert choose_port("auto", ["COM4"]) == "COM4"


def port_info(device, vid, pid):
    # Shaped like serial.tools.list_ports_common.ListPortInfo (only what teensy_ports reads).
    return SimpleNamespace(device=device, vid=vid, pid=pid)


def test_teensy_ports_skip_other_serial_devices():
    # The stim laptop, 2026-10-28: COM4/COM5 are the LTE modem (VID 8087), COM7 the
    # Teensy through a hub (VID 16C0, PID 0483 = PJRC USB serial).
    ports = [port_info("COM4", 0x8087, 0x0ACA), port_info("COM5", 0x8087, 0x0ACA),
             port_info("COM7", 0x16C0, 0x0483), port_info("COM9", None, None)]
    assert teensy_ports(ports) == ["COM7"]
    assert choose_port("auto", teensy_ports(ports)) == "COM7"


def test_teensy_ports_can_be_empty():
    assert teensy_ports([port_info("COM4", 0x8087, 0x0ACA)]) == []


def test_auto_refuses_to_guess_between_ports():
    with pytest.raises(errors.AmbiguousPort):
        choose_port("auto", ["COM3", "COM4"])
    with pytest.raises(errors.NoPort):
        choose_port("auto", [])


# --- masking noise ---------------------------------------------------------------------

def test_noise_has_requested_length_and_stays_in_range():
    x = masking_noise(8000, 2, "pink", 1)
    assert x.shape == (16000,)
    assert np.max(np.abs(x)) <= 1
    assert np.std(x) > 0.05


def test_noise_is_reproducible_with_seed():
    assert np.array_equal(masking_noise(8000, 1, "pink", 7), masking_noise(8000, 1, "pink", 7))
    assert not np.array_equal(masking_noise(8000, 1, "pink", 7), masking_noise(8000, 1, "pink", 8))


def band_power_ratio(x, fs):
    X = np.abs(np.fft.fft(x)) ** 2
    f = np.arange(len(x)) * fs / len(x)
    return X[(f >= 50) & (f <= 100)].mean() / X[(f >= 2000) & (f <= 4000)].mean()


def test_pink_noise_has_more_low_than_high_frequency_power():
    # Pink: power ~ 1/f, so 50-100 Hz carries far more power per Hz than 2-4 kHz.
    fs = 16000
    assert band_power_ratio(masking_noise(fs, 4, "pink", 3), fs) > 10
    assert band_power_ratio(masking_noise(fs, 4, "white", 3), fs) < 2


def test_noise_loops_without_a_jump():
    # The buffer is looped; the step from last to first sample must be as small as
    # an ordinary sample-to-sample step.
    x = masking_noise(8000, 2, "pink", 5)
    assert abs(x[-1] - x[0]) < 4 * np.std(np.diff(x))


def test_unknown_noise_colour_is_an_error():
    with pytest.raises(errors.BadNoise):
        masking_noise(8000, 1, "purple", 1)
