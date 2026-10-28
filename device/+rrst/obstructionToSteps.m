function steps = obstructionToSteps(value, scaleMax, zeroStep, fullStep)
%OBSTRUCTIONTOSTEPS Map an obstruction value onto a motor step position.
%   steps = rrst.obstructionToSteps(value, scaleMax, zeroStep, fullStep)
%
%   value     requested obstruction, in [0, scaleMax] (mm or percent)
%   scaleMax  top of the stimulus scale, e.g. 17 or 18 (mm) or 100 (percent)
%   zeroStep  step position of the 0 anchor (wedge just touching the tube)
%   fullStep  step position of the full-scale anchor (barely possible to inhale)
%
%   The mapping is linear and rounded to the nearest step. A value outside
%   [0, scaleMax] raises 'rrst:outOfRange' instead of being clipped: the original
%   scale2motorstep clipped silently, which sent the ITI rest (20-80 on a 0-17 mm
%   scale) to full obstruction.

if ~(isscalar(scaleMax) && isfinite(scaleMax) && scaleMax > 0 ...
        && isscalar(zeroStep) && isfinite(zeroStep) ...
        && isscalar(fullStep) && isfinite(fullStep) && zeroStep < fullStep)
    error('rrst:badMap', ...
        'Invalid step map: need scaleMax > 0 and finite zeroStep < fullStep (got %g, %g, %g).', ...
        scaleMax, zeroStep, fullStep);
end
if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0 && value <= scaleMax)
    error('rrst:outOfRange', ...
        'Obstruction value must be a finite scalar in [0, %g]; got %s.', scaleMax, mat2str(value));
end

steps = round(zeroStep + (value / scaleMax) * (fullStep - zeroStep));
end
