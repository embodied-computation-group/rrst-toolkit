function stim = flowLevels(portName, levels)
%FLOWLEVELS Hold the wedge at fixed levels while the operator breathes through the circuit.
%   flowLevels("COM7")                    levels 0 25 50 75 95 (percent of the device range)
%   flowLevels("COM7", [25 50 75 95])
%
%   MOVES THE WEDGE: calibration (closes fully, then opens), then each level in
%   turn, then park open. Run only with the user's go-ahead.
%
%   For checking the airflow sensor against the obstruction. Start the "Flow"
%   LSL stream and a recorder for Flow + RRST first. At each level the console
%   says when to breathe; press Enter when done. Markers on the "RRST" stream:
%   flowlevels_start, level_<x>_ready (move confirmed), level_<x>_done (Enter),
%   flowlevels_end. Levels are in percent: 0 = wedge just touching the tube,
%   100 = barely possible to inhale (the device record's anchors).

if nargin < 2, levels = [0 25 50 75 95]; end

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'), fullfile(root, 'task', 'helpers'), ...
    fullfile(root, 'task', 'RRST_2-0', 'config'));
cfg = pilotConfig();

rrstMarker('open', cfg.markers.liblslDir);
closeMarkers = onCleanup(@() rrstMarker('close'));

port = rrst.openPort(portName);
closePort = onCleanup(@() delete(port));
dev = rrst.Device(port);
st = dev.status();
rec = rrst.loadDeviceRecord(st.deviceId, cfg.devicesDir);
stim = rrst.Stimulator(dev, rec, 'Unit', "percent", 'RestRange', cfg.stim.restRange, ...
    'CalibrationTolerance', cfg.stim.calibrationTolerance, 'Motion', cfg.device.motion);
stim.validateLevels(levels);

input(sprintf(['Device %s. Calibration runs with the tube %s, as in the device record.\n' ...
    'Start the recorder now if it is not running. Press Enter to calibrate...'], ...
    st.deviceId, erase(string(rec.anchors.calibrationCondition), "tube ")));
try
    stim.calibrate();
    rrstMarker('flowlevels_start');
    for x = levels
        stim.present(x);
        rrstMarker(sprintf('level_%g_ready', x));
        input(sprintf('\nWedge at %g %%. Breathe in through the mouthpiece a few times, then press Enter...', x));
        rrstMarker(sprintf('level_%g_done', x));
    end
    rrstMarker('flowlevels_end');
    stim.park();
catch err
    try
        stim.park();
    catch
    end
    saveTranscript(root, dev, 'flowlevels', st.deviceId);
    rethrow(err);
end
saveTranscript(root, dev, 'flowlevels', st.deviceId);
fprintf('Done. Wedge parked open.\n');
end
