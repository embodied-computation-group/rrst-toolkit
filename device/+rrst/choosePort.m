function port = choosePort(requested, available)
%CHOOSEPORT Pick the device's serial port without guessing.
%   port = rrst.choosePort("COM3", serialportlist("available"))
%   port = rrst.choosePort("auto", serialportlist("available"))
%
%   "auto" is accepted only when exactly one port is available. With several,
%   the operator must name one in the configuration.

requested = string(requested);
available = string(available);
if requested == "auto"
    if isempty(available)
        error('rrst:noPort', 'No serial port is available. Is the device plugged in?');
    elseif numel(available) > 1
        error('rrst:ambiguousPort', ...
            'Several serial ports are available (%s). Set cfg.device.port to the device''s port.', ...
            strjoin(available, ', '));
    end
    port = available(1);
elseif any(available == requested)
    port = requested;
else
    error('rrst:noPort', 'Port %s is not available (available: %s).', requested, ...
        strjoin([available, "none"], ', '));
end
end
