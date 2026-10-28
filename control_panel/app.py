"""Tkinter GUI entry point for the RRST device control panel."""

import csv
import math
import queue
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from firmware_flasher import FirmwareFlasher
from serial_link import SerialLink, DISCONNECTED_SENTINEL, list_ports, list_teensy_ports
from status_parser import parse_status_block
from sweep import SweepTest, DEFAULT_TOLERANCE_STEPS, SWEEP_TEST_MARGIN_STEPS, recommended_value, best_combo_per_mode
from tooltip import Tooltip

# Updated by hand whenever RRST_Control_Panel/firmware/RRST_Teensy_4_version_TMC2209.hex
# is refreshed - see the design spec's Maintainer workflow section. Not
# derived automatically: the codename is only knowable by actually
# running the firmware and asking it (its 's' status output), not by
# inspecting the compiled .hex.
BUNDLED_FIRMWARE_VERSION = "Patient-Regulator (Oct  7 2026 08:45:06)"

STATUS_START_MARKER = "--- SYSTEM STATUS ---"
STATUS_END_MARKER = "---"

STATUS_FIELDS = [
    ("Software Version", "Firmware Version", "The connected device's firmware build identifier (an adjective-noun codename) and build timestamp. Useful for confirming which build is actually running, e.g. after a flash."),
    ("Stepper Enabled", "Enabled", "Whether the stepper driver output stage is currently energized (sends holding torque and responds to moves). Disabled by 'd', a driver fault, a lost serial connection, or repeated unexpected endstop hits."),
    ("Current Position", "Position", "The stepper's currently tracked position in steps. Not trustworthy until calibrated."),
    ("Max Range Limit", "Max Range", "The calibrated maximum position in steps - the far endstop's location, found during the last successful calibration this session."),
    ("Calibrated", "Calibrated", "Whether the device has been successfully calibrated since it was last enabled. A stepper has no absolute position feedback, so this resets any time the driver is disabled."),
    ("Saved Max Pos", "Saved Max Pos", "The max position from the last calibration saved to EEPROM, for comparing against the current one - useful for spotting mechanical drift (a loosening coupler, worn lead screw) over time."),
    ("Retract Distance", "Retract Distance", "How far back from the max endstop calibration's reported 'First-contact position' safety target sits."),
    ("First-Contact", "First-Contact", "The position the Retract button (and calibration) targets - the max endstop position minus the configured retract distance. This is where the device rests a step short of the hard mechanical limit, rather than sitting against it. Unavailable until calibrated."),
    ("Current Speed", "Speed", "Currently active maximum speed, steps/s."),
    ("Acceleration", "Acceleration", "Currently active acceleration, steps/s²."),
    ("Run Current", "Run Current", "Currently active RMS run current, mA."),
    ("Hold Current", "Hold Current", "Currently active hold current, as a percentage of run current."),
    ("Microsteps", "Microsteps", "Currently active microstepping resolution."),
    ("Chopper Mode", "Chopper Mode", "Currently active chopper mode - SpreadCycle (louder, full torque) or StealthChop (near-silent, reduced high-speed torque)."),
    ("Fan Mode", "Fan Mode", "Current fan mode - Auto (temperature-based), Forced ON, or Forced OFF."),
    ("Fan State", "Fan State", "Whether the cooling fan is currently running."),
    ("Min Endstop", "Min Endstop", "Live read of the min endstop switch. Should read 'ok' when idle - 'TRIGGERED' means the switch is closed, which also happens if its wire comes loose (these switches fail safe)."),
    ("Max Endstop", "Max Endstop", "Live read of the max endstop switch. Should read 'ok' when idle - 'TRIGGERED' means the switch is closed, which also happens if its wire comes loose (these switches fail safe)."),
    ("Soft Limit Guard", "Soft Limit Guard", "The software layer, separate from the physical switches above - every absolute move ('a') is refused before it's ever issued if the target falls outside the calibrated [0, Max Range] bounds. Only active once calibrated."),
    ("Total Run Time", "Total Run Time", "Cumulative time the motor has been enabled (energized), across the device's whole life. Persists across power cycles."),
    ("Session Run Time", "Session Run Time", "Motor-enabled time since this device was last powered on. Resets to 0 every boot."),
    ("Total Distance", "Total Distance", "Cumulative lead-screw travel across the device's whole life, in meters - a proxy for mechanical wear (e.g. when to regrease the shaft)."),
    ("Total Min Hits", "Total Min Hits", "Cumulative physical actuations of the min endstop switch, across the device's whole life - counted at every physical contact, both during calibration/verification (fast-approach and slow-precise-reapproach count separately) and during normal guarded moves that land on this switch. A proxy for switch mechanical wear."),
    ("Total Max Hits", "Total Max Hits", "Cumulative physical actuations of the max endstop switch, across the device's whole life - counted at every physical contact, both during calibration/verification (fast-approach and slow-precise-reapproach count separately) and during normal guarded moves that land on this switch. A proxy for switch mechanical wear."),
    ("Heat Sink Temp", "Heat Sink Temp", "Driver heat-sink temperature from an optional DS18B20 sensor on pin 4. Unavailable if no sensor is installed - detected automatically once at boot, no configuration needed."),
    ("Device ID", "Device ID", "The Teensy's factory-programmed 64-bit unique hardware ID - fixed for the life of the chip, lets you tell physical devices apart (e.g. when more than one is connected) independent of USB port names or firmware version."),
    ("Peak Heat Sink Temp", "Peak Heat Sink Temp", "The highest heat-sink temperature ever recorded on this device, across its whole life. Persists across power cycles; reset only by 'z' (Reset to Defaults). Shows 'never recorded' on a device with no DS18B20 sensor installed."),
]

MICROSTEP_OPTIONS = ["0", "2", "4", "8", "16", "32", "64", "128", "256"]

AUTO_REFRESH_MS = 1500
QUEUE_POLL_MS = 100


