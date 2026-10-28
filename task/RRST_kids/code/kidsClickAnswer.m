function answer = kidsClickAnswer(x, W)
%KIDSCLICKANSWER Answer for a click at horizontal position x on a window W pixels wide.
%   answer = kidsClickAnswer(x, W)
%   "no" (easy, drawn left), "yes" (squishy, drawn right), or "none" for a click
%   in the middle strip (within 5 % of the centre), so a stray click does not count.
d = x / W - 0.5;
if abs(d) <= 0.05
    answer = "none";
elseif d < 0
    answer = "no";
else
    answer = "yes";
end
end
