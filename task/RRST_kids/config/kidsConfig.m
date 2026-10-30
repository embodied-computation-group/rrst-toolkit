function cfg = kidsConfig()
%KIDSCONFIG Settings for RRST-Kids ("Milkshake Monster"), for children of about 4-5.
%   cfg = kidsConfig()
%
%   PILOT settings, not a study decision. Single-interval yes/no: on each trial the
%   experimenter starts the slurping when the child is ready, the child takes a few
%   breaths at the same level and says whether "the mouse pinched the straw" (added
%   resistance). A Psi method with the guess rate (yes-bias) marginalised estimates
%   the threshold; catch trials at level 0 measure the false-alarm rate. Design
%   rationale: task/RRST_kids/README.md.
%
%   SAFETY: no level above cfg.child.hardCap (percent of the ADULT scale) is ever
%   presented. validateKidsConfig rejects a cap above 100 (full scale) and any configured level
%   above the cap, and kidsCheckLevel re-checks every level before it is sent.

cfg.label = "KIDS PILOT";

% --- Device (as the adult pilot) ------------------------------------------
cfg.device.mock = false;                 % true: simulated device, no hardware needed
cfg.device.port = "auto";                % stim laptop: "COM7" (COM4/COM5 are the LTE modem)
cfg.device.motion = struct('speed', 16000, 'acceleration', 10000, 'chopperMode', "SpreadCycle");
cfg.stim.unit = "percent";               % 0 = wedge touching the tube, 100 = barely possible to inhale (adult)
cfg.stim.restRange = [10 50];            % rest between trials, well below the cap
cfg.stim.calibrationTolerance = 300;     % steps; catches tube in/out mismatch

% --- Event markers (as the adult pilot) -------------------------------------
% LSL marker stream "RRST" for recording with physiology and airflow. Opened at
% launch, so start the Physio Recorder (RRST preset) first; it starts recording
% when the stream appears. Mock and simulated-child runs never wait for a recorder.
cfg.markers.lsl = true;
cfg.markers.requireRecorder = true;      % wait before calibration until a recorder receives the markers
cfg.markers.liblslDir = "C:\toolbox\liblsl-Matlab";

% --- Recording ---------------------------------------------------------------------
% "physio": the Physio Recorder records flow, markers (and PLUX); start it first (RRST
% preset); a real session waits until it receives the markers (markers.requireRecorder).
% "standalone": no Physio Recorder. The task starts flow_lsl.py itself if no "Flow"
% stream is running (and stops it at the end), never waits for a recorder, and saves
% every flow sample and marker it sees: result.flow, result.markers, <name>_flow.csv.
% Markers still go to LSL when markers.lsl is true.
cfg.recording.mode = "physio";            % "physio" | "standalone"

% --- Child safety and procedure --------------------------------------------
cfg.child.hardCap = 100;                 % % of the adult scale; never exceeded (100 = full scale, the absolute maximum; Micah 2026-10-30: no restriction below it)
cfg.child.rampMax = 15;                  % no level more than this above the highest level so far
cfg.child.startLevel = 70;               % first Psi trial: just perceptible for an adult
cfg.child.numPsiTrials = 30;
cfg.child.numCatchTrials = 10;           % level 0, random positions, not first, never two in a row
cfg.child.stopSE = 8;                    % stop early when the threshold SE is below this...
cfg.child.stopMinTrials = 20;            % ...after at least this many Psi trials
cfg.child.slurps = 3;                    % breaths per trial, all at the trial's level
cfg.child.maxRepeats = 10;               % trials re-queued after no answer or a bad breath
cfg.child.flagFAmax = 0.40;              % false-alarm rate above this: threshold unusable
cfg.child.flagHitMin = 0.60;             % hit rate at levels >= flagHighLevel below this: unusable
cfg.child.flagHighLevel = 80;

cfg.psi.PF = "PAL_Weibull";
cfg.psi.stimRange = 0:5:100;             % must contain 0 (catch) and the start level
cfg.psi.priorAlphaRange = linspace(30, 100, 71);
cfg.psi.priorBetaRange = linspace(log10(2), log10(16), 40);   % log10 beta
cfg.psi.priorGammaRange = 0:0.05:0.5;    % yes-bias (false-alarm rate), marginalised
cfg.psi.priorLambdaRange = 0.10;         % lapses: children miss more trials than adults

% --- Intro tutorial (between the story and the practice) ----------------------
% Free play (wedge at 0: the child slurps as often as they like and every slurp sets
% the reference slurp), then one demo per demoOrder with no question: "pinch" at
% pinchLevel with the mouse pinching the straw during the slurps, "sleep" at 0 with
% the mouse asleep, each followed by its reveal; then the answer cards, explained.
cfg.tutorial.enabled = true;             % false: the old free slurps (practice.nFree)
cfg.tutorial.pinchLevel = 90;            % % of the adult scale; at most child.hardCap
cfg.tutorial.demoOrder = ["pinch" "sleep"];

