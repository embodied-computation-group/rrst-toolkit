function [init, respDevice] = initResp(sPort, sBaudRate)
%initResp Opens the serial connection and calibrates the device,
% confirming success from the firmware's own response instead of
% guessing how long it takes.
%
%   Input:
%       sPort       serial port, e.g. "COM5" (windows)
%       sBaudRate   device baud rate (9600)
%   Output:
%       init        1 if the port opened AND calibration was confirmed
%                    successful by the firmware's own response, 0 otherwise
%       respDevice  device object handle (valid even if init is 0, as
%                   long as the port itself opened - the caller can
%                   retry calibration without reopening the port)
%
% Builds on respDeviceHelpers_3-0/setupResp.m and calibrateResp.m
% (Niia Nikolova).

CALIBRATION_TIMEOUT_S = 120;   % generous - two precise endstop seeks,
                                % each with its own slow re-approach phase

try
    respDevice = serialport(sPort, sBaudRate);
catch
    respDevice = NaN;
    init = 0;
    disp('Serial port initialization failed.');
    return
end
disp('Serial port initialization successful.');

init = 0;
try
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
