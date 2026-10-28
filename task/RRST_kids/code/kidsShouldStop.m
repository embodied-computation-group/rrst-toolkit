function [stop, why] = kidsShouldStop(kp, cfg)
%KIDSSHOULDSTOP True when the run is complete, precise enough, or out of repeats.
%   [stop, why] = kidsShouldStop(kp, cfg)   why: "complete", "precise", "repeats" or "".
stop = true;
if kp.k > numel(kp.schedule)
    why = "complete";
elseif kp.nPsiDone >= cfg.child.stopMinTrials && kp.PM.seThreshold(end) < cfg.child.stopSE
    why = "precise";
elseif kp.nRepeats > cfg.child.maxRepeats
    why = "repeats";
else
    stop = false;
    why = "";
end
end
