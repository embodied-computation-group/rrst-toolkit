function mv = openForSetup(portName, target)
%OPENFORSETUP Calibrate, then park the wedge open so a tube can be fitted.
%   mv = openForSetup("COM3")          % park 1 mm from the min endstop
%   mv = openForSetup("COM3", target)  % park at another step position
%
%   MOVES THE WEDGE: calibration runs open, then closed, then the wedge moves to
%   target. Run only with the user's go-ahead. The firmware disables the driver
%   when the port closes; the leadscrew holds the wedge where it stopped.

if nargin < 2, target = 1600; end   % 1 mm at 1600 steps/mm

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'));

port = rrst.openPort(portName);
cleaner = onCleanup(@() delete(port));
dev = rrst.Device(port);
st = dev.status();

try
    cal = dev.calibrate();
    dev.enable();
    t0 = tic;
    mv = dev.moveTo(target);
    tMove = toc(t0);
catch err
    saveTranscript(root, dev, 'open', st.deviceId);
    rethrow(err);
end

fprintf('MaxPosition %d. Moved %d -> %d steps in %.2f s (command to confirmed reply).\n', ...
    cal.maxPosition, cal.maxPosition, target, tMove);
if ~isempty(mv.warnings)
    fprintf('Warnings: %s\n', strjoin(mv.warnings, ' | '));
end
saveTranscript(root, dev, 'open', st.deviceId);
end
