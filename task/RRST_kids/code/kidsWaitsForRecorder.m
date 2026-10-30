function tf = kidsWaitsForRecorder(cfg)
%KIDSWAITSFORRECORDER True when the session must hold until a recorder receives the markers.
%   tf = kidsWaitsForRecorder(cfg)
%   Only with markers on and cfg.markers.requireRecorder, and never for a mock device
%   (cfg.device.mock) or a simulated child (cfg.debug.simulateChild): those are tests
%   and must run without the Physio Recorder. Never in standalone recording
%   (kidsStandalone): the task records flow and markers itself.
simulated = isfield(cfg, 'debug') && isfield(cfg.debug, 'simulateChild') && ~isempty(cfg.debug.simulateChild);
tf = cfg.markers.lsl && cfg.markers.requireRecorder && ~cfg.device.mock && ~simulated && ...
    ~kidsStandalone(cfg);
end
