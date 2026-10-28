function verified = slipTest(portName, nCycles)
%SLIPTEST Does closing onto the tube lose motor steps, or does the mechanism flex?
%   verified = slipTest("COM3", 2)
%
%   MOVES THE WEDGE. Run with the tube fitted and the user's go-ahead.
%   Calibrates, then repeats: open to 1600 steps, 'k' (seek the max endstop and
%   report the step count where it triggers, without resetting the count).
%     - Elastic flex: every 'k' reports about the calibrated MaxPosition.
%     - Lost steps:   'k' grows by the per-close loss on every cycle.
%   The wedge is parked open (1600 steps) at the end.

if nargin < 2, nCycles = 2; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'));

port = rrst.openPort(portName);
cleaner = onCleanup(@() delete(port));
dev = rrst.Device(port);
st = dev.status();

verified = NaN(1, nCycles);
try
    cal = dev.calibrate();
    dev.enable();
    fprintf('Calibrated MaxPosition %d\n', cal.maxPosition);
    for k = 1:nCycles
        dev.moveTo(1600);
        lines = dev.command("k", dev.CalibrationTimeout);
        tok = regexp(cellstr(lines), 'Position verified against Max endstop:\s*(-?\d+)', 'tokens', 'once');
        hit = find(~cellfun(@isempty, tok), 1);
        if isempty(hit)
            error('rrst:verifyFailed', 'No verified position in reply: %s', strjoin(lines, ' | '));
        end
        verified(k) = str2double(tok{hit}{1});
        fprintf('Cycle %d: max endstop triggered at %d (%+d vs calibration)\n', ...
            k, verified(k), verified(k) - cal.maxPosition);
    end
    dev.moveTo(1600);
catch err
    saveTranscript(root, dev, "sliptest", st.deviceId);
    rethrow(err);
end
saveTranscript(root, dev, "sliptest", st.deviceId);
end
