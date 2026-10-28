function f = kidsFlags(kp, cfg)
%KIDSFLAGS Response-bias checks on the answered trials.
%   f = kidsFlags(kp, cfg)
%   f.faRate       "yes" on catch trials (level 0)
%   f.hitRateHigh  "yes" on trials at or above cfg.child.flagHighLevel
%   f.unusable     faRate > flagFAmax or hitRateHigh < flagHitMin; f.reason says why
h = kp.history;
isCatch = [h.isCatch];
lev = [h.level];
resp = [h.response];
f.nCatch = nnz(isCatch);
f.faRate = mean(resp(isCatch));
high = ~isCatch & lev >= cfg.child.flagHighLevel;
f.nHigh = nnz(high);
f.hitRateHigh = mean(resp(high));
reasons = strings(0);
if f.nCatch > 0 && f.faRate > cfg.child.flagFAmax
    reasons(end + 1) = sprintf('false alarms %.0f %% on catch trials', 100 * f.faRate);
end
if f.nHigh > 0 && f.hitRateHigh < cfg.child.flagHitMin
    reasons(end + 1) = sprintf('only %.0f %% "yes" at %g %% and above', 100 * f.hitRateHigh, cfg.child.flagHighLevel);
end
f.unusable = ~isempty(reasons);
f.reason = strjoin(reasons, '; ');
end
