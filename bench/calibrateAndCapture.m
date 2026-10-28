function cal = calibrateAndCapture(portName)
%CALIBRATEANDCAPTURE Bench step 2: calibrate a real device and save every reply.
%   cal = calibrateAndCapture("COM3")
%
%   MOVES THE WEDGE: fully open (min endstop), then fully closed (max endstop).
%   Run only with the user's go-ahead, with no tube fitted.
%
%   Sends c, e, s, x (status and driver diagnostics are read-only). The firmware
%   disables the driver when the port closes, so the calibration does not outlive
%   this function. The transcript is saved to bench/captures/.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'));

port = rrst.openPort(portName);
cleaner = onCleanup(@() delete(port));
dev = rrst.Device(port);

before = dev.status();
fprintf('Device %s, firmware %s\n', before.deviceId, before.softwareVersion);

t0 = tic;
try
    cal = dev.calibrate();
    tCal = toc(t0);
    dev.enable();
    after = dev.status();
    dev.command("x", dev.DefaultTimeout);
catch err
    saveTranscript(root, dev, before.deviceId);
    rethrow(err);
end

fprintf('Calibration took %.1f s\n', tCal);
fprintf('MaxPosition %d steps, first contact %d steps (retract %g mm)\n', ...
    cal.maxPosition, cal.firstContact, after.retractMm);
fprintf('Previous saved max: %g\n', cal.previousSaved);
fprintf('After: calibrated %d, enabled %d, position %g\n', ...
    after.calibrated, after.stepperEnabled, after.currentPosition);
saveTranscript(root, dev, before.deviceId);
end

function saveTranscript(root, dev, deviceId)
outDir = fullfile(root, 'bench', 'captures');
if ~exist(outDir, 'dir'), mkdir(outDir); end
fname = fullfile(outDir, sprintf('calibrate__device_%s__%s.txt', deviceId, datestr(now, 'yyyy-mm-dd_HHMMSS')));
% read(...,'char') yields one char per byte, so ISO-8859-1 writes the device's bytes back unchanged.
fid = fopen(fname, 'w', 'n', 'ISO-8859-1');
for k = 1:numel(dev.Transcript)
    tr = dev.Transcript(k);
    fprintf(fid, '===== %.3f s  %s\n', tr.t, tr.direction);
    fwrite(fid, char(tr.text));
    fprintf(fid, '\n');
end
fclose(fid);
fprintf('Transcript saved to %s\n', fname);
end
