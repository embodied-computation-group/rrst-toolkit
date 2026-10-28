function [moved, currPosition] = moveResp(respDevice, newPosition, unitscale)
%moveResp Moves respiroception device to desired position, confirming
% success from the firmware's own response instead of firing and
% forgetting.
%   Input:
%       respDevice       serialport object returned by initResp()
%       newPosition      target position, e.g. "50" (0-100)
%       unitscale        units to scale. 0 percent (0-100), 1 mm (0-17)
%   Output:
%       moved            1 if the firmware confirmed "Move complete.",
%                        0 on any error response, invalid input, comm
%                        error, or timeout
%       currPosition     newPosition (the caller's intended target) if
%                        moved, NaN otherwise - the firmware's "Move
%                        complete." response doesn't itself report a
%                        position
%
% Builds on respDeviceHelpers_3-0/moveResp.m (Niia Nikolova).

MOVE_TIMEOUT_S = 30;   % generous - a worst-case move across the full
                        % calibrated range at the compiled-in speed/
                        % acceleration takes a few seconds

moved = 0;
currPosition = NaN;

try
    motorStepVal = scale2motorstep(newPosition, unitscale);
    writeline(respDevice, 'a');
    writeline(respDevice, sprintf('%d', motorStepVal));
catch
    disp('Could not send move command (invalid input or communication error).');
    return
end

startTime = tic;
while toc(startTime) < MOVE_TIMEOUT_S
    remaining = MOVE_TIMEOUT_S - toc(startTime);
    respDevice.Timeout = max(remaining, 0.1);
    try
        line = readline(respDevice);
    catch
        disp('Serial communication error while waiting for move to complete.');
        respDevice.Timeout = 10;
        return
    end
    % An empty line here isn't necessarily a timeout - several firmware
    % responses (e.g. "Enter absolute target position...") are printed
    % with a leading embedded newline, which readline() hands back as
    % its own empty "line" before the real text ever arrives. Skip it
    % and keep reading - the while condition's own elapsed-time check
    % is what actually bounds how long this can run, not this per-line
    % result.
    if startsWith(line, 'Move complete.')
        disp('Move complete.');
        moved = 1;
        currPosition = newPosition;
        respDevice.Timeout = 10;
        return
    elseif startsWith(line, 'Error', 'IgnoreCase', true)
        disp(['Move failed: ', char(line)]);
        respDevice.Timeout = 10;
        return
    end
end
respDevice.Timeout = 10;
disp('Move timed out - no response from device.');
end
