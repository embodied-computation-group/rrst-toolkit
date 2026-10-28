function kidsCheckLevel(level, cfg)
%KIDSCHECKLEVEL Last check before a level is sent to the device: never above the cap.
%   kidsCheckLevel(level, cfg)   errors with rrst:kidsCap otherwise.
if ~(isscalar(level) && isfinite(level) && level >= 0 && level <= cfg.child.hardCap)
    error('rrst:kidsCap', 'Level %s refused: the child cap is %g %% of the adult scale.', ...
        mat2str(level), cfg.child.hardCap);
end
end
