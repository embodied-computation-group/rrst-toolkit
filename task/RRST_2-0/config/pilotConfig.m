function cfg = pilotConfig()
%PILOTCONFIG Settings for piloting the RRST 2.0 task. NOT a study configuration.
%   cfg = pilotConfig()
%
%   Values follow the original RRS_3-0 code where it was unambiguous, converted to a
%   percent-of-device-range stimulus axis. Psi priors follow the methods paper
%   (beta log10(1)-log10(16), lambda 0.02). The open scientific decisions (TASKS.md,
%   "Open questions") are NOT settled here: a study needs its own configuration.

cfg.label = "PILOT";

% --- Device --------------------------------------------------------------
cfg.device.mock = false;                 % true: simulated device, no hardware needed
cfg.device.port = "auto";                % "auto" only if exactly one serial port exists
cfg.device.recalibrateAtBreaks = true;   % as in RRS_3-0; about 25 s inside the break
% Set and checked at every calibration, never trusted from the device's EEPROM
% (Martin, 2026-10-28). PROVISIONAL, {{MOTION}} is undecided: these are what unit
% 2E4441D76D5F2996 already runs (SpreadCycle, 16000/10000; a 24000-step move takes
% about 3.1 s), so piloting behaves as before. StealthChop must stay <= 16000 steps/s.
cfg.device.motion = struct('speed', 16000, 'acceleration', 10000, 'chopperMode', "SpreadCycle");

% --- Stimulus axis -------------------------------------------------------
% "percent": 0 = wedge just touching the tube, 100 = barely possible to inhale,
% both from the device record. "mm": travel past the zero anchor.
cfg.stim.unit = "percent";
cfg.stim.restRange = [20 80];            % where the wedge rests between trials (RRS_3-0 intent: 50 +/- 30 %)
cfg.stim.calibrationTolerance = 300;     % steps; catches tube in/out mismatch (about 1150)

% --- Procedure -----------------------------------------------------------
cfg.procedure = "psi";                   % "psi" (Palamedes PAL_AMPM) or "quest" (PAL_AMRF running fit)

cfg.psi.numTrials = 100;
cfg.psi.grain = 72;
cfg.psi.PF = "PAL_Weibull";
cfg.psi.stimRange = linspace(0, 100, 41);            % 2.5 % steps, used exactly (no rounding)
cfg.psi.priorAlphaRange = linspace(0, 100, 72);
cfg.psi.priorBetaRange = linspace(log10(1), log10(16), 72);   % log10 beta, as the paper
cfg.psi.priorGammaRange = 0.5;
cfg.psi.priorLambdaRange = 0.02;

cfg.quest.numStaircases = 2;
cfg.quest.numTrials = 30;                % per staircase
cfg.quest.alphas = linspace(0, 100, 41);
cfg.quest.xMin = 0;
cfg.quest.xMax = 100;
cfg.quest.PF = "PAL_Weibull";
cfg.quest.beta = 1.5;
cfg.quest.lambda = 0.02;

cfg.metacogTrials = 0;                   % extra near-threshold trials after the staircase

% --- Session -------------------------------------------------------------
cfg.confidence = true;
cfg.inputDevice = 2;                     % 1 keyboard, 2 mouse (keyboard untested in RRS_3-0)
cfg.runTutorial = false;
cfg.tutorial.easyStim = 97;              % RRS_3-0 percent values
cfg.tutorial.hardStim = 65;
cfg.tutorial.exampleStimuli = [98 61 82];
cfg.tutorial.stimInAlt = [1 2 2];
cfg.probeTaskSatisfaction = true;
cfg.collectExperienceRatings = true;
cfg.smallWindow = false;                 % true: 1/3-size window for debugging

% --- Timing (s) ----------------------------------------------------------
cfg.timing.fixedTiming = false;
cfg.timing.prepare = 1.5;
cfg.timing.inhale = 0.8;
cfg.timing.breathPause = 0.5;
cfg.timing.response = 3;
cfg.timing.confidence = 5;
cfg.timing.isi = 2;                      % countdown before each breath, AFTER the move is confirmed
cfg.timing.itiMin = 2;
cfg.timing.itiMax = 4;
cfg.timing.pause = 120;
cfg.timing.pauseEvery = 20;              % trials (30 without confidence ratings, as RRS_3-0)
cfg.timing.experienceQuestion = 10;

% --- Masking noise -------------------------------------------------------
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
cfg.noise.enabled = false;
% Sound file looped as is (48 kHz stereo, about -29 dBFS RMS; see its README).
% Empty: generate noise of cfg.noise.colour instead.
cfg.noise.file = fullfile(root, 'task', 'helpers', 'audio', 'rain_loop_30s.wav');
cfg.noise.volume = 1;                    % file: 1 = as recorded, about as loud as brown at 0.2; depends on system volume
cfg.noise.colour = "brown";              % generated noise only. Pilot 2026-10-28: pink was harsh
cfg.noise.fs = 44100;                    % generated noise only
cfg.noise.durS = 30;                     % generated noise only; looped

% --- Event markers --------------------------------------------------------
% LSL marker stream "RRST" (trial and interval onsets) for recording with
% physiology and airflow. Opened at launch: start RRST before the recorder.
cfg.markers.lsl = true;
cfg.markers.liblslDir = "C:\toolbox\liblsl-Matlab";

% --- Output --------------------------------------------------------------
cfg.output.dir = fullfile(root, 'data', 'raw');
cfg.devicesDir = fullfile(root, 'devices');
end
