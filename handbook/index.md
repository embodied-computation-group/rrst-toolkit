# RRST Toolkit

The **Respiratory Resistance Sensitivity Task (RRST)** measures how sensitive people are
to small changes in how hard it is to breathe in. Their awareness of that sensitivity
(metacognition) is measured too. A motorised wedge compresses a silicone tube in the
participant's breathing circuit. On each trial the participant takes two paced breaths,
one with added resistance and one without, then reports which was harder and how
confident they are. A Bayesian staircase sets the resistance.

This handbook covers how to **build, program, set up and run** the RRST device, for both
hardware generations:

<div class="grid cards" markdown>

- **[RRST 2.0 (2026)](v2/index.md)**: Teensy 4.0 + TMC2209 driver; software-set motor
  current, safety features, a desktop Control Panel, and a task that confirms every
  move. *Documentation in progress.*
- **[Legacy device (2021–2022)](legacy/index.md)**: Teensy 3.1 + TMC2100 driver, as
  published in Nikolova et al. (2022). Several parts are now hard to get; see
  [Parts sourcing](parts-sourcing.md).

</div>

Not sure which one you have? See [Which device do I have?](identify.md)

!!! warning "Status: draft"
    This handbook is being written. Pages marked **TODO** contain placeholders still to
    be filled in. The 2.0 sections need review by the device engineer, Martin Snejbjerg
    Jensen. New photos of the 2.0 devices are on the [roadmap](roadmap.md).

## Cite

Nikolova, N., Harrison, O., Toohey, S., Brændholt, M., Legrand, N., Correa, C., Vejlø, M.,
Snejbjerg Jensen, M., Fardo, F., & Allen, M. (2022). The respiratory resistance
sensitivity task: An automated method for quantifying respiratory interoception and
metacognition. *Biological Psychology*, 170, 108325.
<https://doi.org/10.1016/j.biopsycho.2022.108325>

## Credits

- **Task and methods:** Niia Nikolova and the
  [Embodied Computation Group](https://www.the-ecg.org/).
- **Device, PCB, firmware and Control Panel:** Martin Snejbjerg Jensen, CFIN, Aarhus
  University.
- **Original build and setup guide:** "RRST Build and Set up" (ECG, 2022). This handbook
  supersedes it.

Licence: GPL-3.0. Contact: Micah Allen (micah [at] cfin [dot] au [dot] dk).
