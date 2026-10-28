import queue
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import serial.tools.list_ports

from serial_link import SerialLink, DISCONNECTED_SENTINEL, list_ports, list_teensy_ports


class FakeSerial:
    """Minimal stand-in for pyserial's Serial, used via dependency
    injection so these tests need no real hardware or port."""

    def __init__(self, port, baudrate, timeout=1, write_timeout=1):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.write_timeout = write_timeout
        self.written = []
        self._lines = queue.Queue()
        self.closed = False
        self._raise_on_read = False
        self._raise_on_write = False

    def feed_line(self, text):
        self._lines.put((text + "\r\n").encode())

    def raise_on_next_read(self):
        self._raise_on_read = True

    def raise_on_write(self):
        self._raise_on_write = True

    def readline(self):
        if self._raise_on_read:
            raise IOError("device unplugged")
        try:
            return self._lines.get(timeout=0.2)
        except queue.Empty:
            return b""

    def write(self, data):
        if self._raise_on_write:
            raise IOError("device unplugged")
        self.written.append(data)

    def close(self):
        self.closed = True


def test_connect_starts_reader_and_write_line_sends_bytes():
    fakes = []

    def factory(port, baudrate, timeout=1, write_timeout=1):
        f = FakeSerial(port, baudrate, timeout, write_timeout)
        fakes.append(f)
        return f

    link = SerialLink(port_factory=factory)
    link.connect("/dev/fake")
    assert link.is_connected()

    link.write_line("e")
    assert fakes[0].written == [b"e\n"]

    link.disconnect()
    assert fakes[0].closed
    assert not link.is_connected()


def test_reader_thread_pushes_lines_onto_queue():
    def factory(port, baudrate, timeout=1, write_timeout=1):
        return FakeSerial(port, baudrate, timeout, write_timeout)

    link = SerialLink(port_factory=factory)
    link.connect("/dev/fake")
    link._port.feed_line("Stepper enabled in normal mode")

    line = link.incoming.get(timeout=2)
    assert line == "Stepper enabled in normal mode"

    link.disconnect()


def test_read_error_pushes_disconnected_sentinel():
    def factory(port, baudrate, timeout=1, write_timeout=1):
        f = FakeSerial(port, baudrate, timeout, write_timeout)
        f.raise_on_next_read()
        return f

    link = SerialLink(port_factory=factory)
    link.connect("/dev/fake")

    item = link.incoming.get(timeout=2)
    assert item is DISCONNECTED_SENTINEL

    link.disconnect()


def test_write_error_pushes_disconnected_sentinel_instead_of_raising():
    fakes = []

    def factory(port, baudrate, timeout=1, write_timeout=1):
        f = FakeSerial(port, baudrate, timeout, write_timeout)
        fakes.append(f)
        return f

    link = SerialLink(port_factory=factory)
    link.connect("/dev/fake")
    fakes[0].raise_on_write()

    # Does not raise - every caller (button handlers, the sweep coroutine)
    # relies on the queue instead of needing its own try/except here.
    link.write_line("e")

    item = link.incoming.get(timeout=2)
    assert item is DISCONNECTED_SENTINEL

    link.disconnect()


class FakePortInfo:
    def __init__(self, device, vid=None):
        self.device = device
        self.vid = vid


def test_list_ports_sorts_likely_usb_devices_first(monkeypatch):
    # Reproduces the real complaint: pyserial's own enumeration order on
    # macOS comes out roughly alphabetical, which puts the permanent
    # /dev/cu.debug-console virtual port ahead of a real device's
    # usbmodemNNNNNN name - and app.py's _refresh_ports() auto-selects
    # whatever list_ports() returns first.
    fake_ports = [
        FakePortInfo("/dev/cu.Bluetooth-Incoming-Port"),
        FakePortInfo("/dev/cu.debug-console"),
        FakePortInfo("/dev/cu.usbmodem159042401"),
    ]
    monkeypatch.setattr(serial.tools.list_ports, "comports", lambda: fake_ports)

    ports = list_ports()

    assert ports[0] == "/dev/cu.usbmodem159042401"
    assert ports[1:] == ["/dev/cu.Bluetooth-Incoming-Port", "/dev/cu.debug-console"]


