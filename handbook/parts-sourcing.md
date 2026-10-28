# Parts sourcing

Current availability of every part, and tested or proposed replacements for those no
longer made. **Partial survey: 2026-10-28.** Many supplier sites blocked automated checks, so most parts are still unverified.

!!! warning "How to read this page"
    - **Available**: a current product page with price and stock was checked on the date
      shown.
    - **Discontinued**: the manufacturer or distributor says so.
    - **Unverified**: the supplier page couldn't be opened or checked. Treat these as
      unknown, not as available.
    - **Proposed**: a replacement that matches the specifications on paper but hasn't
      been built into a device yet.

!!! todo "TODO(parts): finish the survey by hand"
    The automated survey on 2026-10-28 couldn't open most supplier pages (e3d-online,
    Mouser, Farnell, element14, Analog Devices, StepperOnline and TME blocked or timed
    out). Every part not listed as Available or Discontinued below still needs a manual
    check in a browser, with the URL and date recorded.

## Stepper motor

The original **E3D Super Whopper** may no longer be available.
[GitHub issue #1](https://github.com/embodied-computation-group/RespiroceptionMethodsPaper/issues/1)
(September 2025) is titled "Stepper Motors no longer available", although its text says
"stepper drives". E3D's site could not be checked (blocked), so **this status is
unverified**. A replacement must have:

- a NEMA 17 face and mounting holes;
- a **5 mm shaft** (the coupler is 5 → 8 mm);
- **1.8° per step** (200 steps/rev): the firmware assumes 1600 steps/mm with the TR8×2
  leadscrew at 16 microsteps;
- a body length that fits the printed top shell;
- a rated current the driver can supply (TMC2209: about 2 A RMS max);
- holding torque comparable to the original.

| Motor | Status | Notes |
|---|---|---|
| E3D Super Whopper | Unverified (reported unavailable) | Original part. Unconfirmed search results suggest it is a Motech MT-1705HS200A-family motor (60 mm body, 5 mm shaft, 2 A, 1.8°). `TODO(parts)`: confirm from a datasheet |
| Motech MT-1705HS200AE | In use on 2.0 units (per the engineer's checklist) | Possibly the same motor family as the Super Whopper. `TODO(parts)`: datasheet, suppliers, fit in the legacy shell |
| LDO 42STH60-2004AC | Proposed, unverified | 60 mm, 2 A class. `TODO(parts)`: confirm the specifications |
| `TODO(parts)` | Proposed | |

!!! note "Running a 2 A motor"
    A 2.0 A-rated motor exceeds what the legacy TMC2100 (about 1.2 A RMS) can deliver at
    full rating. On a TMC2209 the firmware default run current is 800 mA. Whether the
    TMC2100 runs these motors reliably at reduced current hasn't been tested.

## Microcontroller and driver

| Part | Status | Replacement |
|---|---|---|
| Teensy 3.1 | **Discontinued**: PJRC lists it as replaced by the Teensy 3.2 ([pjrc.com](https://www.pjrc.com/store/teensy31.html), checked 2026-10-28) | Teensy 4.0, with the 2.0 firmware |
| Teensy 4.0 | **Available**: in stock at SparkFun, DEV-15583, US$23.80 ([sparkfun.com](https://www.sparkfun.com/teensy-4-0.html), checked 2026-10-28). PJRC says SparkFun now makes Teensy boards | — |
| TMC2100 SilentStepStick | Unverified | BigTreeTech TMC2209 V1.2, with the [2.0 conversion](v2/electronics.md) |
| BigTreeTech TMC2209 | **Available**: Tinytronics (NL), €7.00, 100+ in stock ([tinytronics.nl](https://www.tinytronics.nl/nl/mechanica-en-actuatoren/motoraansturingen-en-drivers/stappen-motoraansturingen-en-drivers/bigtreetech-tmc2209-stappenmotordriver-module), checked 2026-10-28). The page doesn't state the board revision | — |

## Other parts

| Part | Status | Notes |
|---|---|---|
| Omron microswitch | Unverified | The parts list says "DF2-5L". Omron's part number is probably **D2F-5L**. `TODO(parts)`: confirm and correct the parts list |
| POWERbreathe filtered mouthpiece | Partly verified | A single-use POWERbreathe bacteria filter is in stock at Oxycare (EU), €1.79 ([oxycare.eu](https://oxycare.eu/en/powerbreathe-bacteria-filter-blue-trendvent-physio-pulsar), checked 2026-10-28). Not confirmed to be the TrySafe/anti-viral mouthpiece used in the studies |
| Hans Rudolph 1410 T-valve | Unverified | The manufacturer's two-way valve page doesn't list series 1410. `TODO(parts)`: contact Hans Rudolph |
| Fan | Unverified | The parts list says 30×30 mm, but its link is a 40×40 mm fan. `TODO(parts)`: measure the shell |
| Sensirion SFM3019-240 flow sensor and SEK-SensorBridge (optional, [airflow sensor](shared/airflow-sensor.md)) | Unverified | Current Sensirion products ([SFM3019](https://sensirion.com/products/catalog/SFM3019), [SEK-SensorBridge](https://sensirion.com/products/catalog/SEK-SensorBridge)); price and stock not checked. Niia Nikolova reports buying the SFM3019-240 cheaply on Amazon. `TODO(parts)`: Amazon listing and price; sensor cable and tube adapters |
| Silicone tube, power supply, barrel socket, NCP1117, XM1584, TVS/Schottky diodes, capacitors | Unverified | Generic or widely stocked parts, not yet checked |

## Reports from other labs

!!! todo "TODO(parts): collect replacements other labs have used"
    Some labs building the device have reportedly found their own replacements. If you
    have built an RRST with substitute parts, please open an issue or pull request with
    the part, supplier, and whether it worked (see [Contributing](contributing.md)).
