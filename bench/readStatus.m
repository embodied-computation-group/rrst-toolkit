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
fname = fullfile(outDir, sprintf('status__device_%s__%s.txt', st.deviceId, datestr(now, 'yyyy-mm-dd_HHMMSS')));
fid = fopen(fname, 'w', 'n', 'UTF-8');
fwrite(fid, char(rx(end).text));
fclose(fid);
fprintf('Raw reply saved to %s\n', fname);
end
