function result = runKidsRRST(cfg)
%RUNKIDSRRST Run RRST-Kids ("Milkshake Monster"), a yes/no breathing task for children of about 4-5.
%   runKidsRRST()       pilot settings (config/kidsConfig.m), real device
%   runKidsRRST(cfg)    e.g. cfg = kidsConfig(); cfg.device.port = "COM7"; runKidsRRST(cfg)
%
%   Test without hardware or a child:
%     cfg = kidsConfig(); cfg.device.mock = true; cfg.smallWindow = true;
%     cfg.debug.simulateChild = [70 8 0.1 0.1];   % [threshold slope falseAlarm lapse]
%     cfg.debug.timeScale = 0.2;                   % everything 5x faster
%     runKidsRRST(cfg)
%
%   SAFETY: no level above cfg.child.hardCap (100 = full adult scale at most) is
%   ever sent. Calibration closes the wedge fully: do it before the child sits down.
%   Esc aborts at any time (wedge parked open, data saved). Space pauses.
%
%   Markers: with cfg.markers.lsl (default) the "RRST" LSL marker stream opens at
%   launch, so start the Physio Recorder (RRST preset) first. A real session waits
%   before calibration until a recorder receives the markers; mock and simulated-child
%   runs don't. cfg.markers.lsl = false runs without LSL (liblsl not needed).
%
%   Airflow: with cfg.flow.enabled (default) the "Flow" LSL stream of the SFM3019
%   (plux-lsl/flow_lsl.py, started by the Physio Recorder's RRST preset) is required:
%   the task finds it (cfg.flow.timeout s), reads 1 s and prints "Airflow sensor OK"
%   or stops with the fix (rrst:noFlowStream, rrst:flowBad). A simulated child always
%   uses synthetic flow (kidsSimFlow); a mock device uses the live stream if one is
%   found within 2 s, else synthetic flow. Both print SIMULATED FLOW.
%   cfg.flow.enabled = false; cfg.flow.feedback = "none" runs the timed animation.
%
%   Recording (cfg.recording.mode, printed on the first line):
%   "physio" (default): the Physio Recorder records; everything above applies.
%   "standalone": no Physio Recorder. If no "Flow" stream is found within 2 s the
%   task starts plux-lsl/flow_lsl.py itself, hidden (flowStreamer; cfg.flow.streamer,
%   cfg.flow.streamerScript), and stops it at the end (also after Esc or an error);
%   a streamer that was already running is used and left running. It never waits for
%   a recorder, keeps every flow sample it pulls and every marker it sends, and saves
%   them in the .mat (result.flow, result.markers, result.t0) and <name>_flow.csv.
%     cfg = kidsConfig(); cfg.recording.mode = "standalone"; runKidsRRST(cfg)
%   See README.md in this folder.

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
addpath(fullfile(here, 'code'), fullfile(here, 'config'), fullfile(root, 'device'), ...
    fullfile(root, 'task', 'RRST_2-0', 'code'), ...       % uniqueFileName
    fullfile(root, 'task', 'helpers'));                   % rrstMarker, waitForRecorder, flowInlet

if nargin < 1
    cfg = kidsConfig();
end
if ~isfield(cfg, 'debug'), cfg.debug = struct(); end
if ~isfield(cfg.debug, 'simulateChild'), cfg.debug.simulateChild = []; end
if ~isfield(cfg.debug, 'timeScale'), cfg.debug.timeScale = 1; end
validateKidsConfig(cfg);
if isempty(which('PsychtoolboxVersion')) || isempty(which('PAL_AMPM_setupPM'))
    error('rrst:missingToolbox', 'Psychtoolbox 3 and Palamedes must be on the MATLAB path.');
end
if kidsStandalone(cfg)
    modeLine = 'STANDALONE recording (no Physio Recorder: the task records flow and markers itself)';
else
    modeLine = 'PHYSIO recording (start the Physio Recorder, RRST preset, first)';
end
fprintf('RRST-Kids, %s, %s. Cap %g %% of the adult scale.\n', cfg.label, modeLine, cfg.child.hardCap);

%% Event markers (LSL). Opened first so a recorder started now already sees them.
closeMarkers = kidsOpenMarkers(cfg); %#ok<NASGU>   closes the stream when this function ends

%% Airflow (breath feedback): the sensor is checked before anything else happens
[flowSrc, flowSource, streamer] = openFlow(cfg);
% the inlet first, then the streamer if the task started it (normal end, Esc, error)
closeFlow = onCleanup(@() closeFlowSource(flowSrc, streamer)); %#ok<NASGU>

%% Child
if isempty(cfg.debug.simulateChild)
    vars.subNo = input('Child ID (number)?   ');
else
    vars.subNo = 9999;
end
if isempty(vars.subNo), vars.subNo = 9999; end
vars.seed = sum(100 * clock); %#ok<CLOCK>
vars.started = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
vars.flowSource = flowSource;               % "live" | "simulated" | "off" (saved)
vars.flowSrc = flowSrc;                     % the source itself (kidsMain; not saved)

%% Device
if cfg.device.mock
    port = rrst.MockPort('MaxPosition', 45000);
    fprintf(2, '\n*** MOCK DEVICE: no hardware is moved. ***\n\n');
else
    portName = rrst.choosePort(cfg.device.port, serialportlist("available"));
    port = rrst.openPort(portName);
    fprintf('Device port: %s\n', portName);
end
closePort = onCleanup(@() delete(port));   % closing the port disables the motor
dev = rrst.Device(port);
st = dev.status();
rec = rrst.loadDeviceRecord(st.deviceId, cfg.devicesDir);
stim = rrst.Stimulator(dev, rec, 'Unit', cfg.stim.unit, 'RestRange', cfg.stim.restRange, ...
    'CalibrationTolerance', cfg.stim.calibrationTolerance, 'Motion', cfg.device.motion);
stim.validateLevels([cfg.psi.stimRange cfg.practice.levels cfg.tutorial.pinchLevel cfg.child.hardCap]);
fprintf('Device %s, firmware %s\n', st.deviceId, st.softwareVersion);

if kidsWaitsForRecorder(cfg)               % never for a mock device, a simulated child or standalone
    waitForRecorder();
elseif kidsStandalone(cfg)
    fprintf('Standalone recording: the task records flow and markers itself.\n');
end
if isempty(cfg.debug.simulateChild)
    input(sprintf(['\nCalibration closes the wedge fully. Tube in, NOBODY on the mouthpiece.\n' ...
        'Press Enter when ready...']));
end

%% Session
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0);
if isempty(cfg.debug.simulateChild), HideCursor; end
result = kidsMain(cfg, stim, vars);
end

