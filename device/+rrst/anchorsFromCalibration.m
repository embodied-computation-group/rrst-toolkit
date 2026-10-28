function [zeroStep, fullStep] = anchorsFromCalibration(maxPosition, zeroOffset, fullOffset)
%ANCHORSFROMCALIBRATION Step positions of the stimulus anchors for this calibration.
%   [zeroStep, fullStep] = rrst.anchorsFromCalibration(maxPosition, zeroOffset, fullOffset)
%
%   maxPosition  MaxPosition reported by the firmware after 'c' (steps from the min
%                endstop to the max endstop)
%   zeroOffset   steps back from MaxPosition to the 0 anchor (wedge just touching)
%   fullOffset   steps back from MaxPosition to the full-scale anchor
%
%   The offsets are measured once per device at the bench. Storing them relative to
%   the max endstop keeps the anchors at the same physical place when MaxPosition
%   drifts between calibrations.

if ~(isscalar(maxPosition) && isfinite(maxPosition) && maxPosition > 0 ...
        && isscalar(zeroOffset) && isfinite(zeroOffset) ...
        && isscalar(fullOffset) && isfinite(fullOffset) ...
        && fullOffset >= 0 && zeroOffset > fullOffset && zeroOffset <= maxPosition)
    error('rrst:badAnchors', ...
        ['Invalid anchors: need 0 <= fullOffset < zeroOffset <= maxPosition ' ...
         '(got maxPosition %g, zeroOffset %g, fullOffset %g).'], ...
        maxPosition, zeroOffset, fullOffset);
end

zeroStep = maxPosition - zeroOffset;
fullStep = maxPosition - fullOffset;
end