class ControlPanelApp:
    def __init__(self, root):
        self.root = root
        self.root.title("RRST Device Control Panel")

        self.link = SerialLink()
        self._collecting_status = False
        self._status_lines = []
        self._suppress_next_echo = False
        self._action_widgets = []
        self._sweep_rows = {}
        self._sweep_results = []
        self._live_max_range = None
        self._live_microsteps = None
        self._live_calibrated = False
        self.sweep = SweepTest(
            write_line=self.link.write_line,
            on_combo_done=self._on_sweep_combo_done,
            on_finished=self._on_sweep_finished,
            on_progress=self._on_sweep_progress,
            on_step_result=self._on_sweep_step_result,
        )

        self._build_widgets()
        self._refresh_ports()
        self._set_connected_state(False)

        self.root.after(QUEUE_POLL_MS, self._poll_queue)

    # ---- widget construction ----

    def _build_widgets(self):
        self._build_connection_bar()

        outer = ttk.Frame(self.root)
        outer.pack(fill="both", expand=True, padx=8, pady=8)

        # Everything except the log lives in this column, so the log's own
        # column (below) can span the full window height independently of
        # however tall the controls/status/sweep-test stack ends up being.
        main = ttk.Frame(outer)
        main.pack(side="left", fill="both", expand=True, padx=(0, 8))

        top_row = ttk.Frame(main)
        top_row.pack(fill="both", expand=True)

        controls = ttk.Frame(top_row)
        controls.pack(side="left", fill="y", padx=(0, 8))
        self._build_motor_control(controls)
        self._build_tuning(controls)
        self._build_modes_diagnostics(controls)

        status_col = ttk.Frame(top_row)
        status_col.pack(side="left", fill="both", expand=True)
        self._build_status_panel(status_col)

        self._build_sweep_test(main)

        log_column = ttk.Frame(outer)
        log_column.pack(side="left", fill="y")
        self._build_log_pane(log_column)

    def _build_connection_bar(self):
        bar = ttk.Frame(self.root)
        bar.pack(fill="x", padx=8, pady=8)

        ttk.Label(bar, text="Port:").pack(side="left")
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(bar, textvariable=self.port_var, width=30, state="readonly")
        self.port_combo.pack(side="left", padx=4)
        Tooltip(self.port_combo, "Serial port the device is connected on. Click Refresh Ports if it's not listed.")

        refresh_button = ttk.Button(bar, text="Refresh Ports", command=self._refresh_ports)
        refresh_button.pack(side="left", padx=4)
        Tooltip(refresh_button, "Re-scans available serial ports.")

        self.connect_button = ttk.Button(bar, text="Connect", command=self._on_connect_clicked)
        self.connect_button.pack(side="left", padx=4)
        Tooltip(self.connect_button, "Opens or closes the serial connection to the device.")

        self.flash_button = ttk.Button(bar, text="Flash Firmware", command=self._on_flash_firmware_clicked)
        self.flash_button.pack(side="left", padx=(16, 4))
        Tooltip(
            self.flash_button,
            f"Flashes the bundled firmware ({BUNDLED_FIRMWARE_VERSION}) onto a connected "
            "Teensy 4.0. Disconnects first if currently connected. Refuses to proceed if "
            "more than one Teensy is connected, since there's no way to target a specific one. "
            "On macOS you'll need to press the small button on the Teensy board when prompted - "
            "automatic reboot into programming mode isn't supported on this platform.",
        )
        ttk.Label(bar, text=f"(bundled: {BUNDLED_FIRMWARE_VERSION})", foreground="#666666").pack(side="left", padx=(0, 4))

        self.status_dot = ttk.Label(bar, text="● Disconnected", foreground="red")
        self.status_dot.pack(side="left", padx=8)

    def _build_motor_control(self, parent):
        frame = ttk.LabelFrame(parent, text="Motor Control")
        frame.pack(fill="x", pady=(0, 8))

        row1 = ttk.Frame(frame)
        row1.pack(fill="x", pady=2)
        self._add_action_button(row1, "Enable", lambda: self.link.write_line("e"),
            "Enables the stepper driver output stage (sends 'e'). The motor will hold position and respond to moves.")
        self._add_action_button(row1, "Disable", lambda: self.link.write_line("d"),
            "Disables the stepper driver output stage (sends 'd'). Removes holding torque - the mechanism can be moved by hand, so calibration is no longer trusted afterward.")

        row2 = ttk.Frame(frame)
        row2.pack(fill="x", pady=2)
        self._add_action_button(row2, "Calibrate", lambda: self.link.write_line("c"),
            "Homes to the min endstop, then finds the max endstop (sends 'c'). Required before any absolute move. Reports the calibrated range and compares it to the last saved calibration.")
        self._add_action_button(row2, "Home", lambda: self.link.write_line("h"),
            "Moves to position 0 (sends 'h'). Requires calibration first.")
        self._add_action_button(row2, "Retract", self._on_retract_clicked,
            "Moves to the calibrated First-Contact position (sends 'y'). A step short of the hard max endstop, intended as the resting position between trials. Requires calibration first.")

        row3 = ttk.Frame(frame)
        row3.pack(fill="x", pady=2)
        self._add_action_button(row3, "Safe Mode", lambda: self.link.write_line("o"),
            "Verifies soft limits are active (sends 'o').")

        self._add_value_row(frame, "Move to (steps):", "a",
            "Target absolute position in steps.",
            "Moves to an absolute step position within the calibrated range (sends 'a'). Requires calibration first.")

    def _build_tuning(self, parent):
        frame = ttk.LabelFrame(parent, text="Tuning")
        frame.pack(fill="x", pady=(0, 8))

        self._add_value_row(frame, "Speed (steps/s):", "f",
            "Maximum stepper speed in steps/second.",
            "Sets the maximum stepper speed (sends 'f').")
        self._add_value_row(frame, "Acceleration (steps/s²):", "g",
            "Stepper acceleration/deceleration rate in steps/second².",
            "Sets the stepper acceleration (sends 'g').")
        self._add_value_row(frame, "Run Current (mA):", "i",
            "TMC2209 RMS run current in mA, 1-2000.",
            "Sets the run current (sends 'i'). The driver quantizes this to its nearest supported current step, so the confirmed value may differ slightly from what you enter.")
        self._add_microsteps_row(frame,
            "TMC2209 microstepping resolution. 0 means full-step (1x).",
            "Sets the microstepping resolution (sends 'u').")
        self._add_value_row(frame, "Hold Current (%):", "p",
            "Holding current as a percentage of run current, 0-100.",
            "Sets the hold current percentage (sends 'p'). Applied automatically whenever the stepper is enabled but not moving.")
        self.retract_distance_var, retract_row = self._add_value_row(frame, "Retract Distance (steps):", "r",
            "Distance back from the max endstop, in steps, used to compute calibration's 'First-contact position' safety target. Must be > 0.",
            "Sets the retract distance (sends 'r').")
        self.retract_distance_mm_label = ttk.Label(retract_row, text="")
        self.retract_distance_mm_label.pack(side="left", padx=4)
        Tooltip(
            self.retract_distance_mm_label,
            "The entered step count converted to mm at the device's currently reported microstepping - steps alone don't tell you the physical distance without knowing that.",
        )
        self.retract_distance_var.trace_add("write", self._update_retract_mm_label)
        self._update_retract_mm_label()

        save_row = ttk.Frame(frame)
        save_row.pack(fill="x", pady=2)
        self._add_action_button(save_row, "Save Settings", lambda: self.link.write_line("v"),
            "Saves run current, hold %, speed, acceleration, microsteps, chopper mode, and retract distance to the device's EEPROM (sends 'v') - they'll reload automatically on the next power-up.")
        self._add_action_button(save_row, "Reset to Defaults", self._on_reset_defaults_clicked,
            "Clears the endstop log and resets run current, hold %, speed, acceleration, microsteps, chopper mode, and retract distance to their compiled-in defaults (sends 'z'). Also resets the lifetime Peak Heat Sink Temp to 'never recorded'. Also overwrites the device's saved EEPROM settings, so this survives a power cycle. Does not affect calibration or Saved Max Pos.")

    def _build_modes_diagnostics(self, parent):
        frame = ttk.LabelFrame(parent, text="Modes / Diagnostics")
        frame.pack(fill="x", pady=(0, 8))

        row1 = ttk.Frame(frame)
        row1.pack(fill="x", pady=2)
        self._add_action_button(row1, "Toggle Chopper Mode", lambda: self.link.write_line("t"),
            "Switches between SpreadCycle (louder, full torque/speed headroom) and StealthChop (near-silent, reduced high-speed torque) (sends 't').")
        self._add_action_button(row1, "Toggle Fan Mode", lambda: self.link.write_line("w"),
            "Cycles the cooling fan between Auto (temperature-based), Forced ON, and Forced OFF (sends 'w').")

        row2 = ttk.Frame(frame)
        row2.pack(fill="x", pady=2)
        self._add_action_button(row2, "Driver Diagnostics", lambda: self.link.write_line("x"),
            "Reads the TMC2209's latched fault flags - overtemperature, short-to-ground, short-to-supply (sends 'x'). Flags stay latched until the driver is disabled and re-enabled.")
        self._add_action_button(row2, "Endstop Log", lambda: self.link.write_line("l"),
            "Shows how many times each endstop was hit unexpectedly during a move, and when (sends 'l').")
        self._add_action_button(row2, "Menu", lambda: self.link.write_line("m"),
            "Prints the device's own command menu to the raw log (sends 'm').")

    def _build_status_panel(self, parent):
        frame = ttk.LabelFrame(parent, text="Live Status (auto-refresh)")
        frame.pack(fill="both", expand=True)

        # Split into two side-by-side sub-columns instead of one tall list -
        # with STATUS_FIELDS having grown to dozens of rows over several
        # features, a single column made this panel (and therefore the
        # whole window) the tallest thing on screen. Left sub-column gets
        # the first half, right sub-column the second half - this stays
        # balanced automatically if more fields are added later.
        half = (len(STATUS_FIELDS) + 1) // 2
        self.status_value_labels = {}
        for index, (_, display_name, tooltip_text) in enumerate(STATUS_FIELDS):
            if index < half:
                row, name_col, value_col, name_padx = index, 0, 1, 4
            else:
                row, name_col, value_col, name_padx = index - half, 2, 3, (16, 4)
            name_label = ttk.Label(frame, text=display_name + ":")
            name_label.grid(row=row, column=name_col, sticky="w", padx=name_padx, pady=2)
            Tooltip(name_label, tooltip_text)
            value_label = ttk.Label(frame, text="--")
            value_label.grid(row=row, column=value_col, sticky="w", padx=4, pady=2)
            self.status_value_labels[display_name] = value_label

        # Not live device data - the safety-margined recommendation from the
        # last completed sweep test (see _update_sweep_verdict), kept here
        # too so it's visible without scrolling to the Sweep Test panel.
        # A wrapped block of text doesn't split well into a half-width
        # column, so this spans both sub-columns, below whichever is
        # taller (the left one, since it always gets the larger half).
        safe_limits_row = half
        safe_limits_name_label = ttk.Label(frame, text="Safe Limits:")
        safe_limits_name_label.grid(row=safe_limits_row, column=0, sticky="nw", padx=4, pady=2)
        Tooltip(
            safe_limits_name_label,
            "The safety-margined speed/acceleration recommendation from the last completed sweep test, per "
            "chopper mode - not live device data. Stays here until a new sweep actually finishes; an aborted "
            "or empty run doesn't clear it.",
        )
        self.safe_limits_value_label = ttk.Label(frame, text="(no sweep run yet)", justify="left", wraplength=650)
        self.safe_limits_value_label.grid(row=safe_limits_row, column=1, columnspan=3, sticky="w", padx=4, pady=2)

    def _build_sweep_test(self, parent):
        frame = ttk.LabelFrame(parent, text="Sweep Test (find max reliable speed/acceleration)")
        frame.pack(fill="x", padx=8, pady=(0, 8))

        inputs = ttk.Frame(frame)
        inputs.pack(fill="x", pady=2)

        ttk.Label(inputs, text="Currents (mA, comma-separated):").grid(row=0, column=0, sticky="w", padx=4, pady=2)
        self.sweep_currents_var = tk.StringVar(value="600,800,1000")
        entry = ttk.Entry(inputs, textvariable=self.sweep_currents_var, width=30)
        entry.grid(row=0, column=1, columnspan=3, sticky="w", padx=4, pady=2)
        self._action_widgets.append(entry)
        Tooltip(entry, "Comma-separated list of run currents (mA) to test, e.g. 600,800,1000. The sweep runs for every current x selected chopper mode.")

        self.sweep_spread_var = tk.BooleanVar(value=True)
        self.sweep_stealth_var = tk.BooleanVar(value=True)
        spread_check = ttk.Checkbutton(inputs, text="SpreadCycle", variable=self.sweep_spread_var)
        spread_check.grid(row=1, column=0, sticky="w", padx=4, pady=2)
        Tooltip(spread_check, "Include SpreadCycle in the sweep matrix. At least one chopper mode must be checked.")
        stealth_check = ttk.Checkbutton(inputs, text="StealthChop", variable=self.sweep_stealth_var)
        stealth_check.grid(row=1, column=1, sticky="w", padx=4, pady=2)
        Tooltip(stealth_check, "Include StealthChop in the sweep matrix. At least one chopper mode must be checked.")
        self._action_widgets.extend([spread_check, stealth_check])

        ttk.Label(inputs, text="Speed sweep - start/end/step (steps/s):").grid(row=2, column=0, sticky="w", padx=4, pady=2)
        self.sweep_speed_start_var = tk.StringVar(value="5000")
        self.sweep_speed_end_var = tk.StringVar(value="20000")
        self.sweep_speed_step_var = tk.StringVar(value="5000")
        speed_field_tooltips = (
            "First speed (steps/s) tested in the sweep.",
            "Speed (steps/s) the sweep won't go past, even if every step keeps passing.",
            "How much to increase speed (steps/s) after each passing step.",
        )
        for col, (var, tip) in enumerate(zip(
            (self.sweep_speed_start_var, self.sweep_speed_end_var, self.sweep_speed_step_var),
            speed_field_tooltips,
        )):
            e = ttk.Entry(inputs, textvariable=var, width=8)
            e.grid(row=2, column=1 + col, sticky="w", padx=4, pady=2)
            self._action_widgets.append(e)
            Tooltip(e, tip)

        ttk.Label(inputs, text="Fixed acceleration during speed sweep:").grid(row=3, column=0, sticky="w", padx=4, pady=2)
        self.sweep_speed_fixed_accel_var = tk.StringVar(value="10000")
        e = ttk.Entry(inputs, textvariable=self.sweep_speed_fixed_accel_var, width=8)
        e.grid(row=3, column=1, sticky="w", padx=4, pady=2)
        self._action_widgets.append(e)
        Tooltip(e, "Acceleration (steps/s²) held constant while speed is being swept.")
        self.sweep_required_accel_label = ttk.Label(inputs, text="")
        self.sweep_required_accel_label.grid(row=3, column=2, columnspan=2, sticky="w", padx=4, pady=2)
        Tooltip(
            self.sweep_required_accel_label,
            "The test move only has so much travel to work with (the calibrated range, minus a small margin at "
            "each end). A candidate speed can't actually be reached unless this acceleration is high enough to "
            "get there within that distance - below it, the sweep stops early since higher candidates would be "
            "physically identical to whatever peak speed the travel already allows.",
        )
        self.sweep_speed_end_var.trace_add("write", self._update_required_accel_label)

        ttk.Label(inputs, text="Accel sweep - start/end/step (steps/s²):").grid(row=4, column=0, sticky="w", padx=4, pady=2)
        self.sweep_accel_start_var = tk.StringVar(value="5000")
        self.sweep_accel_end_var = tk.StringVar(value="60000")
        self.sweep_accel_step_var = tk.StringVar(value="5000")
        accel_field_tooltips = (
            "First acceleration (steps/s²) tested in the sweep.",
            "Acceleration (steps/s²) the sweep won't go past, even if every step keeps passing.",
            "How much to increase acceleration (steps/s²) after each passing step.",
        )
        for col, (var, tip) in enumerate(zip(
            (self.sweep_accel_start_var, self.sweep_accel_end_var, self.sweep_accel_step_var),
            accel_field_tooltips,
        )):
            e = ttk.Entry(inputs, textvariable=var, width=8)
            e.grid(row=4, column=1 + col, sticky="w", padx=4, pady=2)
            self._action_widgets.append(e)
            Tooltip(e, tip)

        ttk.Label(inputs, text="Fixed speed during acceleration sweep:").grid(row=5, column=0, sticky="w", padx=4, pady=2)
        self.sweep_accel_fixed_speed_var = tk.StringVar(value="20000")
        e = ttk.Entry(inputs, textvariable=self.sweep_accel_fixed_speed_var, width=8)
        e.grid(row=5, column=1, sticky="w", padx=4, pady=2)
        self._action_widgets.append(e)
        Tooltip(e, "Speed (steps/s) held constant while acceleration is being swept.")

        ttk.Label(inputs, text="Repeatability tolerance (steps):").grid(row=6, column=0, sticky="w", padx=4, pady=2)
        self.sweep_tolerance_var = tk.StringVar(value=str(DEFAULT_TOLERANCE_STEPS))
        e = ttk.Entry(inputs, textvariable=self.sweep_tolerance_var, width=8)
        e.grid(row=6, column=1, sticky="w", padx=4, pady=2)
        self._action_widgets.append(e)
        Tooltip(e, "Max allowed difference (steps) between two repeated calibrations at the same setting to still count as reliable.")

        button_row = ttk.Frame(frame)
        button_row.pack(fill="x", pady=4)
        self.sweep_run_button = ttk.Button(button_row, text="Run Sweep", command=self._on_sweep_run_clicked)
        self.sweep_run_button.pack(side="left", padx=2)
        self._action_widgets.append(self.sweep_run_button)
        Tooltip(self.sweep_run_button, "Starts the sweep: for each current x mode, runs one baseline calibration, then increments speed (then acceleration), test-moving and re-verifying calibration at each step until one fails or the available travel is exhausted.")
        self.sweep_abort_button = ttk.Button(button_row, text="Abort", command=self._on_sweep_abort_clicked, state="disabled")
        self.sweep_abort_button.pack(side="left", padx=2)
        self._action_widgets.append(self.sweep_abort_button)
        Tooltip(self.sweep_abort_button, "Stops the sweep immediately, mid-step.")
        self.sweep_export_button = ttk.Button(button_row, text="Export CSV", command=self._on_sweep_export_clicked, state="disabled")
        self.sweep_export_button.pack(side="left", padx=2)
        Tooltip(self.sweep_export_button, "Saves the results table to a CSV file. Enabled once the sweep has produced at least one result.")

        self.sweep_progress_label = ttk.Label(frame, text="", font=("TkDefaultFont", 10, "bold"))
        self.sweep_progress_label.pack(fill="x", pady=(0, 4))
        Tooltip(
            self.sweep_progress_label,
            "What the sweep is testing right now, and how far through the planned matrix it is. The total is "
            "the full configured range - a combo that fails or hits its reachable-speed ceiling partway "
            "through stops that axis early, so real progress can run ahead of this estimate near the end.",
        )

        caveat_label = ttk.Label(
            frame,
            text="Note: speed and acceleration are swept independently (each holding the other fixed) - "
                 "the two reported values have not been tested together. Confirm with a real run at your "
                 "chosen combination before relying on it.",
            wraplength=760, justify="left", foreground="#8a6400",
        )
        caveat_label.pack(fill="x", pady=(0, 4))

        columns = ("current", "mode", "speed_limit", "speed_rec", "accel_limit", "accel_rec", "notes")
        headings = ("Current (mA)", "Mode", "Speed Limit", "Recommended Speed", "Accel Limit", "Recommended Accel", "Notes")
        widths = (70, 85, 100, 130, 105, 135, 220)
        self.sweep_tree = ttk.Treeview(frame, columns=columns, show="headings", height=6)
        for col, heading, width in zip(columns, headings, widths):
            self.sweep_tree.heading(col, text=heading)
            self.sweep_tree.column(col, width=width, anchor="w")
        self.sweep_tree.pack(fill="x", pady=(4, 2))
        Tooltip(
            self.sweep_tree,
            "Limit columns are the last value that passed - one step from where it actually broke. "
            "Recommended columns apply a safety margin below a real found limit (blank margin when the "
            "sweep simply reached its configured range without ever failing, since that isn't a true edge).",
        )

        self.sweep_verdict_label = ttk.Label(frame, text="", justify="left", wraplength=760)
        self.sweep_verdict_label.pack(fill="x", pady=(4, 0))
        Tooltip(
            self.sweep_verdict_label,
            "The best combo per chopper mode tested, ranked by: not having run warm during testing first "
            "(reliability under sustained real use beats a marginally bigger number), then by recommended "
            "speed x recommended accel, then by lower current on ties.",
        )

        self._update_required_accel_label()

    def _build_log_pane(self, parent):
        frame = ttk.LabelFrame(parent, text="Raw device log")
        frame.pack(fill="both", expand=True)

        self.log_text = tk.Text(frame, height=10, state="disabled")
        self.log_text.pack(fill="both", expand=True, side="left")

        scrollbar = ttk.Scrollbar(frame, command=self.log_text.yview)
        scrollbar.pack(side="right", fill="y")
        self.log_text.configure(yscrollcommand=scrollbar.set)

    # ---- widget helpers ----

    def _add_action_button(self, parent, label, command, tooltip):
        button = ttk.Button(parent, text=label, command=command)
        button.pack(side="left", padx=2)
        self._action_widgets.append(button)
        Tooltip(button, tooltip)
        return button

    def _add_value_row(self, parent, label, command_char, field_tooltip, button_tooltip):
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=2)
        ttk.Label(row, text=label, width=20).pack(side="left")
        var = tk.StringVar()
        entry = ttk.Entry(row, textvariable=var, width=10)
        entry.pack(side="left", padx=4)
        self._action_widgets.append(entry)
        Tooltip(entry, field_tooltip)

        def on_set():
            value = var.get().strip()
            if value:
                self.link.write_line(command_char)
                self.link.write_line(value)

        button = ttk.Button(row, text="Set", command=on_set)
        button.pack(side="left", padx=4)
        self._action_widgets.append(button)
        Tooltip(button, button_tooltip)
        return var, row

    def _add_microsteps_row(self, parent, field_tooltip, button_tooltip):
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=2)
        ttk.Label(row, text="Microsteps:", width=20).pack(side="left")
        var = tk.StringVar(value=MICROSTEP_OPTIONS[4])
        combo = ttk.Combobox(row, textvariable=var, values=MICROSTEP_OPTIONS, width=8, state="readonly")
        combo.pack(side="left", padx=4)
        self._action_widgets.append(combo)
        Tooltip(combo, field_tooltip)

        def on_set():
            self.link.write_line("u")
            self.link.write_line(var.get())

        button = ttk.Button(row, text="Set", command=on_set)
        button.pack(side="left", padx=4)
        self._action_widgets.append(button)
        Tooltip(button, button_tooltip)

    # ---- connection handling ----

    def _refresh_ports(self):
        ports = list_ports()
        self.port_combo["values"] = ports
        if ports and not self.port_var.get():
            self.port_var.set(ports[0])

    def _on_connect_clicked(self):
        if self.link.is_connected():
            self.link.disconnect()
            self._set_connected_state(False)
            return

        port = self.port_var.get()
        if not port:
            return
        try:
            self.link.connect(port)
        except Exception as exc:
            self._append_log(f"ERROR: could not open {port}: {exc}")
            return
        self._set_connected_state(True)

    def _set_connected_state(self, connected):
        for widget in self._action_widgets:
            if isinstance(widget, ttk.Combobox):
                widget.configure(state="readonly" if connected else "disabled")
            else:
                widget.configure(state="normal" if connected else "disabled")

        self.connect_button.configure(text="Disconnect" if connected else "Connect")
        self.port_combo.configure(state="disabled" if connected else "readonly")

        if connected:
            self.status_dot.configure(text="● Connected", foreground="green")
            self._set_sweep_running_state(False)
            self._schedule_auto_refresh()
        else:
            self.status_dot.configure(text="● Disconnected", foreground="red")
            self._collecting_status = False
            self._status_lines = []
            for _, display_name, _tooltip in STATUS_FIELDS:
                self.status_value_labels[display_name].configure(text="--")
            self.sweep_export_button.configure(state="disabled")

    def _set_sweep_running_state(self, running):
        for widget in self._action_widgets:
            if widget is self.sweep_abort_button:
                continue
            if isinstance(widget, ttk.Combobox):
                widget.configure(state="disabled" if running else "readonly")
            else:
                widget.configure(state="disabled" if running else "normal")
        self.sweep_abort_button.configure(state="normal" if running else "disabled")

    # ---- firmware flashing ----

    def _on_flash_firmware_clicked(self):
        if self.sweep.is_running():
            messagebox.showerror(
                "Sweep in progress",
                "Wait for the current sweep test to finish (or click Abort) before flashing firmware - "
                "both use the serial connection.",
            )
            return
        teensy_ports = list_teensy_ports()
        if len(teensy_ports) > 1:
            messagebox.showerror(
                "Multiple devices found",
                "More than one Teensy is connected (" + ", ".join(teensy_ports) + "). "
                "teensy_loader_cli can't target a specific one - disconnect all but the "
                "device you want to flash, then try again.",
            )
            return
        if len(teensy_ports) == 0:
            messagebox.showerror("No device found", "No Teensy device was detected. Check the cable and try again.")
            return

        if self.link.is_connected():
            self.link.disconnect()
            self._set_connected_state(False)

        self.flash_button.configure(state="disabled")
        # Connect/port controls are disabled too, for the whole flash -
        # the port is exclusively teensy_loader_cli's to use until it
        # finishes; letting the user click Connect mid-flash would race
        # it for the same port.
        self.connect_button.configure(state="disabled")
        self.port_combo.configure(state="disabled")
        self._append_log("Starting firmware flash...")

        self._flash_queue = queue.Queue()
        flasher = FirmwareFlasher(
            on_line=lambda line: self._flash_queue.put(("line", line)),
            on_done=lambda code: self._flash_queue.put(("done", code)),
            # The Win32 build of teensy_loader_cli can't soft-reboot the
            # board itself (-s just prints "not implemented"), so the
            # flasher triggers the reboot over the serial port instead.
            # Other platforms keep their existing, working behavior.
            reboot_port=teensy_ports[0] if sys.platform.startswith("win") else None,
        )
        flasher.start()
        self.root.after(QUEUE_POLL_MS, self._poll_flash_queue)

    def _poll_flash_queue(self):
        try:
            while True:
                kind, payload = self._flash_queue.get_nowait()
                if kind == "line":
                    self._append_log(payload)
                    # teensy_loader_cli's own soft-reboot (-s) isn't
                    # implemented on macOS, so it silently falls through to
                    # waiting for a manual button press - its own hint for
                    # that is easy to miss buried in scrolling output, so
                    # repeat it unmissably the moment it shows up.
                    if "Waiting for Teensy device" in payload:
                        if sys.platform.startswith("win"):
                            # The flasher already requested the reboot over
                            # serial; the button is only a fallback here.
                            self._append_log(
                                "If flashing doesn't start within a few seconds, press the "
                                "small button on the Teensy board."
                            )
                        else:
                            self._append_log(
                                "ACTION NEEDED: press the small button on the Teensy board now - "
                                "automatic reboot isn't supported on macOS."
                            )
                    continue
                # kind == "done" - the only other message this queue carries
                if payload == 0:
                    self._append_log("Firmware flash completed successfully.")
                else:
                    self._append_log(f"ERROR: firmware flash failed (teensy_loader_cli exit code: {payload}).")
                self.flash_button.configure(state="normal")
                self.connect_button.configure(state="normal")
                self.port_combo.configure(state="readonly")
                return
        except queue.Empty:
            pass
        self.root.after(QUEUE_POLL_MS, self._poll_flash_queue)

    # ---- queue polling / log / status ----

    def _poll_queue(self):
        try:
            while True:
                item = self.link.incoming.get_nowait()
                if item is DISCONNECTED_SENTINEL:
                    self._append_log("Device disconnected.")
                    if self.sweep.is_running():
                        self.sweep.abort(reason="device disconnected")
                    self.link.disconnect()
                    self._set_connected_state(False)
                    continue
                self._handle_line(item)
        except queue.Empty:
            pass
        self.sweep.tick()
        self.root.after(QUEUE_POLL_MS, self._poll_queue)

    def _handle_line(self, line):
        # The firmware echoes back whatever command character it just
        # received (so a serial terminal shows what was typed) - for the
        # auto-refresh timer's 's', that echo arrives as its own line
        # right before the status block itself, one line too early for
        # the status-block suppression below to catch. _suppress_next_echo
        # is set immediately before writing 's' and consumed by exactly
        # the next line handled, so only that specific echo is dropped -
        # anything else that happens to arrive first (e.g. an unsolicited
        # fault message) is left alone and logged normally.
        if self._suppress_next_echo:
            self._suppress_next_echo = False
            if line.strip() == "s":
                return

        # Status block lines are never logged - 's' is only ever sent by
        # the 1.5s auto-refresh timer (never a manual button), so there's
        # no case where a user wants to see it in the log; logging it
        # anyway would otherwise flood the log with a ~16-line block every
        # 1.5 seconds, burying everything else.
        if line.strip() == STATUS_START_MARKER:
            self._collecting_status = True
            self._status_lines = []
            return

        if self._collecting_status:
            if line.strip() == STATUS_END_MARKER:
                self._collecting_status = False
                self._apply_status(parse_status_block(self._status_lines))
            else:
                self._status_lines.append(line)
            return

        self._append_log(line)
        self.sweep.feed_line(line)

    def _apply_status(self, parsed):
        for label, display_name, _tooltip in STATUS_FIELDS:
            if label in parsed:
                self.status_value_labels[display_name].configure(text=parsed[label])
        if "Max Range Limit" in parsed:
            try:
                self._live_max_range = int(parsed["Max Range Limit"].split()[0])
            except (ValueError, IndexError):
                self._live_max_range = None
            # Gate on the same status block's "Calibrated" field, not just
            # whether a Max Range Limit number is present - the firmware
            # still reports its last-known MaxPosition even when
            # uncalibrated (marked "stale" in its own text), which would
            # otherwise let this hint compute a misleading target from a
            # stale or compiled-in-default value.
            self._live_calibrated = parsed.get("Calibrated", "").strip() == "YES"
            self._update_required_accel_label()
        if "Microsteps" in parsed:
            try:
                self._live_microsteps = int(parsed["Microsteps"].split()[0])
            except (ValueError, IndexError):
                self._live_microsteps = None
            self._update_retract_mm_label()

    def _update_retract_mm_label(self, *_trace_args):
        try:
            steps = int(self.retract_distance_var.get())
        except (ValueError, tk.TclError):
            self.retract_distance_mm_label.configure(text="")
            return
        if not self._live_microsteps:
            self.retract_distance_mm_label.configure(text="(connect to see mm)")
            return
        steps_per_mm = 100 * self._live_microsteps
        mm = steps / steps_per_mm
        self.retract_distance_mm_label.configure(text=f"(= {mm:.3f} mm at {self._live_microsteps} microsteps)")

    def _update_required_accel_label(self, *_trace_args):
        try:
            end_speed = int(self.sweep_speed_end_var.get())
        except (ValueError, tk.TclError):
            self.sweep_required_accel_label.configure(text="")
            return
        if self._live_max_range is None or not self._live_calibrated:
            self.sweep_required_accel_label.configure(text="(connect + calibrate to compute)")
            return
        usable_distance = self._live_max_range - 2 * SWEEP_TEST_MARGIN_STEPS
        if usable_distance <= 0:
            self.sweep_required_accel_label.configure(text="(calibrated range too short for the sweep test)")
            return
        required_accel = math.ceil((end_speed * end_speed) / usable_distance)
        self.sweep_required_accel_label.configure(
            text=f"(need ≥ {required_accel} steps/s² to actually reach {end_speed} steps/s)"
        )

    def _append_log(self, line):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", line + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def _schedule_auto_refresh(self):
        if not self.link.is_connected():
            return
        if not self.sweep.is_running():
            try:
                self._suppress_next_echo = True
                self.link.write_line("s")
            except Exception as exc:
                self._suppress_next_echo = False
                self._append_log(f"ERROR: auto-refresh write failed: {exc}")
        self.root.after(AUTO_REFRESH_MS, self._schedule_auto_refresh)

    def _on_sweep_run_clicked(self):
        try:
            currents = [int(x.strip()) for x in self.sweep_currents_var.get().split(",") if x.strip()]
            if not currents:
                raise ValueError("enter at least one current")
            modes = []
            if self.sweep_spread_var.get():
                modes.append("spread")
            if self.sweep_stealth_var.get():
                modes.append("stealth")
            if not modes:
                raise ValueError("select at least one chopper mode")
            speed_range = (
                int(self.sweep_speed_start_var.get()),
                int(self.sweep_speed_end_var.get()),
                int(self.sweep_speed_step_var.get()),
                int(self.sweep_speed_fixed_accel_var.get()),
            )
            accel_range = (
                int(self.sweep_accel_start_var.get()),
                int(self.sweep_accel_end_var.get()),
                int(self.sweep_accel_step_var.get()),
                int(self.sweep_accel_fixed_speed_var.get()),
            )
            tolerance = int(self.sweep_tolerance_var.get())
            if speed_range[2] <= 0 or accel_range[2] <= 0:
                raise ValueError("speed/accel step must be greater than 0")
        except ValueError as exc:
            self._append_log(f"ERROR: invalid sweep input: {exc}")
            return

        self.sweep_tree.delete(*self.sweep_tree.get_children())
        self._sweep_rows = {}
        self._sweep_results = []
        self.sweep_verdict_label.configure(text="")
        self.sweep_progress_label.configure(text="")
        self.sweep_export_button.configure(state="disabled")
        for current in currents:
            for mode in modes:
                mode_label = "SpreadCycle" if mode == "spread" else "StealthChop"
                row_id = self.sweep_tree.insert("", "end", values=(current, mode_label, "--", "--", "--", "--", "pending"))
                self._sweep_rows[(current, mode)] = row_id

        self._set_sweep_running_state(True)
        self._append_log(f"Starting sweep: {len(currents)} current(s) x {len(modes)} mode(s)")
        self.sweep.start(currents, modes, speed_range, accel_range, tolerance)

    def _on_sweep_abort_clicked(self):
        self.sweep.abort()

    def _on_sweep_combo_done(self, result):
        self._sweep_results.append(result)
        row_id = self._sweep_rows.get((result.current_ma, result.mode))
        if row_id is None:
            return
        mode_label = "SpreadCycle" if result.mode == "spread" else "StealthChop"
        notes = []
        if result.note:
            notes.append(result.note)
        if result.speed_limit is not None:
            if result.speed_reached_end:
                notes.append("speed reached configured max without failing")
            else:
                notes.append(f"speed max drift {result.speed_max_drift}/{result.tolerance_steps} steps")
        if result.accel_limit is not None:
            if result.accel_reached_end:
                notes.append("accel reached configured max without failing")
            else:
                notes.append(f"accel max drift {result.accel_max_drift}/{result.tolerance_steps} steps")
        if result.ran_warm:
            notes.append("ran warm during testing (>=120C)")
        speed_rec = recommended_value(result.speed_limit, result.speed_reached_end)
        accel_rec = recommended_value(result.accel_limit, result.accel_reached_end)
        self.sweep_tree.item(row_id, values=(
            result.current_ma,
            mode_label,
            result.speed_limit if result.speed_limit is not None else "none",
            speed_rec if speed_rec is not None else "none",
            result.accel_limit if result.accel_limit is not None else "none",
            accel_rec if accel_rec is not None else "none",
            "; ".join(notes) if notes else "ok",
        ))

    def _format_sweep_progress_text(self, current_ma, mode, axis, speed, accel, completed, total):
        mode_label = "SpreadCycle" if mode == "spread" else "StealthChop"
        axis_label = "speed" if axis == "speed" else "acceleration"
        return (f"Testing {current_ma} mA, {mode_label}, speed={speed}, accel={accel} "
                f"(sweeping {axis_label}) — step {completed}/{total}")

    def _on_sweep_progress(self, current_ma, mode, axis, speed, accel, completed, total):
        self.sweep_progress_label.configure(
            text=self._format_sweep_progress_text(current_ma, mode, axis, speed, accel, completed, total)
        )

    def _on_sweep_step_result(self, current_ma, mode, axis, speed, accel, completed, total,
                               outcome, drift, tolerance_steps):
        base = self._format_sweep_progress_text(current_ma, mode, axis, speed, accel, completed, total)
        if outcome == "pass":
            suffix = f" → drift {drift}/{tolerance_steps} steps (PASS)"
        elif outcome == "fail_drift":
            suffix = f" → drift {drift}/{tolerance_steps} steps (FAIL - exceeded tolerance)"
        elif outcome == "fail_move":
            suffix = " → FAILED (safety disable tripped during move - repeated unexpected endstop hits)"
        else:  # "fail_verify"
            suffix = " → FAILED (position verify - max endstop not found)"
        text = base + suffix
        self.sweep_progress_label.configure(text=text)
        # On every PASS, the sweep coroutine loops straight back to
        # on_progress for the next step with no pause in between (see
        # _sweep_axis) - Tkinter never gets a chance to actually paint
        # this label update before it's overwritten by the next step's
        # "Testing..." text, so a passing step's result would otherwise
        # never become visible at all. Logging it too makes every step's
        # outcome durably visible regardless of how fast the sweep runs.
        self._append_log(text)

    def _on_sweep_finished(self, aborted, reason):
        self._set_sweep_running_state(False)
        if aborted:
            self._append_log(f"Sweep aborted: {reason}")
            self.sweep_progress_label.configure(text=self.sweep_progress_label.cget("text") + "  [aborted]")
        else:
            self._append_log("Sweep finished.")
            self.sweep_progress_label.configure(text=self.sweep_progress_label.cget("text") + "  [finished]")
        if self.sweep_tree.get_children():
            self.sweep_export_button.configure(state="normal")
        self._update_sweep_verdict()

    def _update_sweep_verdict(self):
        best = best_combo_per_mode(self._sweep_results)
        if not best:
            self.sweep_verdict_label.configure(text="")
            # safe_limits_value_label is intentionally left untouched here -
            # it's meant to persist the last completed sweep's answer, and
            # an aborted or empty run shouldn't erase a previously good one.
            return
        lines = []
        for mode in ("spread", "stealth"):
            result = best.get(mode)
            if result is None:
                continue
            mode_label = "SpreadCycle" if mode == "spread" else "StealthChop"
            speed_rec = recommended_value(result.speed_limit, result.speed_reached_end)
            accel_rec = recommended_value(result.accel_limit, result.accel_reached_end)
            line = (f"Best {mode_label}: {result.current_ma} mA → "
                    f"speed ≤ {speed_rec} steps/s, accel ≤ {accel_rec} steps/s²")
            if result.ran_warm:
                line += " (ran warm during testing - consider a lower current)"
            lines.append(line)
        text = "\n".join(lines)
        self.sweep_verdict_label.configure(text=text)
        self.safe_limits_value_label.configure(text=text)

    def _on_retract_clicked(self):
        self.link.write_line("y")

    def _on_reset_defaults_clicked(self):
        if messagebox.askyesno(
            "Reset to Defaults",
            "This clears the endstop log and resets run current, hold %, speed, "
            "acceleration, microsteps, chopper mode, and retract distance to "
            "their compiled-in defaults - overwriting what's saved on the "
            "device's EEPROM. Continue?",
        ):
            self.link.write_line("z")

    def _on_sweep_export_clicked(self):
        path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv")],
            initialfile="rrst_sweep_results.csv",
        )
        if not path:
            return
        try:
            with open(path, "w", newline="") as f:
                writer = csv.writer(f)
                writer.writerow([
                    "Current (mA)", "Mode",
                    "Speed Limit (steps/s)", "Recommended Speed (steps/s)",
                    "Accel Limit (steps/s^2)", "Recommended Accel (steps/s^2)",
                    "Notes",
                ])
                for row_id in self.sweep_tree.get_children():
                    writer.writerow(self.sweep_tree.item(row_id, "values"))
            self._append_log(f"Sweep results exported to {path}")
        except OSError as exc:
            self._append_log(f"ERROR: could not export CSV: {exc}")


def main():
    root = tk.Tk()
    ControlPanelApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
