function tf = rrstMarker(label, tEvent)
%RRSTMARKER Send a task event to the "RRST" Lab Streaming Layer marker stream.
%   rrstMarker('open', liblslDir)   create the outlet and push "RRST_ready"
%   rrstMarker(label)               push label stamped now
%   rrstMarker(label, tEvent)       push label stamped at tEvent, a GetSecs time
%                                   (e.g. the onset returned by Screen('Flip'))
%   rrstMarker('close')             destroy the outlet
%   tf = rrstMarker('recorded')     true when a recorder (any LSL inlet) is connected
%
%   Until 'open' is called every push is a no-op, so the task runs without LSL
%   (cfg.markers.lsl = false) and in tests. A recorder (LabRecorder, the Physio
%   Recorder app) only picks up the stream if it exists when recording starts,
%   so open it at task launch. GetSecs times are moved onto the LSL clock with
%   the offset between the two clocks measured at each push.

persistent lib outlet

tf = false;
switch label
    case 'recorded'
        tf = ~isempty(outlet) && outlet.have_consumers();
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
        fprintf('LSL marker stream "RRST" is open.\n');
        rrstMarker('RRST_ready');
    case 'close'
        outlet = [];
        lib = [];
    otherwise
        if isempty(outlet)
            return
        end
        now = GetSecs;
        if nargin < 2
            tEvent = now;
        end
        outlet.push_sample({char(label)}, tEvent + (lsl_local_clock(lib) - now));
end
end
