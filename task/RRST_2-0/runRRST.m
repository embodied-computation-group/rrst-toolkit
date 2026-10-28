function runRRST(cfg)
%RUNRRST Run the RRST 2.0 task.
%   runRRST()       pilot settings (config/pilotConfig.m), real device
%   runRRST(cfg)    your own configuration, e.g.
%                   cfg = pilotConfig(); cfg.device.mock = true; runRRST(cfg)
%
%   Before anything moves, this checks the configuration, Psychtoolbox and
%   Palamedes, connects to the device, loads its record from devices/ (by the
%   device ID the firmware reports), checks every configured level against the
%   device's range, and asks the operator to confirm the tube is seated.
%   Data go to cfg.output.dir (default data/raw/, never committed).
%
%   Press Esc during the task to abort: the wedge is parked open and the data so
%   far are saved.

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
addpath(fullfile(here, 'code'), fullfile(here, 'config'), ...
    fullfile(root, 'task', 'helpers'), fullfile(root, 'device'));

if nargin < 1
    cfg = pilotConfig();
end
validateConfig(cfg);

%% Toolboxes
if isempty(which('PsychtoolboxVersion'))
    error('rrst:missingToolbox', 'Psychtoolbox 3 is not on the MATLAB path (http://psychtoolbox.org/download).');
end
if isempty(which('PAL_AMPM_setupPM'))
    error('rrst:missingToolbox', 'Palamedes is not on the MATLAB path (https://palamedestoolbox.org).');
end
fprintf('Psychtoolbox %s\n', PsychtoolboxVersion);
fprintf('Configuration: %s, procedure %s, stimulus unit %s\n', cfg.label, cfg.procedure, cfg.stim.unit);

%% Event markers (LSL). Opened first so a recorder started now already sees them.
if cfg.markers.lsl
    rrstMarker('open', cfg.markers.liblslDir);
    closeMarkers = onCleanup(@() rrstMarker('close'));
end

%% Participant
vars.exptName   = 'RRST';
vars.exptVers   = '2-0';
vars.subNo      = input('What is the subject ID, e.g. 0001)?   ');
if isempty(vars.subNo)
    vars.subNo = 9999;                                       % test
end
vars.session    = input('Session number (1, 2, 3, ...)?   ');
if isempty(vars.session) && vars.subNo == 9999
    vars.session = 1;                                        % test
end
vars.languageIn = input('Language?: (e for english, or d for danish)   ', 's');

vars.OutputFolder = cfg.output.dir;
if ~exist(vars.OutputFolder, 'dir')
    mkdir(vars.OutputFolder);
end
vars.DataFileName = sessionFileStem(vars.subNo, vars.session, cfg.device.mock);   % e.g. RRST_0001_s2
if vars.subNo ~= 9999
    checkSessionIsNew(vars.OutputFolder, vars.DataFileName);   % a completed session is never run again
end

%% Device
if cfg.device.mock
    port = rrst.MockPort('MaxPosition', 45000);
    fprintf(2, '\n*** MOCK DEVICE: no hardware is moved. For testing the task only. ***\n\n');
else
    portName = rrst.choosePort(cfg.device.port, serialportlist("available"));
    port = rrst.openPort(portName);
    fprintf('Device port: %s\n', portName);
end
closePort = onCleanup(@() delete(port));   % closing the port disables the motor
dev = rrst.Device(port);
st = dev.status();
fprintf('Device %s, firmware %s, git commit %s\n', st.deviceId, st.softwareVersion, st.gitCommit);
fprintf('Device settings before the session: %g steps/s, %g steps/s^2, %s (set to %d, %d, %s at calibration)\n', ...
    st.speed, st.acceleration, st.chopperMode, ...
    cfg.device.motion.speed, cfg.device.motion.acceleration, cfg.device.motion.chopperMode);

rec = rrst.loadDeviceRecord(st.deviceId, cfg.devicesDir);
if isfield(rec.anchors, 'provisional') && rec.anchors.provisional
    fprintf(2, 'Note: this device''s anchors are provisional: %s\n', rec.anchors.provisionalReason);
end
stim = rrst.Stimulator(dev, rec, 'Unit', cfg.stim.unit, 'RestRange', cfg.stim.restRange, ...
    'CalibrationTolerance', cfg.stim.calibrationTolerance, 'Motion', cfg.device.motion);
switch cfg.procedure
    case "psi",   stim.validateLevels(cfg.psi.stimRange);
    case "quest", stim.validateLevels([cfg.quest.xMin cfg.quest.xMax]);
end
if cfg.runTutorial
    stim.validateLevels([cfg.tutorial.easyStim cfg.tutorial.hardStim cfg.tutorial.exampleStimuli]);
end
fprintf('Scale: 0-%g %s (zero = wedge touching the tube, max = barely possible to inhale)\n', ...
    stim.ScaleMax, stim.Unit);

input(sprintf(['\nCalibration runs with the tube %s, as in the device record.\n' ...
    'The wedge will close fully, then open. Press Enter when ready...'], ...
    erase(string(rec.anchors.calibrationCondition), "tube ")));

%% Screen
oldLevel = Screen('Preference', 'Verbosity', 0);
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0);
restoreScreen = onCleanup(@() Screen('Preference', 'Verbosity', oldLevel));
scr.ViewDist = 70;
HideCursor;

main(vars, scr, cfg, stim);
end
