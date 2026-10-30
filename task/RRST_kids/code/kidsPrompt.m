function line = kidsPrompt(moment, info)
%KIDSPROMPT The experimenter's line for one moment of an RRST-Kids session (pure).
%   line = kidsPrompt(moment, info)   one short line (char, under 90 characters, no
%                                     line break): what is happening and which key
%                                     goes on. kidsMain draws it first in the small
%                                     bottom-left line of every screen and prints it
%                                     on the console.
%   names = kidsPrompt()              the moments (string array)
%
%   English and for the experimenter only: the child does not read. A main trial's
%   line never names its level (the experimenter must not know a catch trial).
%
%   Moments and info fields:
%     calibrating
%     story      beat, nBeats         "Story 1 of 3. Tell it, then Space."
%     freeplay                        tutorial: free slurps, Space ends them
%     demo       demo "pinch"|"sleep" tutorial demo, before its slurps
%     bridge                          tutorial: the answer cards, explained
%     mainStart                       practice passed, main trials next
%     move                            the mouse runs while the wedge moves
%     ready      phase "practice" (k, n: questioned trial k of n), "main" (n: trial
%                number), "free" (k, n: free slurp trial k of n; tutorial off)
%     slurps     phase as ready, or "demo" (demo); slurps: slurps per trial
%     question, reveal (phase "practice"|"demo"), reward, cup, rest (restS), pause,
%     thanks, done
%   Plan: docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, section 5.3 (U9).

names = ["calibrating" "story" "freeplay" "demo" "bridge" "mainStart" "move" "ready" "slurps" ...
    "question" "reveal" "reward" "cup" "rest" "pause" "thanks" "done"];
if nargin == 0
    line = names;
    return
end
if nargin < 2, info = struct(); end
moment = string(moment);
switch moment
    case "calibrating"
        line = 'Calibrating: nobody on the tube. Wait.';
    case "story"
        line = sprintf('Story %d of %d. Tell it, then Space.', info.beat, info.nBeats);
    case "freeplay"
        line = 'Free slurps: let them breathe. Space when done.';
    case "demo"
        switch string(info.demo)
            case "pinch", what = 'the mouse is pinching';
            case "sleep", what = 'the mouse is asleep';
            otherwise, bad('Unknown demo "%s".', info.demo);
        end
        line = sprintf('Demo: %s. Let them slurp and feel it. Space starts.', what);
    case "bridge"
        line = 'Now you say: did the mouse pinch? Explain both cards, then Space.';
    case "mainStart"
        line = 'Practice passed. Main trials: no feedback, one star per answer. Space.';
    case "move"
        line = 'The mouse runs: the wedge is moving. Wait.';
    case "ready"
        switch phaseOf(info)
            case "practice"
                line = sprintf(['PRACTICE %d of %d. Space starts the slurps. ' ...
                    'The truth is shown after the answer.'], info.k, info.n);
            case "main"
                line = sprintf('Trial %d. Space starts the slurps. No feedback; one star per answer.', info.n);
            case "free"
                line = sprintf('Free slurps %d of %d. Space starts the slurps.', info.k, info.n);
        end
    case "slurps"
        switch phaseOf(info, "demo")
            case "practice", what = sprintf('PRACTICE %d of %d', info.k, info.n);
            case "main", what = sprintf('Trial %d', info.n);
            case "free", what = sprintf('Free slurps %d of %d', info.k, info.n);
            case "demo", what = 'Demo';
        end
        line = sprintf('%s: %d slurps. Space = stop early, x = bad breath.', what, info.slurps);
    case "question"
        line = 'Click the card the child chose (Left/Right arrow). x = bad breath.';
    case "reveal"
        if isfield(info, 'phase') && string(info.phase) == "demo"
            line = 'Demo: this is what the mouse did.';
        else
            line = 'Practice: this is the truth.';
        end
    case "reward"
        line = 'Star: one per answer, right or wrong.';
    case "cup"
        line = 'Sticker time! Space.';
    case "rest"
        line = sprintf('Rest %g s. Then Space.', info.restS);
    case "pause"
        line = 'Paused, wedge open. Space goes on, Esc ends.';
    case "thanks"
        line = 'Practice not passed: thank the child. The session ends.';
    case "done"
        line = 'All done. Esc or wait.';
    otherwise
        bad('Unknown moment "%s".', moment);
end
end

function p = phaseOf(info, extra)
% The trial phase, checked against the phases the moment knows.
known = ["practice" "main" "free"];
if nargin > 1, known = [known extra]; end
if ~isfield(info, 'phase') || ~ismember(string(info.phase), known)
    bad('This moment needs info.phase (%s).', strjoin(known, ', '));
end
p = string(info.phase);
end

function bad(msg, varargin)
error('rrst:badPrompt', msg, varargin{:});
end