def test_list_ports_sorts_usbserial_devices_first_too(monkeypatch):
    # usbserial is the standard naming for e.g. FTDI/CH340-based boards -
    # not just Teensy's usbmodem.
    fake_ports = [FakePortInfo("/dev/cu.debug-console"), FakePortInfo("/dev/cu.usbserial-14110")]
    monkeypatch.setattr(serial.tools.list_ports, "comports", lambda: fake_ports)

    assert list_ports()[0] == "/dev/cu.usbserial-14110"


def test_list_ports_keeps_multiple_real_devices_alphabetical_among_themselves(monkeypatch):
    fake_ports = [FakePortInfo("/dev/cu.usbmodem2"), FakePortInfo("/dev/cu.usbmodem1")]
    monkeypatch.setattr(serial.tools.list_ports, "comports", lambda: fake_ports)

    assert list_ports() == ["/dev/cu.usbmodem1", "/dev/cu.usbmodem2"]


def test_list_teensy_ports_filters_by_vendor_id(monkeypatch):
    fake_ports = [
        FakePortInfo("/dev/cu.debug-console"),  # vid=None, not a USB device at all
        FakePortInfo("/dev/cu.usbmodem1", vid=0x16C0),  # a real Teensy
        FakePortInfo("/dev/cu.usbserial-14110", vid=0x0403),  # a non-Teensy USB-serial adapter (e.g. FTDI)
    ]
    monkeypatch.setattr(serial.tools.list_ports, "comports", lambda: fake_ports)

    assert list_teensy_ports() == ["/dev/cu.usbmodem1"]


def test_list_teensy_ports_finds_multiple(monkeypatch):
    fake_ports = [
        FakePortInfo("/dev/cu.usbmodem1", vid=0x16C0),
        FakePortInfo("/dev/cu.usbmodem2", vid=0x16C0),
    ]
    monkeypatch.setattr(serial.tools.list_ports, "comports", lambda: fake_ports)

    assert sorted(list_teensy_ports()) == ["/dev/cu.usbmodem1", "/dev/cu.usbmodem2"]


def test_list_teensy_ports_empty_when_none_connected(monkeypatch):
    monkeypatch.setattr(serial.tools.list_ports, "comports", lambda: [])

    assert list_teensy_ports() == []


def _connected_link():
    fakes = []

    def factory(port, baudrate, timeout=1, write_timeout=1):
        f = FakeSerial(port, baudrate, timeout, write_timeout)
        fakes.append(f)
        return f

    link = SerialLink(port_factory=factory)
    link.connect("FAKE")
    return link, fakes[0]


def test_blocking_command_marks_link_busy_until_completion_line():
    link, fake = _connected_link()
    try:
        assert not link.is_busy()
        link.write_line("y")
        assert link.is_busy()
        fake.feed_line("Retracting to First-Contact position: 16468")
        assert link.incoming.get(timeout=1) == "Retracting to First-Contact position: 16468"
        assert link.is_busy()
        fake.feed_line("Move complete.")
        assert link.incoming.get(timeout=1) == "Move complete."
        assert not link.is_busy()
    finally:
        link.disconnect()


def test_error_reply_also_clears_busy():
    link, fake = _connected_link()
    try:
        link.write_line("c")
        assert link.is_busy()
        fake.feed_line("ERROR: Min endstop not found - calibration aborted.")
        link.incoming.get(timeout=1)
        assert not link.is_busy()
    finally:
        link.disconnect()


def test_non_blocking_commands_do_not_mark_busy():
    link, _ = _connected_link()
    try:
        for cmd in ("s", "x", "f", "g", "t", "v"):
            link.write_line(cmd)
            assert not link.is_busy()
    finally:
        link.disconnect()
