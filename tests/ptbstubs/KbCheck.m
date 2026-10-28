function [down, secs, code] = KbCheck(varargin)
global PTBSTUB
PTBSTUB.nKb = PTBSTUB.nKb + 1;
code = zeros(1, 256);
if PTBSTUB.nKb >= PTBSTUB.escAt, code(KbName('ESCAPE')) = 1; end
down = any(code); secs = GetSecs;
end