function [src, kind, streamer] = openFlow(cfg)
% The airflow source: the live "Flow" stream, synthetic flow for tests, or none.
% Standalone: no stream within 2 s -> start flow_lsl.py (streamer: a flowStreamer the
% caller stops, [] if none was started); every pulled sample is kept (src.record),
% with a long inlet buffer so nothing is dropped between slurp phases.
RECORD_BUFFER_S = 600;                          % s: the longest gap between pulls kept
src = [];
kind = "off";
streamer = [];
if ~cfg.flow.enabled
    fprintf('Airflow sensor not used (cfg.flow.enabled = false): timed slurp animation.\n');
    return
end
standalone = kidsStandalone(cfg);
bufferS = flowInlet.BufferS;
if standalone
    bufferS = RECORD_BUFFER_S;
end
simulated = ~isempty(cfg.debug.simulateChild);   % a simulated child cannot breathe into the sensor
if ~simulated
    timeout = cfg.flow.timeout;
    if cfg.device.mock || standalone
        timeout = min(timeout, 2);
    end
    try
        src = flowInlet(cfg.markers.liblslDir, timeout, BufferS=bufferS);
        if standalone
            fprintf('Airflow stream "Flow" already running (on %s): using it, and leaving it running.\n', ...
                src.hostname);
        end
    catch err
        if standalone && strcmp(err.identifier, 'rrst:noFlowStream')
            try
                [src, streamer] = startStreamer(cfg, bufferS);
            catch err2
                if ~cfg.device.mock
                    rethrow(err2);
                end
                fprintf(2, '%s\n', err2.message);   % mock device: synthetic flow instead
            end
        elseif ~(cfg.device.mock && ismember(err.identifier, {'rrst:noFlowStream', 'rrst:noLiblsl'}))
            % the kids task also needs the timed animation chosen (validateKidsConfig)
            error(err.identifier, '%s', strrep(err.message, 'set cfg.flow.enabled = false', ...
                'set cfg.flow.enabled = false and cfg.flow.feedback = "none"'));
        end
    end
end
if isempty(src)
    src = kidsSimFlow('Clock', @GetSecs);
    src.record = standalone;
    kind = "simulated";
    fprintf(2, '\n*** SIMULATED FLOW: no airflow sensor, the breaths are synthetic. ***\n\n');
    return
end
src.record = standalone;
[ok, msg] = src.check(1);
fprintf('%s\n', msg);
if ~ok
    src.close();
    stopFlowStreamer(streamer);
    error('rrst:flowBad', '%s', msg);
end
kind = "live";
end

function [src, streamer] = startStreamer(cfg, bufferS)
% Standalone and no "Flow" stream: start flow_lsl.py hidden and wait for its stream.
fprintf('No "Flow" stream running: starting the airflow streamer flow_lsl.py.\n');
streamer = flowStreamer(cfg.flow.streamer, cfg.flow.streamerScript);
streamer.start();                   % rrst:noStreamer names the missing file and its cfg field
try
    src = flowInlet(cfg.markers.liblslDir, cfg.flow.timeout, BufferS=bufferS);
catch err
    why = streamer.lastLog(5);
    streamer.stop();
    if ~strcmp(err.identifier, 'rrst:noFlowStream')
        rethrow(err);
    end
    error('rrst:noFlowStream', ['Started flow_lsl.py, but no "Flow" stream appeared within ' ...
        '%g s. Its last output:\n%s\nCheck the SensorBridge (USB plugged in, LED on) and ' ...
        'close SEK-ControlCenter and the Physio Recorder, then start the task again.'], ...
        cfg.flow.timeout, why);
end
fprintf('Airflow stream "Flow" found.\n');
end

function stopFlowStreamer(streamer)
if ~isempty(streamer)
    streamer.stop();
end
end

function closeFlowSource(src, streamer)
if ~isempty(src) && ismethod(src, 'close')
    src.close();
end
stopFlowStreamer(streamer);
end
