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
%   presented. validateKidsConfig rejects a cap above 85 and any configured level
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

% --- Child safety and procedure --------------------------------------------
cfg.child.hardCap = 85;                  % % of the adult scale; never exceeded (85 is the absolute maximum)
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
cfg.psi.stimRange = 0:5:85;              % must contain 0 (catch) and the start level
cfg.psi.priorAlphaRange = linspace(30, 85, 56);
cfg.psi.priorBetaRange = linspace(log10(2), log10(16), 40);   % log10 beta
cfg.psi.priorGammaRange = 0:0.05:0.5;    % yes-bias (false-alarm rate), marginalised
cfg.psi.priorLambdaRange = 0.10;         % lapses: children miss more trials than adults

% --- Practice ----------------------------------------------------------------
cfg.practice.levels = [0 0 80 0 80 0 75 0];   % first two: free slurps, no question
cfg.practice.nFree = 2;
cfg.practice.passMin = 5;                % correct of the questioned trials...
cfg.practice.mustPass = [80 80];         % ...and both trials at 80 correct
cfg.practice.maxRounds = 2;

% --- Timing (s) --------------------------------------------------------------
cfg.timing.moveMin = 1.5;                % mouse animation while the wedge moves
cfg.timing.inhale = 1.2;                 % per slurp: belly grows, a third of the milkshake goes
cfg.timing.exhale = 1.8;                 % belly shrinks, bubbles rise. Pacing only: the child
                                         % need not follow it; Space ends the slurps early
cfg.timing.response = 8;                 % experimenter clicks the child's answer
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

% --- Output --------------------------------------------------------------------
cfg.output.dir = fullfile(root, 'data', 'raw');
cfg.devicesDir = fullfile(root, 'devices');
end
