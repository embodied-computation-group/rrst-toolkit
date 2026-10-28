"""Thin wrapper around pyserial: connect/disconnect, line writes, and a
background reader thread that pushes decoded lines onto a queue for a
GUI (or anything else) to poll without blocking."""

import queue
import threading

import serial
import serial.tools.list_ports

DISCONNECTED_SENTINEL = object()


def _is_likely_usb_device(port_name):
    """True for the standard macOS/Linux naming of an actual USB-CDC
    serial device (e.g. this project's Teensy) - as opposed to a system
    virtual port like /dev/cu.debug-console or /dev/cu.Bluetooth-
    Incoming-Port, which pyserial enumerates right alongside real
    devices with no distinction of its own."""
    lowered = port_name.lower()
    return "usbmodem" in lowered or "usbserial" in lowered


# PJRC's registered USB vendor ID - identifies genuine Teensy hardware
# specifically, unlike _is_likely_usb_device()'s port-name heuristic
# above (which also matches non-Teensy USB-serial adapters, e.g. FTDI/
# CH340 chips, that happen to enumerate as usbserialNNNNN on macOS).
TEENSY_VID = 0x16C0


def list_teensy_ports():
    """Return device names of currently connected Teensy-vendor USB
    devices (any Teensy model/mode, not just ones running this
    project's firmware) - used to detect "more than one Teensy
    connected" before an operation (like flashing) that can't safely
    target a specific one."""
    return [p.device for p in serial.tools.list_ports.comports() if p.vid == TEENSY_VID]


def list_ports():
    """Return available serial port device names, with likely real USB
    devices sorted ahead of system virtual ports. pyserial's own
    enumeration order doesn't distinguish the two - on macOS it commonly
    comes out roughly alphabetical, which puts permanent virtual ports
    like /dev/cu.debug-console ahead of a real device's usbmodemNNNNNN
    name purely by chance. _refresh_ports() in app.py defaults to the
    first entry in this list, so this ordering is what decides which
    port gets auto-selected without the user having to hunt for the
    right one in the dropdown."""
    ports = [p.device for p in serial.tools.list_ports.comports()]
    return sorted(ports, key=lambda p: (0 if _is_likely_usb_device(p) else 1, p))


class SerialLink:
    """Manages one serial connection and a background reader thread.

    port_factory defaults to serial.Serial, but can be overridden (e.g. in
    tests) with anything exposing the same readline()/write()/close()
    interface, so this class is testable without real hardware.
    """

    def __init__(self, baudrate=115200, port_factory=serial.Serial):
        self.baudrate = baudrate
        self._port_factory = port_factory
        self._port = None
        self._reader_thread = None
        self._stop_reading = threading.Event()
        self.incoming = queue.Queue()

    def is_connected(self):
        return self._port is not None

    def connect(self, port_name):
        if self.is_connected():
            raise RuntimeError("already connected")
        self._port = self._port_factory(port_name, self.baudrate, timeout=1, write_timeout=1)
        self._stop_reading.clear()
        self._reader_thread = threading.Thread(target=self._read_loop, daemon=True)
        self._reader_thread.start()

    def disconnect(self):
        self._stop_reading.set()
        if self._reader_thread is not None:
            self._reader_thread.join(timeout=2)
        if self._port is not None:
            self._port.close()
        self._port = None
        self._reader_thread = None

    def write_line(self, text):
        if not self.is_connected():
            raise RuntimeError("not connected")
        try:
            self._port.write((text + "\n").encode())
        except Exception:
            # Mirrors _read_loop's own failure handling - a dropped
            # connection surfaces the same way regardless of whether it
            # was noticed on a read or a write, so every caller (button
            # handlers, the sweep coroutine) can rely on one path
            # (DISCONNECTED_SENTINEL via the queue) instead of needing
            # its own try/except around every write_line call.
            self.incoming.put(DISCONNECTED_SENTINEL)

    def _read_loop(self):
        while not self._stop_reading.is_set():
            try:
                raw = self._port.readline()
            except Exception:
                self.incoming.put(DISCONNECTED_SENTINEL)
                return
            if not raw:
                continue
            try:
                line = raw.decode(errors="replace").rstrip("\r\n")
            except Exception:
                continue
            if line:
                self.incoming.put(line)
