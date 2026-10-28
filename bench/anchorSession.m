function anchorSession(portName, cmdFile, logFile, idleLimitS)
%ANCHORSESSION Keep a calibrated device connected and take moves from a command file.
%   anchorSession("COM3", cmdFile, logFile)
%
%   MOVES THE WEDGE. For measuring the stimulus anchors at the bench, with a person
%   at the device saying when the wedge touches the tube and when breathing becomes
%   barely possible. Calibrates once, then polls cmdFile for new lines:
%     goto <steps>   absolute move, checked against the firmware reply, timed
%     verify         'k': seek the max endstop, report the count (no reset)
%     status         's'
%     note <text>    write a note into the log (e.g. "contact", "barely possible")
%     quit           park open (1600) and exit
%   Every result is appended to logFile. After idleLimitS without a command the
%   wedge is parked open and the session ends.

if nargin < 4, idleLimitS = 1800; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'device'));

port = rrst.openPort(portName);
cleaner = onCleanup(@() delete(port));
dev = rrst.Device(port);
st = dev.status();
say(logFile, 'device %s, firmware %s', st.deviceId, st.softwareVersion);

nDone = numel(readCommands(cmdFile));   % ignore anything already in the file
try
    cal = dev.calibrate();
    dev.enable();
    say(logFile, 'calibrated: MaxPosition %d, computed first contact %d', cal.maxPosition, cal.firstContact);
    dev.moveTo(1600);
    say(logFile, 'READY at 1600');

    lastCmd = tic;
    while toc(lastCmd) < idleLimitS
        cmds = readCommands(cmdFile);
        if numel(cmds) <= nDone
            pause(0.2);
            continue
        end
        for k = nDone + 1:numel(cmds)
            c = strtrim(cmds(k));
            nDone = k;
            lastCmd = tic;
            parts = split(c);
            switch lower(parts(1))
                case "goto"
                    target = str2double(parts(2));
                    try
                        mv = dev.moveTo(target);
                        say(logFile, 'goto %d ok (%.2f s, %.2f mm from max)%s', target, mv.elapsed, ...
                            (cal.maxPosition - target) / 1600, warnText(mv.warnings));
                    catch err
                        say(logFile, 'goto %s FAILED: %s', parts(2), err.message);
                    end
                case "verify"
                    lines = dev.command("k", dev.CalibrationTimeout);
                    say(logFile, 'verify: %s', strjoin(lines(2:end), ' | '));
                case "status"
                    s = dev.status();
                    say(logFile, 'status: position %g, enabled %d, calibrated %d', ...
                        s.currentPosition, s.stepperEnabled, s.calibrated);
                case "note"
                    say(logFile, 'NOTE %s', strjoin(parts(2:end), ' '));
                case "quit"
                    dev.moveTo(1600);
                    say(logFile, 'parked at 1600; session ended');
                    saveTranscript(root, dev, "anchors", st.deviceId);
                    return
                otherwise
                    say(logFile, 'unknown command: %s', c);
            end
        end
    end
    dev.moveTo(1600);
    say(logFile, 'idle for %d s: parked at 1600; session ended', idleLimitS);
catch err
    say(logFile, 'SESSION ERROR: %s', err.message);
end
saveTranscript(root, dev, "anchors", st.deviceId);
end

function cmds = readCommands(cmdFile)
if ~isfile(cmdFile)
    cmds = strings(0, 1);
    return
end
cmds = splitlines(string(fileread(cmdFile)));
cmds = cmds(strlength(strtrim(cmds)) > 0);
end

function t = warnText(w)
if isempty(w), t = ''; else, t = [' WARN: ' char(strjoin(w, ' | '))]; end
end

function say(logFile, fmt, varargin)
fid = fopen(logFile, 'a');
fprintf(fid, '%s  %s\n', datestr(now, 'HH:MM:SS.FFF'), sprintf(fmt, varargin{:}));
fclose(fid);
end
