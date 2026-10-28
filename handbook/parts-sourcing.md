# Parts sourcing

Current availability of every part, and tested or proposed replacements for those no
longer made. **Last checked: TODO.**

!!! warning "How to read this page"
    - **Available**: a current product page with price and stock was checked on the date
      shown.
    - **Discontinued**: the manufacturer or distributor says so.
    - **Unverified**: the supplier page couldn't be opened or checked. Treat these as
      unknown, not as available.
    - **Proposed**: a replacement that matches the specifications on paper but hasn't
      been built into a device yet.

!!! todo "TODO(parts): availability survey in progress"
    A parts availability survey is under way. Its results will be added here, with the
    URL and date of every check.

## Stepper motor

The original **E3D Super Whopper** is reported as no longer available
([GitHub issue #1](https://github.com/embodied-computation-group/RespiroceptionMethodsPaper/issues/1),
September 2025). A replacement must have:

- a NEMA 17 face and mounting holes;
- a **5 mm shaft** (the coupler is 5 → 8 mm);
- **1.8° per step** (200 steps/rev): the firmware assumes 1600 steps/mm with the TR8×2
  leadscrew at 16 microsteps;
- a body length that fits the printed top shell;
- a rated current the driver can supply (TMC2209: about 2 A RMS max);
- holding torque comparable to the original.

| Motor | Status | Notes |
|---|---|---|
| E3D Super Whopper | Reported discontinued | Original part |
| Motech MT-1705HS200AE | In use on 2.0 units (per the engineer's checklist) | `TODO(parts)`: specifications, suppliers, fit in the legacy shell |
| `TODO(parts)` | Proposed | |

## Microcontroller and driver

| Part | Status | Replacement |
|---|---|---|
| Teensy 3.1 | Discontinued | Teensy 4.0, with the 2.0 firmware |
| TMC2100 SilentStepStick | `TODO(parts)` | BigTreeTech TMC2209 V1.2, with the [2.0 conversion](v2/electronics.md) |

## Reports from other labs

!!! todo "TODO(parts): collect replacements other labs have used"
    Some labs building the device have reportedly found their own replacements. If you
    have built an RRST with substitute parts, please open an issue or pull request with
    the part, supplier, and whether it worked (see [Contributing](contributing.md)).
