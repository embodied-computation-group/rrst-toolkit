"""Simulated RRST firmware behind a pyserial-like interface. Port of rrst.MockPort.

Implements the parts of serial.Serial that Device uses: write, read, in_waiting,
reset_input_buffer and the dtr attribute. Each reply is written byte for byte from the
format strings in RRST_Teensy_4_version_TMC2209.ino (Msnejbjerg/RRST c298eed; 'f', 'g',
't' and the Git Commit status line from 8720abc),
including its mixed CRLF/LF line endings and the trailing "Valve>" prompt. Replies are
available as soon as the command is written: there is no motion time.

Fault injection (the fault attribute):
  "calibrateMinMissing"  'c' fails: min endstop not found
  "moveWarning"          'a' succeeds after one auto-corrected endstop hit
  "moveSafetyDisable"    'a' fails: three unexpected hits, driver disabled
  "silent"               no reply to anything (tests timeouts)
  "settingIgnored"       'f'/'g' prompt, but the value is not accepted
  "uartDown"             't' warns that the TMC2209 UART link is down
dtr = False simulates a host that never asserts DTR: the firmware's
CheckSerialConnection() then aborts the seek or move. That reply text is inferred from
the source, not captured from hardware.
chunk_size limits how many bytes one read() returns, as a real port may.
stray_prompt_after_move=True: like Patient-Regulator on the stim laptop (2026-10-28),
every move is followed by one extra empty prompt. It is sent with the host's next
command, and that command's reply only follows on a later read: the race seen when a
move is sent within milliseconds of the previous one.
"""

PROMPT = "\r\nValve>"


