function kp = kidsRecord(kp, level, response, info)
%KIDSRECORD Add one answered trial (response 1 = "the mouse pinched", 0 = "easy").
%   kp = kidsRecord(kp, level, response, info)   info from kidsNextLevel.
kp.PM = PAL_AMPM_updatePM(kp.PM, double(response), 'xIndex', info.xIndex);
kp.history(end + 1) = struct('level', level, 'response', double(response), 'isCatch', info.isCatch);
if ~info.isCatch
    kp.nPsiDone = kp.nPsiDone + 1;
end
kp.runningMax = max(kp.runningMax, level);
kp.k = kp.k + 1;
end
