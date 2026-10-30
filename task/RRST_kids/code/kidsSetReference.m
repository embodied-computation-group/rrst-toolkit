function [msg, found] = kidsSetReference(fl, slurps)
%KIDSSETREFERENCE Set the child's reference slurp from the free slurps.
%   [msg, found] = kidsSetReference(fl, slurps)
%   fl      kidsFlow
%   slurps  the free slurps' records (kidsFlow.stop), or []
%   msg     the console line for the experimenter
%   found   false when no slurp of type end or weak was seen: the reference stays
%
%   The reference is the median volume of every slurp of type end or weak
%   (kidsReferenceSlurps; plan section 3.2); kidsFlow clamps it to [0.15, 2] L.
s = kidsReferenceSlurps(slurps);
found = ~isempty(s);
if ~found
    [minL, fullL] = fl.setReference([]);
    msg = sprintf(['No free slurp detected: the reference stays at %.2f L. Belly full at ' ...
        '%.2f L; a slurp counts above %.2f L. Check the mouthpiece.'], fl.refVolume, fullL, minL);
else
    [minL, fullL] = fl.setReference([s.volumeL]);
    msg = sprintf(['Reference slurp %.2f L (median of %d free slurps: %.2f L), peak %.0f slm. ' ...
        'Belly full at %.2f L; a slurp counts above %.2f L.'], ...
        fl.refVolume, numel(s), median([s.volumeL]), median([s.peakSlm]), fullL, minL);
end
end
