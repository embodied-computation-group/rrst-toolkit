function closeResp(respDevice)
%closeResp Disables the stepper driver and closes the serial connection.
%   Input:
%       respDevice       serialport object returned by initResp() - must
%                        be a real connection, not the NaN initResp
%                        returns when the port itself never opened
%
% Sends 'd' (disable) so the motor doesn't keep holding torque between
% sessions - nothing in the current task ever does this. Then releases
% the serial port properly: fclose('all') does NOT close a serialport
% object (it only closes raw fopen file handles), so without an
% explicit delete() the port stays open, referenced by whatever
% variable holds it, until something else clears that variable or
% MATLAB exits.
%
% delete(respDevice) always runs, even if the disable command itself
% hits a communication error - releasing the port is this function's
% one job, and it must not be skipped just because the device stopped
% answering on the way out.

if ~isSerialportHandle(respDevice)
    disp('closeResp: no valid serial connection to close.');
    return
end

DISABLE_TIMEOUT_S = 2;

try
    writeline(respDevice, 'd');
    % cmd2_DisableStepper's response ("\nStepper disabled...") is
    % printed with a leading embedded newline, which readline() hands
    % back as its own empty "line" before the real text arrives - a
    % single read would just capture that blank line and never see the
    % actual acknowledgment. Loop within a small bounded budget instead,
    % skipping empty lines, so the port isn't closed while a reply is
    % still in flight but the real text still gets captured.
    responseLine = "";
    startTime = tic;
    while toc(startTime) < DISABLE_TIMEOUT_S
        remaining = DISABLE_TIMEOUT_S - toc(startTime);
        respDevice.Timeout = max(remaining, 0.1);
        line = readline(respDevice);
        if strlength(line) > 0
            responseLine = line;
            break
        end
    end
    if strlength(responseLine) > 0
        disp(['Device response: ', char(responseLine)]);
    else
        disp('No response received before closing.');
    end
catch
    disp('Serial communication error while disabling - closing the port anyway.');
end
delete(respDevice);
disp('Device disabled and serial port closed.');
end
