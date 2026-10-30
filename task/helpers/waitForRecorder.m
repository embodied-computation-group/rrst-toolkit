function waitForRecorder()
%WAITFORRECORDER Hold the session until a recorder receives the RRST markers.
%   Called before calibration when cfg.markers.requireRecorder is true, so a
%   session can't run with the physiology recorder never started. A recorder
%   counts once it has connected to the "RRST" stream (LabRecorder does so
%   when recording starts). Ctrl+C stops the task.

if rrstMarker('recorded')
    fprintf('Recorder connected to the RRST markers.\n');
    return
end
fprintf(2, ['\n*** NOTHING IS RECORDING. ***\n' ...
    'Click Start recording in the Physio Recorder (or start LabRecorder) now.\n' ...
    'The task continues by itself once the recording has started. ' ...
    '(Ctrl+C stops the task.)\n']);
while ~rrstMarker('recorded')
    pause(0.5);
end
fprintf('Recorder connected. Continuing.\n');
end
