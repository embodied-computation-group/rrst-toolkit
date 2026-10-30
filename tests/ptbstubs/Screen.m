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
    case {'FillRect', 'FrameRect', 'FillOval', 'FrameOval'}
        % As Psychtoolbox: a rect with right < left or bottom < top is an error
        % ("Invalid Rect Argument"). Rects are 1x4, or one per column (4xN).
        if numel(varargin) >= 3 && ~isempty(varargin{3})
            r = varargin{3};
            if isvector(r), r = r(:)'; else, r = r'; end
            if any(r(:, 3) < r(:, 1) | r(:, 4) < r(:, 2))
                error('ptbstub:invalidRect', 'Error in function %s: Invalid Rect Argument (%s).', ...
                    cmd, mat2str(r, 4));
            end
        end
        varargout = cell(1, nargout);
    otherwise, varargout = cell(1, nargout);
end
end
