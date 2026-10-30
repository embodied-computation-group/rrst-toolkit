function r = kidsReferenceSlurps(slurps)
%KIDSREFERENCESLURPS The free slurps that set the child's reference slurp.
%   r = kidsReferenceSlurps(slurps)   slurps: kidsFlow records (struct array with a
%   type field), or []. r: those of type "end" or "weak", in order.
%
%   Before the reference exists a slurp counts only from 25 % of the 0.6 L default,
%   so a small child's free slurps can all be "weak"; they are still real slurps and
%   set the reference. "overlong" (a leak or draught) and "interrupted" (cut off by
%   Space or Esc) are not slurps of known size and are left out. Counting afterwards
%   uses the new reference and the absolute floor cfg.flow.minVolumeL (kidsFlow).
if isempty(slurps)
    r = slurps;
    return
end
r = slurps(ismember([slurps.type], ["end" "weak"]));
end
