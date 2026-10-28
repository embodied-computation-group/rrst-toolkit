function varargout = Screen(cmd, varargin)
global PTBSTUB
switch cmd
    case 'Screens', varargout = {0};
    case 'Rect', varargout = {[0 0 2560 1440]};
    case 'TextBounds', varargout = {[0 0 100 30]};
    case 'GetFlipInterval', varargout = {1 / 60};
    case 'Flip'
        PTBSTUB.nFlip = PTBSTUB.nFlip + 1;
        varargout = {GetSecs, GetSecs};
    otherwise, varargout = cell(1, nargout);
end
end
