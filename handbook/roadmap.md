# Roadmap

## Documentation

- [ ] **Photos of the 2.0 devices**: exterior, interior, the TMC2209 conversion
      close-ups, the endstops and the Control Panel.
- [ ] **Engineer review** of every RRST 2.0 page (all `TODO(Martin)` items).
- [ ] **Parts sourcing survey**: availability and replacements, with dates and links.
- [ ] Replacements reported by other labs.
- [ ] Rod and leadscrew cut lengths, print settings, and the purpose of the printed
      couplers.

## Hardware

- [ ] **PCB respin for 2.0**: the TMC2209 on a native footprint, switchable fan,
      reverse-polarity protection, and a connector for the DS18B20 temperature sensor.
      This replaces today's hand-wired modification.
- [ ] A validated replacement motor for the legacy housing.

## Firmware

- [ ] Report the source commit (git hash) in the status output, as well as the build
      codename.
- [ ] Set the "enabled" flag after calibration, so driver-fault monitoring runs without
      an explicit `e`.
- [ ] Recommended quiet-running settings (StealthChop vs SpreadCycle, speed and
      acceleration), validated with the sweep test.

## Task software (RRST Toolkit 2.0)

- [x] Device layer that confirms and logs every calibration and move (tested against a
      simulated device).
- [ ] Bench validation on hardware, with real firmware transcripts.
- [ ] The 2.0 task, built from `RRS_3-0` with:
    - the known bugs fixed;
    - study settings in a configuration file;
    - per-device stimulus anchors;
    - the wedge parked at no load at the end of a session.
- [ ] **Generated masking noise** in Psychtoolbox, replacing the 60-minute recording.
- [ ] Optional pressure and flow recording, as recommended in the methods paper.

## Site

- [x] Published on GitHub Pages (2026-10-28): <https://micahgallen.github.io/rrst-toolkit/>
