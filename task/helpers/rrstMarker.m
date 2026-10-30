function out = rrstMarker(label, tEvent)
%RRSTMARKER Send a task event to the "RRST" Lab Streaming Layer marker stream.
%   rrstMarker('open', liblslDir)   create the outlet and push "RRST_ready"; clears the log
%   rrstMarker(label)               push label stamped now
%   rrstMarker(label, tEvent)       push label stamped at tEvent, a GetSecs time
%                                   (e.g. the onset returned by Screen('Flip'))
%   rrstMarker('close')             destroy the outlet (the log is kept)
%   tf = rrstMarker('recorded')     true when a recorder (any LSL inlet) is connected
%   T = rrstMarker('log')           every label pushed since the log was cleared, as a
%                                   table with t (GetSecs time) and label (string)
%   rrstMarker('clearLog')          empty the log (kidsOpenMarkers, at session start)
%
%   Until 'open' is called every push is a no-op for LSL, so the task runs without
%   LSL (cfg.markers.lsl = false) and in tests; it is still kept in the log, which
%   the standalone recording saves (kidsMain, result.markers). A recorder
%   (LabRecorder, the Physio Recorder app) only picks up the stream if it exists
%   when recording starts, so open it at task launch. GetSecs times are moved onto
%   the LSL clock with the offset between the two clocks measured at each push.

persistent lib outlet logT logLabel

if isempty(logT)
    logT = zeros(0, 1);
    logLabel = strings(0, 1);
end
out = false;
switch label
    case 'recorded'
        out = ~isempty(outlet) && outlet.have_consumers();
    case 'log'
        out = table(logT, logLabel, 'VariableNames', {'t', 'label'});
    case 'clearLog'
        logT = zeros(0, 1);
        logLabel = strings(0, 1);
    case 'open'
        if ~isempty(outlet)
            return
        end
        if ~isfolder(tEvent)
            error('rrst:noLiblsl', ['liblsl-Matlab not found at %s. Install it there ' ...
                '(github.com/labstreaminglayer/liblsl-Matlab releases), or set ' ...
                'cfg.markers.lsl = false to run without markers.'], tEvent);
        end
        addpath(tEvent, fullfile(tEvent, 'bin'));   % bin holds the mex files and lsl.dll
        lib = lsl_loadlib();
        info = lsl_streaminfo(lib, 'RRST', 'Markers', 1, 0, 'cf_string', 'rrst-task-markers');
        outlet = lsl_outlet(info);
        logT = zeros(0, 1);
        logLabel = strings(0, 1);
        fprintf('LSL marker stream "RRST" is open.\n');
        rrstMarker('RRST_ready');
    case 'close'
        outlet = [];
        lib = [];
    otherwise
        now = getSecsOrNaN();
        if nargin < 2
            tEvent = now;
        end
        logT(end + 1, 1) = tEvent;
        logLabel(end + 1, 1) = string(label);
        if isempty(outlet)
            return
        end
        outlet.push_sample({char(label)}, tEvent + (lsl_local_clock(lib) - now));
end
end

function t = getSecsOrNaN()
% GetSecs, or NaN where Psychtoolbox is not on the path (tests without an outlet)
try
    t = GetSecs;
catch
    t = NaN;
end
end
