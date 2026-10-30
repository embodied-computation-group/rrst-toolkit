function fb = kidsFeedbackBeat(answer, truth, p, timing)
%KIDSFEEDBACKBEAT What the child's feedback screen shows after an answer (pure).
%   fb = kidsFeedbackBeat(answer, truth, p)
%   fb = kidsFeedbackBeat(answer, truth, p, timing)
%
%   answer  "yes" (squishy) | "no" (easy): the card the experimenter clicked
%   truth   "yes" (the mouse pinched: level > 0) | "no" (catch trial, level 0)
%   p       progress through the feedback, 0 to 1
%   timing  cfg.timing (optional): fb.dur = timing.feedback, else NaN
%
%   fb.answer, fb.truth, fb.p
%   fb.correct  answer == truth
%   fb.cue      kidsSound cue played once at the start: "star" when right, the soft
%               "tryagain" when wrong (never a sad sound)
%   fb.dur      s, before cfg.debug.timeScale
%   fb.tick     0-1: the gold tick over the chosen card pops in (right only; 0 when wrong)
%   fb.fade     0-0.55: the chosen card fades (wrong only; 0 when right)
%   fb.squeeze  0-1: the mouse on the correct "squishy" card squeezes the straw twice
%               (truth "yes"; 0 otherwise)
%   fb.zRise    0-1: a Z floats up from the mouse asleep on the correct "easy" card
%               (truth "no"; NaN otherwise)
%
%   Both answer cards stay as on the question screen; the correct card gets a thick
%   gold frame and a star badge, the chosen card keeps its white frame. Drawn by
%   kidsQuestion(scr, txt, answer, true, truth, p) with the geometry of
%   kidsFeedbackLayout. Second real run (2026-10-30): the old practice feedback was
%   only a sentence on the experimenter's line.
answer = checkName(answer, 'answer');
truth = checkName(truth, 'truth');
if ~(isnumeric(p) && isscalar(p) && isfinite(p) && p >= 0 && p <= 1)
    error('rrst:badFeedback', 'p must be a number from 0 to 1.');
end
fb.answer = answer; fb.truth = truth; fb.p = p;
fb.correct = answer == truth;
if fb.correct, fb.cue = "star"; else, fb.cue = "tryagain"; end
fb.dur = NaN;
if nargin > 3 && isfield(timing, 'feedback'), fb.dur = timing.feedback; end
fb.tick = 0; fb.fade = 0;
if fb.correct
    fb.tick = min(1, p / 0.15);
else
    fb.fade = 0.55 * min(1, p / 0.3);
end
fb.squeeze = 0; fb.zRise = NaN;
if truth == "yes"
    fb.squeeze = sin(2 * pi * p) ^ 2;          % two squeezes, at rest at both ends
else
    fb.zRise = p;
end
end

function v = checkName(v, what)
if ~((isstring(v) && isscalar(v)) || (ischar(v) && isrow(v))) || ~ismember(string(v), ["yes" "no"])
    error('rrst:badFeedback', '%s must be "yes" or "no".', what);
end
v = string(v);
end
