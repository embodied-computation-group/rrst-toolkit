function init = waitForCalibration(respDevice)
%waitForCalibration Sends 'c' and blocks until the firmware confirms
% calibration succeeded or failed, instead of guessing how long it
% takes. Shared by initResp.m and recalibrateResp.m so this logic
% (including how a benign leading blank line is told apart from a
% real timeout) lives in exactly one place.
%   Input:
%       respDevice       serialport object, already open
%   Output:
%       init             1 if calibration was confirmed successful by
%                         the firmware's own response, 0 otherwise

CALIBRATION_TIMEOUT_S = 120;   % generous - two precise endstop seeks,
                                % each with its own slow re-approach phase

init = 0;
try
    % Discard any unread bytes left over from a previous command before
    % sending 'c' - this function is also called mid-session on a
    % long-lived, already-in-use port (recalibrateResp.m's whole
    % purpose), where a prior command's reply might not have been fully
    % drained (e.g. a caller's own read timed out and gave up while the
    % firmware's actual response was still in flight). Without this, the
    % very first readline() below could consume that stale text instead
    % of this calibration's real response - and if it happened to start
    % with "ERROR:", it would misreport a phantom failure before the
    % firmware had even processed this 'c'.
    flush(respDevice, "input");
    writeline(respDevice, 'c');
catch
    disp('Serial communication error - could not send calibrate command.');
    return
end

startTime = tic;
while toc(startTime) < CALIBRATION_TIMEOUT_S
    remaining = CALIBRATION_TIMEOUT_S - toc(startTime);
    respDevice.Timeout = max(remaining, 0.1);
    try
        line = readline(respDevice);
    catch
        disp('Serial communication error during calibration.');
        break
    end
    % An empty line here isn't necessarily a timeout - cmd3_Calibrate's
    % first response ("\nStarting calibration...") is printed with a
    % leading embedded newline, which readline() hands back as its own
    % empty "line" before the real text ever arrives. Skip it and keep
    % reading - the while condition's own elapsed-time check is what
    % actually bounds how long this can run, not this per-line result.
    if startsWith(line, 'Max Endstop found')
        disp(['Calibration successful: ', char(line)]);
        init = 1;
        respDevice.Timeout = 10;   % restore the default before handing the port back
        return
    elseif startsWith(line, 'ERROR:')
        disp(['Calibration failed: ', char(line)]);
        respDevice.Timeout = 10;
        return
    end
end
respDevice.Timeout = 10;
disp('Calibration timed out - no response from device.');
end
