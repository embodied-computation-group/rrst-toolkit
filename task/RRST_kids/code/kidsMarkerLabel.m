function label = kidsMarkerLabel(event, varargin)
%KIDSMARKERLABEL Text of an RRST-Kids trial marker for the "RRST" LSL stream (rrstMarker).
%   kidsMarkerLabel("level", n, level)              'trial_<n>_level_<x>' (catch trials: level 0)
%   kidsMarkerLabel("go", n)                        'trial_<n>_go' (experimenter's Space)
%   kidsMarkerLabel("answer", answer)               'answer_yes' | 'answer_no' | 'bad_breath' |
%                                                   'no_answer' | 'pause'; "abort" gives '' (no
%                                                   marker: the session's 'aborted' follows)
%   kidsMarkerLabel("outcome", n, level, response)  'trial_<n>_correct' | 'trial_<n>_wrong':
%                                                   correct when response (1 yes, 0 no) == (level > 0)
%   The level uses %g, as the adult task's trial_<n>_level_<x>.
switch event
    case "level"
        label = sprintf('trial_%d_level_%g', varargin{1}, varargin{2});
    case "go"
        label = sprintf('trial_%d_go', varargin{1});
    case "answer"
        switch varargin{1}
            case "yes",   label = 'answer_yes';
            case "no",    label = 'answer_no';
            case "bad",   label = 'bad_breath';
            case "none",  label = 'no_answer';
            case "pause", label = 'pause';
            case "abort", label = '';
            otherwise
                error('rrst:badMarker', 'Unknown answer "%s".', varargin{1});
        end
    case "outcome"
        [n, level, response] = varargin{:};
        outcome = ["wrong" "correct"];
        label = sprintf('trial_%d_%s', n, outcome((response == (level > 0)) + 1));
    otherwise
        error('rrst:badMarker', 'Unknown marker event "%s".', event);
end
end
