"""Runs teensy_loader_cli in a background thread to flash the bundled
firmware, reporting progress via callbacks so a GUI (or anything else,
including a test) can observe it without being tied to Tkinter - same
shape as sweep.py's SweepTest."""

import os
import subprocess
import sys
import threading
import time

import serial

TEENSY40_MCU = "TEENSY40"

# Opening a Teensy's USB serial port at this baud rate makes Teensyduino's
# USB stack reboot the board into its HalfKay bootloader - the same
# signal teensy_loader_cli's libusb build sends for -s. Its Win32 build
# doesn't implement -s at all, so without this a Windows user would have
# to press the board's button by hand on every flash.
REBOOT_BAUD = 134

# The bundled uploader binary's filename differs by OS - Windows needs
# the .exe suffix to be invoked directly by path (not found via PATH
# lookup, where Windows' PATHEXT would otherwise handle this for you).
LOADER_FILENAME = "teensy_loader_cli.exe" if sys.platform.startswith("win") else "teensy_loader_cli"

# After an app-initiated disconnect, give the OS a brief moment to fully
# release the serial port before teensy_loader_cli tries to use it -
# pyserial's close() returning doesn't guarantee every platform/driver
# has finished tearing the port down immediately. Runs on this module's
# own background thread (inside _run()), never on the caller's thread,
# so it can never block a Tkinter UI. Overridable per-instance (see
# FirmwareFlasher.__init__) so tests don't pay this real-time delay.
PRE_FLASH_SETTLE_S = 0.3

# Covers the WHOLE flash attempt (waiting for the device to appear, and
# the actual programming+verify once it does), not just the wait phase -
# teensy_loader_cli gives no way to tell "still waiting" apart from "now
# actively programming" without much more complex line-by-line I/O
# timing than this warrants. Generous enough to comfortably cover a
# normal flash (a few seconds of actual programming) plus a slow manual
# button press if the automatic soft-reboot (-s) doesn't reach the
# device. Overridable per-instance (see FirmwareFlasher.__init__) so
# tests can use a short timeout instead of actually waiting 60s.
FLASH_TIMEOUT_S = 60


def resource_path(relative_path):
    """Resolves a bundled resource's path whether running from source
    (relative to this file's own directory) or from a PyInstaller-built
    executable, where bundled data files are extracted to a temp
    directory referenced by sys._MEIPASS."""
    base_path = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)


class FirmwareFlasher:
    """Runs one flash attempt in a background thread.

    on_line(str) is called for each line of teensy_loader_cli's output.
    on_done(returncode) is called exactly once when the attempt is over:
    returncode is teensy_loader_cli's real exit code (0 = success), or
    None if the subprocess could never be started at all (e.g. the
    bundled binary is missing), it was killed for exceeding
    timeout_s, or on_line itself raised partway through (in which case
    the subprocess is killed defensively before on_done fires, so it's
    never left running unattended).

    Both callbacks run on the background thread start() creates, NOT on
    the thread that called start() - marshal them back to a UI thread
    yourself if needed (e.g. a queue.Queue polled via Tkinter's
    root.after(), the same pattern SerialLink's reader thread already
    uses) before touching any UI object from inside them.

    popen_factory defaults to a thin wrapper around subprocess.Popen,
    but can be overridden (e.g. in tests) with anything that takes the
    argument list and returns an object exposing the same
    stdout/wait()/kill() interface. timeout_s defaults to the module
    constant but can be overridden per instance, mainly so tests can
    exercise the timeout path without a real 60-second wait. settle_s
    likewise defaults to the module constant but can be set to 0 in
    tests, since it has nothing to verify by actually elapsing.

    reboot_port, if given, is the Teensy's serial port: it's briefly
    opened at REBOOT_BAUD before teensy_loader_cli starts, so the board
    reboots into its bootloader on its own. A failure there is reported
    via on_line but isn't fatal - teensy_loader_cli then just waits for
    a manual button press, as it would without this. reboot_port_factory
    defaults to serial.Serial and is overridable for tests, like
    popen_factory.
    """

    def __init__(self, on_line, on_done, popen_factory=None, timeout_s=FLASH_TIMEOUT_S, settle_s=PRE_FLASH_SETTLE_S,
                 reboot_port=None, reboot_port_factory=serial.Serial):
        self._on_line = on_line
        self._on_done = on_done
        self._popen_factory = popen_factory or self._default_popen_factory
        self._timeout_s = timeout_s
        self._settle_s = settle_s
        self._reboot_port = reboot_port
        self._reboot_port_factory = reboot_port_factory

    @staticmethod
    def _default_popen_factory(args):
        return subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    def start(self):
        thread = threading.Thread(target=self._run, daemon=True)
        thread.start()

    def _run(self):
        time.sleep(self._settle_s)

        if self._reboot_port:
            self._request_bootloader_reboot()

        hex_path = resource_path(os.path.join("firmware", "RRST_Teensy_4_version_TMC2209.hex"))
        loader_path = resource_path(os.path.join("firmware", LOADER_FILENAME))
        args = [loader_path, f"--mcu={TEENSY40_MCU}", "-s", "-w", "-v", hex_path]

        try:
            proc = self._popen_factory(args)
        except Exception as exc:
            self._on_line(f"ERROR: could not start teensy_loader_cli: {exc}")
            self._on_done(None)
            return

        timed_out = threading.Event()

        def _on_timeout():
            timed_out.set()
            proc.kill()

        timer = threading.Timer(self._timeout_s, _on_timeout)
        timer.start()
        returncode = None
        callback_failed = False
        try:
            for line in proc.stdout:
                self._on_line(line.rstrip("\r\n"))
            returncode = proc.wait()
        except Exception:
            # Most likely on_line itself raised (e.g. a UI queue already
            # torn down) - don't call it again to report this, it may be
            # the thing that's broken. Kill the process defensively so a
            # callback bug can't leave teensy_loader_cli running
            # unattended with nobody left to notice when it finishes.
            callback_failed = True
            proc.kill()
            try:
                proc.wait()
            except Exception:
                pass
        finally:
            timer.cancel()

        if timed_out.is_set() or callback_failed:
            self._on_done(None)
        else:
            self._on_done(returncode)

    def _request_bootloader_reboot(self):
        self._on_line(f"Requesting bootloader reboot via {self._reboot_port}...")
        try:
            port = self._reboot_port_factory(self._reboot_port, REBOOT_BAUD)
            port.close()
        except Exception as exc:
            # The board may already have dropped off the bus mid-close
            # (it reboots as soon as it sees the baud change), which some
            # drivers report as an error - harmless either way, since
            # teensy_loader_cli falls back to waiting for the button.
            self._on_line(f"Note: automatic reboot request reported: {exc}")
