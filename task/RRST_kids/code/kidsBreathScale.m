function b = kidsBreathScale(volumeL, refVolumeL, fraction)
%KIDSBREATHSCALE Belly fill (0 to 1) from the volume of the current slurp.
%   b = kidsBreathScale(volumeL, refVolumeL, fraction)
%
%   b = min(volumeL / (fraction * refVolumeL), 1), and 0 for a non-positive volume.
%   refVolumeL is the child's reference slurp volume (L), fraction is
%   cfg.flow.bellyFraction. The belly saturates at a low fraction of the reference
%   so that loaded and unloaded slurps both fill it: the picture must not show the
%   level (plan docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, section 1).
%   Errors with rrst:outOfRange for a non-positive reference or fraction.
if ~(isscalar(refVolumeL) && isnumeric(refVolumeL) && isfinite(refVolumeL) && refVolumeL > 0)
    error('rrst:outOfRange', 'Reference volume must be a positive number of litres; got %s.', ...
        mat2str(refVolumeL));
end
if ~(isscalar(fraction) && isnumeric(fraction) && isfinite(fraction) && fraction > 0)
    error('rrst:outOfRange', 'Belly fraction must be positive; got %s.', mat2str(fraction));
end
b = min(max(volumeL, 0) ./ (fraction * refVolumeL), 1);
end
