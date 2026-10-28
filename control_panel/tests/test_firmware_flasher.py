import sys
import os
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from firmware_flasher import FirmwareFlasher, resource_path


class FakeProcess:
    """Minimal stand-in for subprocess.Popen, used via dependency
    injection so these tests need no real teensy_loader_cli binary or
    hardware. Mirrors real Popen's actual kill()/wait() semantics: once
    either one has resolved returncode, the other doesn't overwrite it
    (real Popen.kill() checks poll() first and no-ops on an already-
    exited process)."""

    def __init__(self, lines, returncode):
        self.stdout = iter(line + "\n" for line in lines)
        self._returncode = returncode
        self.returncode = None
        self.killed = False

    def wait(self):
        if self.returncode is None:
            self.returncode = self._returncode
        return self.returncode

    def kill(self):
        if self.returncode is None:
            self.killed = True
            self.returncode = -9


class NeverRespondingProcess:
    """Simulates teensy_loader_cli's -w wait with no device ever
    appearing: produces no output and only exits once killed."""

    def __init__(self):
        self.killed = False
        self.returncode = None

    def __iter__(self):
        return self

    def __next__(self):
        while not self.killed:
            time.sleep(0.01)
        raise StopIteration

    @property
    def stdout(self):
        return self

    def wait(self):
        if self.returncode is None:
            self.returncode = -9
        return self.returncode

    def kill(self):
        if self.returncode is None:
            self.killed = True


def test_reports_each_line_and_success_returncode():
    lines_seen = []
    done_seen = []

    fake_proc = FakeProcess(["Found HID device", "Programming...", "Booting"], returncode=0)

    def factory(args):
        return fake_proc

    flasher = FirmwareFlasher(on_line=lines_seen.append, on_done=done_seen.append, popen_factory=factory, settle_s=0)
    flasher._run()  # call directly (not .start()) so this test doesn't need threading

    assert lines_seen == ["Found HID device", "Programming...", "Booting"]
    assert done_seen == [0]


def test_reports_nonzero_returncode_on_failure():
    done_seen = []
    fake_proc = FakeProcess(["ERROR: file does not exist"], returncode=1)

    flasher = FirmwareFlasher(on_line=lambda _: None, on_done=done_seen.append, popen_factory=lambda args: fake_proc, settle_s=0)
    flasher._run()

    assert done_seen == [1]


def test_reports_none_when_launch_itself_fails():
    lines_seen = []
    done_seen = []

    def factory(args):
        raise FileNotFoundError("no such file: teensy_loader_cli")

    flasher = FirmwareFlasher(on_line=lines_seen.append, on_done=done_seen.append, popen_factory=factory, settle_s=0)
    flasher._run()

    assert len(lines_seen) == 1
    assert "could not start teensy_loader_cli" in lines_seen[0]
    assert done_seen == [None]


def test_times_out_and_reports_none_if_device_never_appears():
    proc = NeverRespondingProcess()
    done_seen = []

    flasher = FirmwareFlasher(
        on_line=lambda _: None, on_done=done_seen.append,
        popen_factory=lambda args: proc, timeout_s=0.05, settle_s=0,
    )
    flasher._run()

    assert done_seen == [None]
    assert proc.killed


def test_reports_none_and_kills_process_if_a_callback_raises():
    fake_proc = FakeProcess(["one line", "two line"], returncode=0)

    def exploding_on_line(line):
        raise RuntimeError("UI queue was already closed")

    done_seen = []
    flasher = FirmwareFlasher(on_line=exploding_on_line, on_done=done_seen.append, popen_factory=lambda args: fake_proc, settle_s=0)
    flasher._run()

    assert done_seen == [None]
    assert fake_proc.killed


def test_waits_settle_s_before_launching_to_let_the_os_release_the_port():
    fake_proc = FakeProcess(["line"], returncode=0)
    started_at = []

    def factory(args):
        started_at.append(time.monotonic())
        return fake_proc

    begin = time.monotonic()
    flasher = FirmwareFlasher(
        on_line=lambda _: None, on_done=lambda _: None, popen_factory=factory, settle_s=0.1
    )
    flasher._run()

    assert started_at[0] - begin >= 0.1


class FakeSerialPort:
    def __init__(self, opened):
        self._opened = opened

    def close(self):
        self._opened.append("closed")


def test_requests_bootloader_reboot_at_134_baud_before_launching():
    events = []

    def port_factory(port_name, baudrate):
        events.append(("open", port_name, baudrate))
        return FakeSerialPort(events)

    def factory(args):
        events.append("launch")
        return FakeProcess([], returncode=0)

    flasher = FirmwareFlasher(
        on_line=lambda _: None, on_done=lambda _: None, popen_factory=factory, settle_s=0,
        reboot_port="COM5", reboot_port_factory=port_factory,
    )
    flasher._run()

    assert events == [("open", "COM5", 134), "closed", "launch"]


def test_reboot_request_failure_is_reported_but_flash_still_runs():
    lines_seen = []
    done_seen = []

    def port_factory(port_name, baudrate):
        raise OSError("device disconnected")

    flasher = FirmwareFlasher(
        on_line=lines_seen.append, on_done=done_seen.append,
        popen_factory=lambda args: FakeProcess([], returncode=0), settle_s=0,
        reboot_port="COM5", reboot_port_factory=port_factory,
    )
    flasher._run()

    assert any("device disconnected" in line for line in lines_seen)
    assert done_seen == [0]


def test_no_reboot_request_without_a_reboot_port():
    def port_factory(port_name, baudrate):
        raise AssertionError("should not open any port")

    done_seen = []
    flasher = FirmwareFlasher(
        on_line=lambda _: None, on_done=done_seen.append,
        popen_factory=lambda args: FakeProcess([], returncode=0), settle_s=0,
        reboot_port_factory=port_factory,
    )
    flasher._run()

    assert done_seen == [0]


def test_resource_path_falls_back_to_this_files_directory_outside_pyinstaller():
    # Outside a PyInstaller bundle, sys._MEIPASS doesn't exist, so this
    # should resolve relative to firmware_flasher.py's own directory.
    expected_dir = os.path.dirname(os.path.abspath(sys.modules["firmware_flasher"].__file__))
    path = resource_path(os.path.join("firmware", "RRST_Teensy_4_version_TMC2209.hex"))
    assert path == os.path.join(expected_dir, "firmware", "RRST_Teensy_4_version_TMC2209.hex")
