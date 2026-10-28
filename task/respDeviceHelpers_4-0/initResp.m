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

try
    respDevice = serialport(sPort, sBaudRate);
catch
    respDevice = NaN;
    init = 0;
    disp('Serial port initialization failed.');
    return
end
disp('Serial port initialization successful.');

init = waitForCalibration(respDevice);
end
