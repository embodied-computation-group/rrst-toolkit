# Running the task

!!! note "Two task versions"
    The instructions below are for the **legacy task** (`RRS_2-2` / `RRS_3-0`, MATLAB
    2020a and later). For the **RRST 2.0 task** (`task/RRST_2-0/`), which confirms every
    device move, logs a full device transcript with the data, and maps stimuli onto
    anchors measured on each device, see [Running the 2.0 task](../v2/running.md).
    The participant instructions at the end of this page apply to both.

## Software

- **MATLAB R2020a or later.** Earlier versions lack the `serialport` interface.
- **Psychtoolbox 3**, with **GStreamer** (MSVC build) on Windows. Check the Psychtoolbox
  [requirements](https://psychtoolbox.org/requirements) for which MATLAB versions the
  current release supports.
- **Palamedes** toolbox ([palamedestoolbox.org](http://www.palamedestoolbox.org/download.html)).

Add Psychtoolbox and Palamedes, with their subfolders, to the MATLAB path and save it.
Test them with `DotDemo` (Psychtoolbox) and `PAL_AMRF_Demo` (Palamedes).

!!! todo "TODO(toolkit): tested versions"
    List the MATLAB, Psychtoolbox, GStreamer and Palamedes versions the 2.0 task is
    tested with. The 2022 setup was tested on Windows 10, MATLAB 2020a and
    Psychtoolbox 3.0.16.

## First-time setup (legacy task)

1. Use `RRS_2-2` for devices from April 2022 or earlier and `RRS_3-0` for May 2022 or
   later.
2. In MATLAB, go to the task folder and run `addpath(genpath(pwd)); savepath`.
3. Add the masking sound to `task/helpers/audio/` (see
   [Room and masking](room-and-masking.md#masking-noise)).
4. Find the device's serial port: run `serialportlist` with the USB cable unplugged,
   plug it in, and run it again. Note the new port, e.g. `COM5`.
5. In `code/loadParams.m`, set `sPort = "COM5";`

Common options in `loadParams.m`: staircase procedure (Psi, QUEST, n-down), tutorial on
or off, confidence ratings, rain sound, mouse or keyboard, language (English/Danish) and
end-of-session experience ratings.

!!! warning "Known issues in the legacy task code"
    A 2026 code review found the following:

    - **The rest position between trials is full obstruction in Psi/QUEST (mm) mode.**
      `moveResp2ITIpos` sends 20–80 to a 0–17 scale.
    - **Device moves are never confirmed.**
    - **The tutorial calls `resetResp`**, which doesn't exist in the 3-0 helpers.
    - **The Psi priors differ from the paper:** the slope range is log10 0–7 and the
      lapse rate is 0.03.

    Details are in the repository's integration review
    (`docs/integration_review_2026-10-28.md`). The 2.0 task fixes them.

## Running a session

1. In MATLAB, go to the task folder and run `experimentLauncher`.
2. Enter the participant ID (a number, padded to 4 digits).
3. The Psychtoolbox window can take a few seconds to open.
4. The session starts with a tutorial: trial structure, 2 trials with feedback, 6 practice
   trials. After a short break, the participant presses SPACE to begin.
5. **Psi:** 100 trials, about 30–35 min with breaks. **QUEST:** 60 trials, about 15 min.
6. Data are saved in `RRS_3-0/dataBackup/` with ID, date and time.
   `subjectReportRRS(filepath)` in `task/helpers/` produces a single-participant report.

## Instructions to the participant

- "In this task we measure how sensitive you are to changes in resistance when you
  breathe in. It takes about 30 minutes, with several breaks."
- "Breathe in through your mouth, through the blue mouthpiece. Breathe out normally,
  through your nose or your mouth. Many people find the nose easiest. Take short,
  shallow breaths so you don't hyperventilate."
- "On each trial you'll breathe in twice, each time when the circle on the screen
  expands. One of the two breaths will have a resistance added. Decide which breath was
  **more difficult**: left mouse button for the first, right for the second. Then rate
  how confident you are by moving the slider and clicking."
- "Sometimes it will feel like a guess. That's normal; give your best guess. Please use
  the whole confidence scale, not just the ends."
- "During breaks, breathe normally, stand up and move around."
- "Before each break you'll rate how unpleasant the task is, and there are a few
  questions at the end."
