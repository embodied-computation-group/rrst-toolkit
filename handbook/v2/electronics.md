# Electronics: TMC2209 conversion

This converts a board that already carries a **Teensy 4.0** to the **TMC2209** driver.
It adds UART configuration and power-transient protection. It is a hand-wired bench
modification of the existing board, not a new PCB. The full source is
`hardware/RRST_Hardware_Modification_Checklist.pdf` (Martin Snejbjerg Jensen,
2026-09-22). The reference schematic, `hardware/RRST_eagle_schematics.sch`, includes the
new parts D1, D2, C7, C8 and R1.

!!! danger "Work with power disconnected"
    Unplug USB and the barrel jack before soldering. Check diode and capacitor polarity
    twice. A reversed D1 only stops the board powering up, but a reversed C7 can fail
    violently.

!!! todo "TODO(photo): conversion photos"
    Add close-up photos of each step on a 2.0 unit: UART wires on the MS3 pad, the 1 kΩ
    resistor, the CFG1/CFG2 bridges, C7/C8 at the socket, D1 in the cut trace, D2 and R1.

## Part A: TMC2209 UART wiring

This enables software control of run current, hold current and microstepping, on top of
normal STEP/DIR operation.

1. Insert the TMC2209 module into the socket silkscreened **TMC2100**, in the standard
   StepStick orientation: the module's label side faces the same way as the old driver.
2. *Sanity check only:* the module's VCC_IO pin lands on the socket's VDD pad, which is
   already wired to the Teensy's 3.3 V rail.
3. Solder a wire from the socket's **MS3** pad (top row, 5th pin from the left)
   **directly to Teensy pin 0 (RX1)**.
4. Solder a second wire from the **same MS3 pad**, through a **~1 kΩ resistor**, to
   **Teensy pin 1 (TX1)**.
5. Bridge **CFG1 (MS1)** to an adjacent GND pad with a short jumper.
6. Bridge **CFG2 (MS2)** to an adjacent GND pad with a short jumper.

Steps 5–6 matter. CFG1 and CFG2 are unpopulated (floating) on this board, and the driver
needs MS1 = MS2 = LOW to latch UART address 0 at power-up.

!!! note "Why both UART wires go to MS3, not MS3 and !RST"
    BigTreeTech's manual labels both pad positions PDN_UART, implying they are joined on
    the module. Bench measurement found about 300 kΩ between them, so they are not one
    net on this module. If you use a different module, check with a meter (power off)
    before relying on either pad.

## Part B: Power-transient protection

This addresses driver damage seen on disconnect and reconnect. The causes were no bulk
capacitance on the motor rail, no reverse-polarity or surge protection, and a floating
EN pin during power transients.

1. Find the **VMOT** pad at the driver socket and an adjacent **GND** pad.
2. Solder **C7** (220 µF / 35 V electrolytic) across VMOT/GND, as close to the socket as
   possible. **+ to VMOT, − to GND.**
3. Solder **C8** (100 nF ceramic) in parallel with C7.
4. Find the trace from the barrel jack's centre pin (PWR) to VMOTOR, and cut it at a
   convenient point.
5. Splice **D1** (SS34 Schottky) in series: **anode on the jack side, cathode on the
   VMOTOR side**.
6. Solder **D2** (SMBJ26A TVS) across VMOTOR/GND, near the jack or the driver socket:
   **cathode to VMOTOR, anode to GND**.
7. Solder **R1** (10 kΩ) between the **EN** pad (socket EN / Teensy pin 8 net) and a
   nearby **3.3 V** pad.

!!! note "Why SMBJ26A"
    The TMC2209's absolute maximum motor-supply rating is only 32–33 V, much tighter than
    the TMC2100's 46 V. No standard TVS can guarantee clamping below about 33 V while
    keeping its standoff above the 24 V rail. The SMBJ26A is the best practical choice,
    but C7 is the main defence against reconnect and inductive-kickback transients.

## Verification before first power-up

- [ ] Continuity: MS1 and MS2 pads read 0 Ω to GND
- [ ] The EN pad is **not** shorted to GND (it reads a weak pull toward 3.3 V)
- [ ] C7/C8 polarity correct (visual)
- [ ] D1 lets current flow jack → VMOTOR, not reversed (visual)
- [ ] D2 is an SMBJ26A (not an SMBJ33A), with its cathode toward VMOTOR
- [ ] Power off: no short between VMOTOR and GND (multimeter)
- [ ] Power on: the Teensy boots normally
- [ ] After flashing: the serial CLI confirms the TMC2209 UART link (`x` shows no
      "UART link is down" warning)

Then continue with [Firmware and Control Panel](firmware.md).

!!! todo "TODO(Martin): steps not covered by the checklist"
    The checklist starts from a board that already has a Teensy 4.0. Document:

    - moving a legacy v3-0 board from Teensy 3.1 to Teensy 4.0 (pin compatibility, the
      USB-power trace cut, headers);
    - fan wiring on 2.0 units;
    - DS18B20 wiring, if fitted.
