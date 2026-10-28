function init = recalibrateResp(respDevice)
%recalibrateResp Re-runs calibration on an already-open connection,
% confirming success from the firmware's own response - the same
% confirm-via-response logic initResp.m uses for the initial
% calibration (see waitForCalibration.m), factored out so both share
% exactly one implementation.
%   Input:
%       respDevice       serialport object returned by initResp(),
%                        already open - this function does not open or
%                        close any port itself
%   Output:
%       init             1 if calibration was confirmed successful by
%                         the firmware's own response, 0 otherwise

if ~isSerialportHandle(respDevice)
    disp('recalibrateResp: no valid serial connection.');
    init = 0;
    return
end

init = waitForCalibration(respDevice);
end
