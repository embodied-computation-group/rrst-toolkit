function [x, y, buttons, a, b, c] = GetMouse(varargin)
global PTBSTUB
PTBSTUB.nMouse = PTBSTUB.nMouse + 1;
k = min(PTBSTUB.nMouse, size(PTBSTUB.buttons, 1));
buttons = PTBSTUB.buttons(k, :); x = 1000; y = 500; a = []; b = []; c = [];
end
