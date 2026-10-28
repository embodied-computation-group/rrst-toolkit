"""Confirmed, logged control of an RRST Teensy 4.0 + TMC2209 device. Port of rrst.Device.

The port is a serial.Serial from open_port (real hardware) or a MockPort (tests). Every
command waits for the firmware's "Valve>" prompt and checks the reply; failures raise
the errors in rrst.errors. Every line sent and every reply received is kept in
transcript, so it can be saved with the session data.
"""
import codecs
import math
import time
from numbers import Integral, Real

import serial

from . import errors
from .replies import parse_calibration_reply, parse_move_reply, parse_status, split_reply


def open_port(name, baudrate=115200):
    """Open the serial connection to a real device, asserting DTR.

    The Teensy 4.0 uses USB CDC, so the baud rate has no effect on speed. The firmware
    treats a host that doesn't assert DTR as disconnected and aborts any seek or move.
    """
    port = serial.Serial()
    port.port, port.baudrate, port.timeout = name, baudrate, 0
    port.dtr = True
    port.open()
    time.sleep(0.1)
    port.reset_input_buffer()
    return port


def list_ports():
    from serial.tools import list_ports as lp
    return [p.device for p in lp.comports()]


class Device:
    default_timeout = 10        # s, for e/d/s
    calibration_timeout = 120   # s, two precise endstop seeks
    move_timeout = 30           # s
    poll_interval = 0.005       # s

    def __init__(self, port, clock=time.monotonic):
        self.port = port
        self.transcript = []
        self.max_position = math.nan
        self.first_contact = math.nan
        self.calibrated = False
        self.enabled = False
        self.last_calibration = None
        self._clock = clock
        self._t0 = clock()
        # The firmware sends UTF-8 ("²" in the status block); a read may split a character.
        self._decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")

    def status(self):
        return parse_status(self.command("s", self.default_timeout))

    def calibrate(self, timeout=None):
        self._invalidate()
        lines = self.command("c", timeout or self.calibration_timeout)
        cal = parse_calibration_reply(lines)
        self.last_calibration = cal
        if not cal.ok:
            # The firmware leaves the driver energised after a failed 'c'.
            try:
                self.disable()
            except errors.RrstError:
                pass
            msg = f"Calibration failed: {cal.error_text}"
            if any("Serial connection lost" in line for line in lines):
                msg += (" The firmware reported the serial link as closed: the host may not be "
                        "asserting DTR. Open the port with open_port, which sets DTR.")
            raise errors.CalibrationFailed(msg)
        self.max_position = cal.max_position
        self.first_contact = cal.first_contact
        self.calibrated = True
        return cal

    def enable(self):
        # Before Precise-Piston (Msnejbjerg/RRST 7dc58a0), 'c' energises the driver but
        # does not set the firmware's enabled flag, and driver-fault monitoring only runs
        # while that flag is set. Harmless on later firmware.
        lines = self.command("e", self.default_timeout)
        if not any(line.startswith("Stepper enabled") for line in lines):
            raise errors.EnableFailed(f"Enable not confirmed. Reply: {' | '.join(lines)}")
        self.enabled = True

    def disable(self):
        # The firmware invalidates calibration on disable.
        self.command("d", self.default_timeout)
        self.enabled = False
        self._invalidate()

    def apply_motion(self, motion, status=None):
        """Set speed, acceleration and chopper mode, and check them with 's'.

        motion has keys speed, acceleration (steps/s, steps/s^2, positive integers) and
        chopperMode ("SpreadCycle" or "StealthChop"). Only values that differ from the
        device's are sent ('f', 'g', 't'). Settings stay in RAM: 'v' (save to EEPROM) is
        never sent. status: a status just read, to save one 's'. Returns the status
        read afterwards."""
        if not (isinstance(motion, dict) and {"speed", "acceleration", "chopperMode"} <= motion.keys()):
            raise errors.BadSetting("motion needs the keys speed, acceleration and chopperMode.")
        for name in ("speed", "acceleration"):
            v = motion[name]
            if not (isinstance(v, Integral) and not isinstance(v, bool) and v > 0):
                raise errors.BadSetting(f"{name} must be a positive integer; got {v!r}.")
        if motion["chopperMode"] not in ("SpreadCycle", "StealthChop"):
            raise errors.BadSetting(
                f'chopperMode must be "SpreadCycle" or "StealthChop"; got {motion["chopperMode"]!r}.')

        st = status or self.status()
        changed = False
        if st.speed != motion["speed"]:
            self._set_value("f", "Speed", motion["speed"])
            changed = True
        if st.acceleration != motion["acceleration"]:
            self._set_value("g", "Acceleration", motion["acceleration"])
            changed = True
        if st.chopper_mode != motion["chopperMode"]:
            lines = self.command("t", self.default_timeout)
            if any("UART link is down" in line for line in lines):
                raise errors.SettingFailed(
                    "Chopper mode may not have reached the driver: the TMC2209 UART link is "
                    f"down. Reply: {' | '.join(lines)}")
            changed = True
        if changed:
            st = self.status()
        if (st.speed, st.acceleration, st.chopper_mode) != \
                (motion["speed"], motion["acceleration"], motion["chopperMode"]):
            raise errors.SettingFailed(
                f"Device reports {st.speed:g} steps/s, {st.acceleration:g} steps/s^2, "
                f"{st.chopper_mode}; requested {motion['speed']}, {motion['acceleration']}, "
                f"{motion['chopperMode']}.")
        return st

    def move_to(self, steps, timeout=None):
        if not self.calibrated:
            raise errors.NotCalibrated("Calibrate the device before moving.")
        if not (isinstance(steps, Real) and not isinstance(steps, bool) and math.isfinite(steps)
                and steps == int(steps) and 0 <= steps <= self.max_position):
            raise errors.OutOfRange(f"Target must be an integer in [0, {self.max_position}]; got {steps!r}.")
        steps = int(steps)
        t0 = self._clock()
        lines = self.command(["a", str(steps)], timeout or self.move_timeout)
        mv = parse_move_reply(lines)
        mv.requested = steps
        mv.elapsed = self._clock() - t0
        if mv.ok and mv.target != steps:
            mv.ok = False
            mv.error_text = f"Firmware confirmed target {mv.target}, but {steps} was requested."
        if not mv.ok:
            msg = f"Move to {steps} failed: {mv.error_text}"
            if "stepper disabled" in mv.error_text:
                self.enabled = False
            if any("Serial connection lost" in line for line in lines):
                # The firmware disables the driver and invalidates calibration.
                self.enabled = False
                self._invalidate()
                msg += " The firmware reported the serial link as closed (DTR not asserted?)."
            raise errors.MoveFailed(msg)
        return mv

    def command(self, cmds, timeout):
        """Send one or more lines and return the parsed reply up to the prompt."""
        self._check_unsolicited()
        cmds = [cmds] if isinstance(cmds, str) else list(cmds)
        for c in cmds:
            self.port.write(f"{c}\n".encode())
            self._log("tx", c)
        buf = ""
        t0 = self._clock()
        while True:
            n = self.port.in_waiting
            if n:
                buf += self._decoder.decode(self.port.read(n))
                lines, complete = split_reply(buf)
                if complete:
                    self._log("rx", buf)
                    return lines
            if self._clock() - t0 > timeout:
                self._log("rx", buf)
                raise errors.Timeout(
                    f'No complete reply to "{", ".join(cmds)}" within {timeout} s. '
                    f"Partial reply: {' | '.join(split_reply(buf)[0])}")
            time.sleep(self.poll_interval)

    def _set_value(self, cmd, label, value):
        # 'f' and 'g' prompt for a value; the firmware confirms "<label> set to <value>".
        lines = self.command([cmd, str(value)], self.default_timeout)
        if f"{label} set to {value}" not in lines:
            raise errors.SettingFailed(f"{label} {value} not confirmed. Reply: {' | '.join(lines)}")

    def _check_unsolicited(self):
        n = self.port.in_waiting
        if not n:
            return
        text = self._decoder.decode(self.port.read(n))
        self._log("unsolicited", text)
        errs = [line for line in split_reply(text)[0] if line.lower().startswith("error")]
        if errs:
            self.enabled = False
            raise errors.DeviceFault(f"Device reported, unprompted: {' | '.join(errs)}")

    def _invalidate(self):
        self.calibrated = False
        self.max_position = math.nan
        self.first_contact = math.nan

    def _log(self, direction, text):
        self.transcript.append({"t": self._clock() - self._t0, "direction": direction, "text": text})
