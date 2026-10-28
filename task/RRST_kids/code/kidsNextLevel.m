function [level, info] = kidsNextLevel(kp, cfg)
%KIDSNEXTLEVEL Level for the next trial: catch, forced start, or Psi within the limits.
%   [level, info] = kidsNextLevel(kp, cfg)
%   info.isCatch, info.xIndex (index in cfg.psi.stimRange, for PAL_AMPM_updatePM),
%   info.proposed (what Psi asked for), info.limited (true if cap or ramp lowered it).
grid = cfg.psi.stimRange;
info.isCatch = kp.schedule(kp.k);
info.proposed = kp.PM.xCurrent;
if info.isCatch
    level = 0;
elseif kp.nPsiDone == 0
    level = cfg.child.startLevel;
else
    ceiling = min(cfg.child.hardCap, kp.runningMax + cfg.child.rampMax);
    level = min(kp.PM.xCurrent, ceiling);
    level = max(grid(grid <= level));      % snap down onto the grid
end
info.limited = ~info.isCatch && kp.nPsiDone > 0 && level < info.proposed;
info.xIndex = find(grid == level, 1);
end
