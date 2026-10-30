function f = kidsFlags(kp, cfg)
%KIDSFLAGS Response-bias checks on the answered trials.
%   f = kidsFlags(kp, cfg)
%   f.faRate       "yes" on catch trials (level 0)
%   f.hitRateHigh  "yes" on trials at or above cfg.child.flagHighLevel (reported only)
%   f.unusable     faRate > flagFAmax; f.reason says why. The hit-rate rule was dropped
%                  on 2026-10-30 (Micah): a child whose threshold is near or above
%                  flagHighLevel says "yes" to few trials there, which is expected.
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
f.unusable = ~isempty(reasons);
f.reason = strjoin(reasons, '; ');
end
