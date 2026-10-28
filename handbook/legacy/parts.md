# Legacy parts list (April 2022)

This is the parts list from the 2022 build guide
(["rrst_parts_list_04-2022"](https://docs.google.com/spreadsheets/d/1Xm-xjyxZgqfn2RlGidUxHrNGNTMF7fd8MpfaUctbE9U)).
The supplier links are the original 2022 ones and most are Danish. The **Status**
column is filled in from [Parts sourcing](../parts-sourcing.md). A status of `TODO`
means the part has not been checked yet.

## Tools

3D printer (FDM, 20 cm build volume, PETG filament) · soldering iron and stand ·
lead-free solder (SAC305) · desoldering braid · solder sucker · wire cutter and
stripper · needle-nose pliers · pliers · fine tweezers · ruler · metal saw (for the rods
and leadscrew) · safety glasses · fume extractor · a Windows or Linux computer.

## Bottom shell

| Part | Specification | Qty | 2022 source | Status |
|---|---|---|---|---|
| Heat-set inserts | M3 × D5.0 × L4.0 | 6 | — | TODO |
| Button-head screws | M3×6 BHCS | 4 | — | TODO |
| Button-head screws | M3×12 BHCS | 2 | — | TODO |
| Button-head screws | M3×35 BHCS | 2 | — | TODO |
| Button-head screws | M3×40 BHCS | 4 | — | TODO |
| Rubber feet | 12×8×16 mm | 4 | [AliExpress](https://www.aliexpress.com/item/33014925172.html) | TODO |
| Fan | 24 V, 30×30 mm | 1 | [3deksperten](https://3deksperten.dk/silent-fan-40x40x10-12-24v-550.html) | TODO. *The linked product is 40×40 mm; check which size the shell takes* |

## Top shell and mechanics

| Part | Specification | Qty | 2022 source | Status |
|---|---|---|---|---|
| Heat-set inserts | M3 × D5.0 × L4.0 | 6 | — | TODO |
| Bearing | 608, 8×22×7 mm | 1 | — | TODO |
| Linear bearings | LM6UU | 2 | — | TODO |
| Steel rods | Ø6 × 140 mm | 2 | — | TODO |
| Stepper motor | E3D Super Whopper | 1 | [E3D](https://e3d-online.com/products/motors) | **Reported unavailable** ([issue #1](https://github.com/embodied-computation-group/RespiroceptionMethodsPaper/issues/1)); unverified. See [replacements](../parts-sourcing.md#stepper-motor) |
| Stepper damper | NEMA 17 | 1 | — | TODO |
| Microswitch (endstops) | Omron "DF2-5L" (probably a typo for **D2F-5L**) | 2 | — | Unverified; see [Parts sourcing](../parts-sourcing.md#other-parts) |
| Coupler | 5 → 8 mm, light-duty rigid | 1 | [3dnielsen](https://3dnielsen.dk/lmuu-glideleje/301-5-to-8mm-light-duty-rigid-coupler-1stk.html) | TODO |
| Leadscrew + nut | TR8×2 (2 mm pitch, 8 mm), ~20 cm, cut to fit; **remember the nut** | 1 | [hobby-store](https://hobby-store.co.uk/lead-screw/lead-screw-tr8x2-500mm.html), [nut](https://hobby-store.co.uk/lead-screw-nuts/lead-screw-nut-tr8x2.html) | TODO |
| Self-tapping screws | M2×10 | 2 | — | TODO |
| Button-head screws | M3×6, M3×12, M3×35 BHCS | 2 each | — | TODO |

## PCB (v3-0 connection board)

| Part | Specification | Qty | 2022 source | Status |
|---|---|---|---|---|
| PCB | Gerbers in `hardware/legacy/version_3-0/pcb/` | 1 (order spares) | any PCB service | — |
| Step-down DC-DC | XM1584 (MP1584 module) | 1 | — | TODO |
| Stepper driver | TMC2100 SilentStepStick. *Adjust its regulator to 0.8 V* | 1 | [Farnell 2822153](https://dk.farnell.com/trinamic/tmc-silentstepstick/stepper-driver-board-2-phase-motor/dp/2822153) | TODO. 2.0 uses a TMC2209 instead |
| Heatsink | StepStick heatsink | 1 | [3deksperten](https://3deksperten.dk/heat-sink-for-a4988.html) | TODO |
| Microcontroller | Teensy 3.1 | 1 | — | **Discontinued** ([PJRC](https://www.pjrc.com/store/teensy31.html), checked 2026-10-28). 2.0 uses a Teensy 4.0 |
| Pin headers, female | 8-pin ×2, 14-pin ×2, 5-pin ×1 | | — | TODO |
| Pin headers, male | 8-pin ×2, 14-pin ×2, 5-pin ×1, 2-pin ×5, 1-pin ×1 | | — | TODO |
| Jumper | 2.54 mm | 1 | — | TODO |
| JST-XH male/female | 4-pin ×1, 3-pin ×2, 2-pin ×1 (each) | | — | TODO |
| Voltage regulator | NCP1117ST33T3G (3.3 V LDO) | 1 | — | TODO |
| Capacitor | 100 nF 0603 | 1 | — | TODO |
| Capacitor | 10 µF 1206, Vishay TR3A106K010C0900 | 2 | — | TODO |
| Capacitor | 22 µF 2412 | 1 | — | TODO |
| DC barrel socket | Cliff FC68148, 2.1 mm | 1 | [Farnell 224959](https://dk.farnell.com/cliff-electronic-components/fc68148/socket-pcb-dc-power-2-1mm-pk10/dp/224959) | TODO |
| DC power supply | Multicomp Pro MP007794 | 1 | — | TODO. `TODO`: record its voltage and current |
| USB cable | micro-USB | 1 | — | — |

## Accessories (both generations)

| Part | Specification | Qty | 2022 source | Status |
|---|---|---|---|---|
| Mouthpieces | POWERbreathe single-use, anti-viral (TrySafe filtered) | per participant | — | TODO |
| T-valve | Hans Rudolph small T-shaped non-rebreathing valve, series 1410, part 112622 | 1 | [Hans Rudolph](https://www.rudolphkc.com/product-page/two-way-non-rebreathing-valves) | TODO |
| Connecting tube | Intersurgical smoothbore tubing, 22 mm, 0.5 m | several | [Intersurgical](https://se.intersurgical.com/products/intensivvard/22mm-and-15mm-smoothbore-tubing-lengths-with-soft-end-connectors) | TODO |
| Silicone tube | 19 mm OD, 13 mm ID (3 mm wall) | ~10 cm | [Hounisen](https://www.hounisen.com/laboratorieudstyr/plast/slanger/silikoneslanger/silikoneslange-13-x-3-mm) | TODO |

!!! todo "TODO(parts): printed couplers"
    The v3-0 print set includes four printed couplers (`coupler1–4.stl`) and a
    `device_drawer.stl`, which the 2022 guide doesn't describe. Document what each one
    connects.
