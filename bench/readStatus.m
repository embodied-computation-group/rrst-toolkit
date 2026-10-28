function st = readStatus(portName)
%READSTATUS Bench step 1: read-only status of a real device. Nothing moves.
%   st = readStatus("COM5")
%
%   Sends only 's'. Prints the firmware version, device ID, calibration state and
%   tuning, and saves the raw reply to bench/captures/ so it can be compared with
%   tests/fixtures/status_calibrated.txt.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'));

port = rrst.openPort(portName);
cleaner = onCleanup(@() delete(port));
dev = rrst.Device(port);
st = dev.status();

fprintf('\nSoftware version: %s\nDevice ID:        %s\n', st.softwareVersion, st.deviceId);
fprintf('Calibrated: %d   Enabled: %d   Position: %g\n', st.calibrated, st.stepperEnabled, st.currentPosition);
fprintf('Speed %g steps/s, accel %g steps/s^2, %g microsteps, run current %g mA, hold %g %%, %s\n', ...
    st.speed, st.acceleration, st.microsteps, st.runCurrent, st.holdPercent, st.chopperMode);
fprintf('Retract: %g steps (%g mm)\n', st.retractSteps, st.retractMm);

outDir = fullfile(root, 'bench', 'captures');
if ~exist(outDir, 'dir'), mkdir(outDir); end
rx = dev.Transcript([dev.Transcript.direction] == "rx");
% Firmware older than 2026-10-07 does not report a device ID; name the file by firmware instead.
if strlength(st.deviceId) > 0
    tag = "device_" + st.deviceId;
else
    tag = "fw_" + extractBefore(st.softwareVersion + " ", " ");
end
fname = fullfile(outDir, sprintf('status__%s__%s.txt', tag, datestr(now, 'yyyy-mm-dd_HHMMSS')));
% read(...,'char') yields one char per byte, so ISO-8859-1 writes the device's bytes back unchanged.
fid = fopen(fname, 'w', 'n', 'ISO-8859-1');
fwrite(fid, char(rx(end).text));
fclose(fid);
fprintf('Raw reply saved to %s\n', fname);
end