class MockPort:
    def __init__(self, max_position=45000, saved_max_position=-1, position=20000,
                 device_id="0123456789ABCDEF",
                 software_version="Patient-Regulator (Oct  7 2026 08:45:06)",
                 retract_steps=24000, retract_mm=15, speed=16000, acceleration=10000,
                 run_current=800, chopper_mode="SpreadCycle", git_commit="",
                 dtr=True, fault="", chunk_size=None, stray_prompt_after_move=False):
        self.max_position = max_position
        self.saved_max_position = saved_max_position   # -1: nothing saved in EEPROM yet
        self.position = position
        self.device_id = device_id
        self.software_version = software_version
        self.retract_steps = retract_steps
        self.retract_mm = retract_mm
        self.speed = speed
        self.acceleration = acceleration
        self.run_current = run_current
        self.chopper_mode = chopper_mode
        self.git_commit = git_commit                   # "": firmware before the Git Commit line
        self.dtr = dtr
        self.fault = fault
        self.chunk_size = chunk_size
        self.stray_prompt_after_move = stray_prompt_after_move
        self._stray_pending = False                    # a stray prompt goes out with the next write
        self._deferring = False                        # output held back until the stray has been read
        self._delayed = b""
        self.calibrated = False
        self.enabled = False                           # firmware StepperStatus flag
        self.written = []                              # every line the host wrote, in order
        self._out = b""
        self._in = b""
        self._awaiting = ""                            # command whose value line comes next: a, f or g

    # --- pyserial interface ---------------------------------------------------------

    @property
    def in_waiting(self):
        if not self._out and self._deferring:
            self._out, self._delayed, self._deferring = self._delayed, b"", False
        return len(self._out)

    def write(self, data):
        self._in += data
        while b"\n" in self._in:
            line, self._in = self._in.split(b"\n", 1)
            self._handle(line.decode().rstrip("\r"))
        return len(data)

    def read(self, size=1):
        n = min(size, len(self._out))
        if self.chunk_size:
            n = min(n, self.chunk_size)
        data, self._out = self._out[:n], self._out[n:]
        return data

    def reset_input_buffer(self):
        self._out = b""

    def close(self):
        pass

    def queue_unsolicited(self, text):
        """Output the firmware sends on its own, e.g. a driver-fault message."""
        self._emit(text)

    # --- simulated firmware -----------------------------------------------------------

    def _emit(self, text):
        if self._deferring:
            self._delayed += text.encode("utf-8")
        else:
            self._out += text.encode("utf-8")

    def _handle(self, line):
        self.written.append(line)
        if self._stray_pending:
            self._stray_pending = False
            self._out += PROMPT.encode()
            self._deferring = True
        if self.fault == "silent":
            return
        if self._awaiting:
            cmd, self._awaiting = self._awaiting, ""
            if cmd == "a":
                self._finish_move(float(line))
            else:
                self._finish_setting(cmd, line)
            return
        if line == "c":
            self._calibrate()
        elif line == "e":
            self.enabled = True
            self._emit("\nStepper enabled in normal mode\n\r\n" + PROMPT)
        elif line == "d":
            self.enabled = False
            self.calibrated = False
            self._emit("\nStepper disabled. Position tracking is no longer trustworthy - "
                       "recalibrate ('c') before moving.\n\r\n" + PROMPT)
        elif line == "s":
            self._status()
        elif line == "t":
            self._toggle_chopper()
        elif line == "a":
            self._emit("\nEnter absolute target position (steps):\r\n")
            self._awaiting = "a"
        elif line == "f":
            self._emit(f"\nCurrent speed is {self.speed}. Enter new max speed: \n")
            self._awaiting = "f"
        elif line == "g":
            self._emit(f"\nCurrent acceleration is {self.acceleration}. Enter new acceleration: \n")
            self._awaiting = "g"

    def _connection_lost(self):
        return ("\nSerial connection lost - stepper disabled. Reconnect and use 'e' "
                "to re-enable (recalibrate 'c' before moving).\r\n")

    def _calibrate(self):
        self.calibrated = False
        out = "\nStarting calibration...\r\n"
        if not self.dtr:
            out += self._connection_lost() + "ERROR: Min endstop not found - calibration aborted.\r\n"
            self.enabled = False
        elif self.fault == "calibrateMinMissing":
            out += "ERROR: Min endstop not found - calibration aborted.\r\n"
        else:
            out += "Min Endstop found. Position set to 0.\r\n"
            out += f"Max Endstop found. Max Position: {self.max_position}"
            if self.saved_max_position >= 0:
                out += (f" (previous saved: {self.saved_max_position}, "
                        f"diff: {self.max_position - self.saved_max_position:+d})")
            else:
                out += " (no previous saved value to compare)"
            out += "\r\n"
            out += (f"First-contact position (retract {self.retract_mm:.3f} mm): "
                    f"{self.max_position - self.retract_steps}\n")
            out += "\r\n"
            self.saved_max_position = self.max_position
            self.position = self.max_position
            self.calibrated = True
        self._emit(out + PROMPT)

    def _finish_setting(self, cmd, line):
        # cmd9_Speed / cmd10_Acceleration: parseInt, accepted only if > 0.
        try:
            value = int(line)
        except ValueError:
            value = 0
        out = ""
        if self.fault != "settingIgnored" and value > 0:
            if cmd == "f":
                self.speed = value
                out = f"Speed set to {value}\n\n"
            else:
                self.acceleration = value
                out = f"Acceleration set to {value}\n\n"
        self._emit(out + PROMPT)

    def _toggle_chopper(self):
        out = ""
        if self.fault == "uartDown":
            out = "WARNING: TMC2209 UART link is down - this setting may not have reached the driver\r\n"
        if self.chopper_mode == "SpreadCycle":
            self.chopper_mode = "StealthChop"
            out += "\nChopper mode set to StealthChop (near-silent, reduced high-speed torque)\n\r\n"
        else:
            self.chopper_mode = "SpreadCycle"
            out += "\nChopper mode set to SpreadCycle (louder, full torque/speed headroom)\n\r\n"
        self._emit(out + PROMPT)

    def _finish_move(self, target):
        warn = f"WARNING: Unexpected MAX endstop hit! Position auto-corrected to {self.max_position}.\n"
        resume = "Resuming toward original target...\r\n"
        if not self.calibrated:
            out = "Error: Must calibrate ('c') before moving.\r\n"
        elif not 0 <= target <= self.max_position:
            out = "Error: Target out of calibrated bounds!\r\n"
        else:
            out = f"Moving to absolute position: {int(target)}\n"
            if not self.dtr:
                # MoveAbsWithEndstopGuard returns early when CheckSerialConnection fails.
                self.enabled = False
                self.calibrated = False
                self._emit(out + self._connection_lost() + PROMPT)
                return
            if self.fault == "moveWarning":
                out += warn + resume + "Move complete.\r\n"
                self.position = int(target)
            elif self.fault == "moveSafetyDisable":
                out += (warn + resume + warn + resume + warn
                        + "ERROR: Repeated unexpected endstop hits - stepper disabled. "
                          "Investigate before re-enabling (e).\r\n")
                self.enabled = False
            else:
                out += "Move complete.\r\n"
                self.position = int(target)
        self._emit(out + PROMPT)
        self._stray_pending = self.stray_prompt_after_move

    def _status(self):
        yn = ("NO", "YES")
        out = ("\n--- SYSTEM STATUS ---\r\n"
               f"Software Version: {self.software_version}\n")
        if self.git_commit:
            out += f"Git Commit:       {self.git_commit}\n"
        out += (f"Device ID:        {self.device_id}\n"
               f"Stepper Enabled:  {yn[self.enabled]}\n"
               f"Current Position: {self.position} steps\n")
        if self.calibrated:
            out += f"Max Range Limit:  {self.max_position} steps\n"
        else:
            out += f"Max Range Limit:  {self.max_position} steps (stale - not calibrated)\n"
        out += (f"Calibrated:       {yn[self.calibrated]}\n"
                f"Retract Distance: {self.retract_steps} steps ({self.retract_mm:.3f} mm)\n")
        if self.calibrated:
            out += f"First-Contact:    {self.max_position - self.retract_steps} steps\n"
        else:
            out += "First-Contact:    unavailable (not calibrated)\r\n"
        out += (f"Current Speed:    {self.speed} steps/s\n"
                f"Acceleration:     {self.acceleration} steps/s²\n"
                f"Run Current:      {self.run_current} mA\n"
                "Hold Current:     50%\n"
                "Microsteps:       16\n"
                f"Chopper Mode:     {self.chopper_mode}\n"
                "---\r\n\r\n")
        self._emit(out + PROMPT)
