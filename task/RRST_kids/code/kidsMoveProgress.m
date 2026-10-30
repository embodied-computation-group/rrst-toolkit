function p = kidsMoveProgress(elapsed, moveS, moveMin, tail, holdAt)
%KIDSMOVEPROGRESS Progress (0-1) of the mouse's move beat while the wedge moves (pure).
%   p = kidsMoveProgress(elapsed, moveS, moveMin, tail)
%   p = kidsMoveProgress(elapsed, moveS, moveMin, tail, holdAt)
%
%   elapsed  s since the move was sent
%   moveS    s the firmware took to confirm the move; NaN while it is still moving
%   moveMin  s, the shortest move beat (cfg.timing.moveMin, times the time scale)
%   tail     s the sequence goes on after the confirmation (0.5, times the time scale)
%   holdAt   p is kept below this until the confirmation (default 0.9: where the
%            mouse starts to hide, kidsBeat "move"), so the mouse never hides before
%            the wedge is in place
%
%   p = min(elapsed / max(moveMin, moveSoFar + tail), 1), where moveSoFar is elapsed
%   while the wedge moves and moveS after it: a short move gives the plain moveMin
%   animation; a long one slows the run down while it lasts, and the sequence ends
%   tail seconds after the confirmation. After the confirmation p rises linearly from
%   its value at the confirmation to 1 at max(moveMin, moveS + tail), so it never
%   jumps, also when holdAt held it back. p = 1 exactly when at least moveMin has
%   passed and the sequence has finished.
%   Measured on the real device (2026-10-30): 1.3-2.8 s per move; moveMin 1.5 s.
if nargin < 5, holdAt = 0.9; end
if isnan(moveS) || elapsed < moveS
    p = moving(elapsed, moveMin, tail, holdAt);
    return
end
tEnd = max(moveMin, moveS + tail);
if elapsed >= tEnd
    p = 1;
    return
end
pc = moving(moveS, moveMin, tail, holdAt);
p = pc + (1 - pc) * (elapsed - moveS) / (tEnd - moveS);
end

function p = moving(elapsed, moveMin, tail, holdAt)
% Before the confirmation: elapsed / max(moveMin, elapsed + tail), held below holdAt.
p = max(elapsed, 0) / max([moveMin, elapsed + tail, eps]);
p = min(p, holdAt - 1e-6);
end
