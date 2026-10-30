function tf = kidsStandalone(cfg)
%KIDSSTANDALONE True when the task records flow and markers itself (no Physio Recorder).
%   tf = kidsStandalone(cfg)   cfg.recording.mode == "standalone"; see kidsConfig.
tf = isfield(cfg, 'recording') && isfield(cfg.recording, 'mode') && ...
    string(cfg.recording.mode) == "standalone";
end