% --- Practice ----------------------------------------------------------------
cfg.practice.levels = [90 0 90 0 85 0];  % questioned trials, the truth shown after each (90/90/85: Micah 2026-10-30, after 80 was missed by an adult)
cfg.practice.nFree = 0;                  % free slurps (no question) before them, counted in
                                         % levels: 0 with the tutorial (free play replaces
                                         % them); without it nFree = 2, levels [0 0 80 0 80 0 75 0]
cfg.practice.passMin = 5;                % correct of the questioned trials...
cfg.practice.mustPass = [90 90];         % ...and both trials at 90 correct
cfg.practice.maxRounds = 2;

% --- Feedback to the child after an answer ------------------------------------------
% "cards" (default): the two answer cards, the correct one in a thick gold frame with a
% star badge, the chosen one keeps its white frame; right: a gold tick and the star
% sound; wrong: the chosen card fades, the mouse on the correct card squeezes the
% straw twice (or a Z floats up from it asleep) and the soft "tryagain" sound; for
% timing.feedback s. "reveal": the earlier scene (the mouse pinching or asleep in a
% spotlight, 1.5 s). Second real run (2026-10-30): the reveal was not clear to the
% child; the truth was only in the experimenter's line.
cfg.feedback.practice = true;            % after every practice answer
cfg.feedback.main = false;               % after every main answer too (stars are always shown)
cfg.feedback.style = "cards";            % "cards" | "reveal"

% --- Timing (s) --------------------------------------------------------------
cfg.timing.moveMin = 1.5;                % mouse animation while the wedge moves
cfg.timing.inhale = 1.2;                 % per slurp: belly grows, a third of the milkshake goes
cfg.timing.exhale = 1.8;                 % belly shrinks, bubbles rise. Pacing only: the child
                                         % need not follow it; Space ends the slurps early
                                         % (timed animation, no airflow sensor)
cfg.timing.drain = 1.0;                  % breath-driven: a third of the milkshake drains with
                                         % bubbles after each counted slurp (and in free play)
cfg.timing.response = 8;                 % experimenter clicks the child's answer
cfg.timing.feedback = 2.5;               % the child's feedback (cfg.feedback, style "cards")
cfg.timing.reward = 1.0;
cfg.timing.dance = 2.0;                  % a cup is full
cfg.timing.pause = 45;
cfg.timing.pauseEvery = 10;              % trials

% --- Screen and sound --------------------------------------------------------
cfg.smallWindow = false;                 % true: 1/3-size window for testing
cfg.visual.textSize = 48;
cfg.noise.enabled = true;
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
cfg.noise.file = fullfile(root, 'task', 'helpers', 'audio', 'rain_loop_30s.wav');
cfg.noise.volume = 0.6;                  % lower than the adult pilot's 1 for small ears; check by ear
cfg.sound.enabled = true;                % cue sounds (kidsSound), mixed over the rain
cfg.sound.volume = 0.8;                  % cue loudness in (0, 1]; check by ear with the rain
cfg.sound.fs = 48000;                    % Hz, used only when the rain is off (else the rain's rate)
cfg.text.language = "en";                % child-facing text must be translated before use

% --- Breath feedback (SFM3019 "Flow" LSL stream; pilot values, tune on the rig) ----
cfg.flow.enabled = true;                  % false: today's timed animation, no inlet
cfg.flow.feedback = "breath";             % "breath" | "none"   {{FLOW_FEEDBACK_MODE}}
cfg.flow.timeout = 10;                    % s to find the "Flow" stream at launch
cfg.flow.onsetSlm = 3;                    % flow above this starts a slurp (flow_quality uses 3 slm)
cfg.flow.onsetHold = 0.05;                % s above threshold before it counts (noise guard)
cfg.flow.offsetHold = 0.15;               % s below threshold before the slurp ends
cfg.flow.minVolumeFrac = 0.25;            % slurp counts if volume >= this x reference volume
cfg.flow.minVolumeL = 0.10;               % ...and at least this (absolute floor, children)
cfg.flow.bellyFraction = 0.40;            % belly is full at this x reference volume (saturation)
cfg.flow.refVolumeDefault = 0.6;          % L, used until the free slurps have set the reference
cfg.flow.slurpTimeout = 8;                % s without a slurp onset: experimenter prompt
cfg.flow.maxSlurpDur = 6;                 % s: a "slurp" longer than this is a leak/draught, not counted
cfg.flow.smoothHz = 5;                    % low-pass before detection
% The streamer the task starts in standalone mode: plux-lsl, next to this toolkit on
% the stim laptop. Checked only when it has to be started. Moved? Set all three.
cfg.flow.pluxDir = fullfile(fileparts(root), 'plux-lsl');
cfg.flow.streamer = fullfile(cfg.flow.pluxDir, '.venv', 'Scripts', 'python.exe');
cfg.flow.streamerScript = fullfile(cfg.flow.pluxDir, 'flow_lsl.py');

% --- Output --------------------------------------------------------------------
cfg.output.dir = fullfile(root, 'data', 'raw');
cfg.devicesDir = fullfile(root, 'devices');
end
