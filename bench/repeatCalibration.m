function maxPos = repeatCalibration(portName, n, label)
%REPEATCALIBRATION Calibrate n times in one connection and report each MaxPosition.
%   maxPos = repeatCalibration("COM3", 2, "tube-in")
%
%   MOVES THE WEDGE: each run goes fully open, then fully closed. The wedge is
%   parked open (1600 steps) at the end. Run only with the user's go-ahead.
%   The spread of MaxPosition shows calibration repeatability; comparing labels
%   (tube in vs out) shows whether the tube makes the motor lose steps.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'));

port = rrst.openPort(portName);
cleaner = onCleanup(@() delete(port));
dev = rrst.Device(port);
st = dev.status();

maxPos = NaN(1, n);
try
    for k = 1:n
        cal = dev.calibrate();
        maxPos(k) = cal.maxPosition;
        fprintf('%s run %d: MaxPosition %d (previous saved %g)\n', label, k, cal.maxPosition, cal.previousSaved);
    end
    dev.enable();
    dev.moveTo(1600);
catch err
    saveTranscript(root, dev, "repeat-" + label, st.deviceId);
    rethrow(err);
end
fprintf('%s: range %d steps (%.2f mm at 1600 steps/mm)\n', label, range(maxPos), range(maxPos) / 1600);
saveTranscript(root, dev, "repeat-" + label, st.deviceId);
end
