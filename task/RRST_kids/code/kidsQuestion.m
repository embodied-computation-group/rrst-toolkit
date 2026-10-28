function kidsQuestion(scr, text, hover, chosen)
%KIDSQUESTION Draw the answer screen (no Flip): "easy" on the left, "squishy" on the right.
%   kidsQuestion(scr, text)                  plain
%   kidsQuestion(scr, text, "no"|"yes")      white ring round the face under the pointer
%   kidsQuestion(scr, text, answer, true)    the answer given: thick ring, other face faded
%   The experimenter clicks the face the child chose (kidsClickAnswer) or presses
%   LeftArrow / n = easy, RightArrow / y = squishy.
if nargin < 3, hover = ""; end
if nargin < 4, chosen = false; end
w = scr.win; W = scr.winRect(3); H = scr.winRect(4); c = scr.colours;
Screen('FillRect', w, c.background);
DrawFormattedText(w, text.question, 'center', 0.12 * H, c.text);
r = 0.16 * H; y = 0.5 * H; sw = 0.025 * H;

% Left: a happy round slurp, straight straw
x = 0.27 * W;
Screen('FillOval', w, c.easy, [x - r, y - r, x + r, y + r]);
Screen('FillRect', w, c.straw, [x - sw / 2, y - 1.9 * r, x + sw / 2, y - 0.9 * r]);
smile(w, x, y, r);
DrawFormattedText(w, text.easy, 'center', y + 1.5 * r, c.text, [], [], [], [], [], [x - 0.15 * W, 0, x + 0.15 * W, H]);

% Right: a squashed slurp, the mouse biting the straw
x = 0.73 * W;
Screen('FillOval', w, c.squishy, [x - 1.25 * r, y - 0.7 * r, x + 1.25 * r, y + 0.7 * r]);
Screen('FillRect', w, c.straw, [x - sw / 2, y - 1.9 * r, x + sw / 2, y - 1.3 * r]);
Screen('FillRect', w, c.straw, [x - sw / 4, y - 1.3 * r, x + sw / 4, y - 0.7 * r]);   % pinched
Screen('FillOval', w, c.mouse, [x - 0.02 * H, y - 1.45 * r, x + 0.09 * H, y - 1.05 * r]);   % mouse on the pinch
Screen('FillOval', w, c.mouseEar, [x + 0.03 * H, y - 1.65 * r, x + 0.07 * H, y - 1.38 * r]);
Screen('FillOval', w, [0.1 0.1 0.1], [x + 0.065 * H, y - 1.3 * r, x + 0.075 * H, y - 1.22 * r]);
for side = [-1 1]                                           % squeezed "> <" eyes and an "oof" mouth
    ex = x + side * 0.4 * r; tip = ex - side * 0.1 * r; back = ex + side * 0.1 * r;
    Screen('DrawLine', w, [1 1 1], back, y - 0.38 * r, tip, y - 0.28 * r, 5);
    Screen('DrawLine', w, [1 1 1], tip, y - 0.28 * r, back, y - 0.18 * r, 5);
end
Screen('FrameOval', w, [1 1 1], [x - 0.12 * r, y + 0.05 * r, x + 0.12 * r, y + 0.3 * r], 5);
DrawFormattedText(w, text.squishy, 'center', y + 1.5 * r, c.text, [], [], [], [], [], [x - 0.15 * W, 0, x + 0.15 * W, H]);

% Pointer and answer feedback
if hover == "", return; end
xs = struct('no', 0.27 * W, 'yes', 0.73 * W);
x = xs.(hover);
ring = [x - 1.6 * r, y - 2.1 * r, x + 1.6 * r, y + 2.1 * r];
if chosen
    other = xs.(setdiff(["no" "yes"], hover));
    Screen('FillRect', w, [c.background 0.7], [other - 0.2 * W, 0.15 * H, other + 0.2 * W, H]);   % fade the other face
    Screen('FrameRect', w, [1 1 1], ring, 14);
else
    Screen('FrameRect', w, [1 1 1], ring, 5);
end
end

function smile(w, x, y, r)
Screen('FillOval', w, [1 1 1], [x - 0.4 * r, y - 0.35 * r, x - 0.2 * r, y - 0.15 * r]);
Screen('FillOval', w, [1 1 1], [x + 0.2 * r, y - 0.35 * r, x + 0.4 * r, y - 0.15 * r]);
Screen('FrameArc', w, [1 1 1], [x - 0.45 * r, y - 0.3 * r, x + 0.45 * r, y + 0.45 * r], 100, 160, 5);
end
