function kidsQuestion(scr, text, hover, chosen)
%KIDSQUESTION Draw the answer screen (no Flip): "easy" on the left, "squishy" on the right.
%   kidsQuestion(scr, text)                  plain
%   kidsQuestion(scr, text, "no"|"yes")      white frame round the card under the pointer
%   kidsQuestion(scr, text, answer, true)    the answer given: thick frame, other card faded
%   Two equally nice scene cards, same size and brightness, the same cheerful monster
%   drinking on both: on "easy" the straw is open and the mouse is asleep in the corner;
%   on "squishy" the mouse sits on the straw and squeezes it narrow. No red/green, no
%   sad face: neither answer looks like the "bad" one. The question is for the
%   experimenter, small at the top. Geometry: kidsQuestionLayout.
%   The experimenter clicks the card the child chose (kidsClickAnswer) or presses
%   LeftArrow / n = easy, RightArrow / y = squishy.
if nargin < 3, hover = ""; end
if nargin < 4, chosen = false; end
w = scr.win; H = scr.winRect(4) - scr.winRect(2);
c = cardColours(scr.colours);
g = kidsQuestionLayout(scr.winRect);
Screen('FillRect', w, c.background);

textSize = Screen('TextSize', w);
setSize(w, textSize, 0.65);
DrawFormattedText(w, text.question, 'center', g.questionY, c.text);

hovering = ismember(hover, ["no" "yes"]);   % "" or "none" (pointer in the middle strip): no frame
if hovering
    lw = g.lineWidth; if chosen, lw = g.chosenWidth; end
    f = g.frame.(hover); rad = g.radius + 0.02 * H;
    roundRect(w, [1 1 1], f, rad);
    roundRect(w, c.background, f + [lw lw -lw -lw], rad - lw);
end

setSize(w, textSize, 0.85);
drawCard(w, c, g.card.no, c.cardEasy, g.radius, false);
drawCard(w, c, g.card.yes, c.cardSquishy, g.radius, true);
DrawFormattedText(w, text.easy, 'center', 'center', c.text, [], [], [], [], [], g.labelRect.no);
DrawFormattedText(w, text.squishy, 'center', 'center', c.text, [], [], [], [], [], g.labelRect.yes);
setSize(w, textSize, 1);

if hovering && chosen
    other = setdiff(["no" "yes"], hover);
    Screen('FillRect', w, [c.background 0.7], g.fade.(other));   % fade the other card
end
end

function c = cardColours(c)
% Two light, equally bright and equally (un)saturated card colours: cream and lilac
% (HSV value 1, saturation 0.12). Defined here until openScreen (kidsMain) has them.
if ~isfield(c, 'cardEasy'), c.cardEasy = [1 0.96 0.88]; end
if ~isfield(c, 'cardSquishy'), c.cardSquishy = [0.94 0.88 1]; end
end

function setSize(w, base, scale)
% Text size relative to the window's size (set by openScreen); no-op without one.
if ~isempty(base) && base > 0
    Screen('TextSize', w, max(12, round(scale * base)));
end
end

function drawCard(w, c, r, colour, rad, pinched)
% One scene card: a wall and a floor, the monster drinking from its cup, and the
% mouse either asleep in the corner or squeezing the straw. Card units: x and y in
% card widths from the top-left corner (the card is 0.8 widths tall).
L = r(3) - r(1);
X = @(a) r(1) + a * L; Y = @(b) r(2) + b * L;
floorY = Y(0.66);
floorColour = 0.93 * colour;
roundRect(w, floorColour, r, rad);
roundRect(w, colour, [r(1), r(2), r(3), floorY + rad], rad);
Screen('FillRect', w, floorColour, [r(1), floorY, r(3), floorY + rad]);

% Monster: the kidsScene character, small belly, eyes on its cup, smiling
R = 0.25 * L; cx = X(0.36); cy = floorY + 0.02 * L - 1.05 * R;
Screen('FillOval', w, c.monster, disc(cx, cy, R));
for side = [-1 1]                                   % feet
    Screen('FillOval', w, c.monsterDark, [cx + side * 0.5 * R - 0.25 * R, cy + 0.8 * R, cx + side * 0.5 * R + 0.25 * R, cy + 1.05 * R]);
end
Screen('FillOval', w, c.belly, disc(cx, cy + 0.3 * R, 0.33 * R));
for side = [-1 1]                                   % eyes
    ex = cx + side * 0.35 * R; ey = cy - 0.45 * R;
    Screen('FillOval', w, [1 1 1], disc(ex, ey, 0.17 * R));
    Screen('FillOval', w, [0.1 0.1 0.15], disc(ex + 0.05 * R, ey, 0.08 * R));
end
Screen('FillOval', w, c.mouseEar, [cx - 0.68 * R, cy - 0.22 * R, cx - 0.4 * R, cy - 0.06 * R]);   % rosy cheek
mx = cx + 0.62 * R; my = cy - 0.1 * R;              % mouth, on the straw
Screen('FrameArc', w, c.mouth, [cx - 0.25 * R, cy - 0.55 * R, mx, cy - 0.05 * R], 105, 140, max(1, 0.035 * R));   % smile
Screen('FillOval', w, c.mouth, disc(mx, my, 0.1 * R));

% Cup with milkshake, standing on the floor
cupW = 0.13 * L; ux = X(0.86);
cupRect = [ux - cupW / 2, my + 0.06 * L, ux + cupW / 2, floorY + 0.02 * L];
Screen('FillRect', w, c.shake, [cupRect(1), cupRect(2) + 0.25 * (cupRect(4) - cupRect(2)), cupRect(3), cupRect(4)]);
Screen('FrameRect', w, c.background, cupRect, max(1, 0.01 * L));

% Straw: down into the cup, across to the mouth; squeezed narrow at the pinch
sw = 0.04 * L; px = X(0.7);
Screen('FillRect', w, c.straw, [ux - sw / 2, my - sw / 2, ux + sw / 2, cupRect(4) - 0.03 * L]);
if pinched
    k = 0.05 * L; n = 0.12 * sw;                    % pinch half-length, half-width at the pinch
    Screen('FillPoly', w, c.straw, [mx, my - sw / 2; px - k, my - sw / 2; px, my - n; px + k, my - sw / 2; ...
        ux + sw / 2, my - sw / 2; ux + sw / 2, my + sw / 2; px + k, my + sw / 2; px, my + n; ...
        px - k, my + sw / 2; mx, my + sw / 2], 0);
    squeezingMouse(w, c, px, my, sw, 0.07 * L);
else
    Screen('FillRect', w, c.straw, [mx, my - sw / 2, ux + sw / 2, my + sw / 2]);
    sleepingMouse(w, c, X(0.16), Y(0.73), 0.06 * L);
end
end

function squeezingMouse(w, c, px, py, sw, s)
% Mouse sitting on the straw at px, eye open, front paws squeezing it from both sides.
by = py - sw / 2 - 0.55 * s;                        % body rests on the straw
dark = 0.75 * c.mouse;
Screen('DrawLine', w, c.mouse, px - 0.9 * s, by + 0.1 * s, px - 1.35 * s, by - 0.5 * s, max(1, 0.12 * s));   % tail, curling up
Screen('DrawLine', w, c.mouse, px - 1.35 * s, by - 0.5 * s, px - 1.1 * s, by - 0.95 * s, max(1, 0.12 * s));
Screen('FillOval', w, c.mouse, [px - 1.1 * s, by - 0.75 * s, px + 0.7 * s, by + 0.6 * s]);   % body
Screen('FillOval', w, c.mouse, [px + 0.2 * s, by - 1.3 * s, px + 1.3 * s, by - 0.2 * s]);    % head
Screen('FillOval', w, c.mouseEar, [px + 0.2 * s, by - 1.7 * s, px + 0.75 * s, by - 1.1 * s]);
Screen('FillOval', w, [0.1 0.1 0.1], disc(px + 0.88 * s, by - 0.82 * s, 0.13 * s));    % open eye
Screen('FillOval', w, [1 1 1], disc(px + 0.92 * s, by - 0.87 * s, 0.045 * s));
Screen('FillOval', w, c.mouseEar, disc(px + 1.3 * s, by - 0.68 * s, 0.11 * s));           % nose
Screen('DrawLine', w, c.mouse, px - 0.2 * s, by + 0.3 * s, px - 0.1 * s, py + 0.62 * sw, max(1, 0.18 * s));   % arm round the straw
for dy = [-1 1]                                     % paws clamping the pinch from above and below
    Screen('FillOval', w, c.mouseEar, [px - 0.38 * s, py + dy * 0.62 * sw - 0.2 * s, px + 0.38 * s, py + dy * 0.62 * sw + 0.2 * s]);
end
for dx = [-1 1]                                     % squeeze marks
    x0 = px + dx * 0.75 * s;
    Screen('DrawLine', w, dark, x0, py + 0.9 * sw, x0 + dx * 0.3 * s, py + 1.6 * sw, max(1, 0.09 * s));
    Screen('DrawLine', w, dark, x0 + dx * 0.25 * s, py + 0.7 * sw, x0 + dx * 0.65 * s, py + 1.2 * sw, max(1, 0.09 * s));
end
end

function sleepingMouse(w, c, x, y, s)
% Mouse curled up asleep, head to the left, closed eye, Z's rising.
lw = max(1, 0.12 * s);
Screen('FrameArc', w, c.mouse, [x - 1.3 * s, y - 0.6 * s, x + 1.4 * s, y + 0.95 * s], 110, 140, lw);   % tail round the front
Screen('FillOval', w, c.mouse, [x - 1.1 * s, y - 0.75 * s, x + 1.1 * s, y + 0.7 * s]);          % body
Screen('FillOval', w, c.mouse, [x - 1.45 * s, y - 0.35 * s, x - 0.45 * s, y + 0.6 * s]);        % head, tucked low
Screen('FillOval', w, c.mouseEar, [x - 1.0 * s, y - 0.75 * s, x - 0.55 * s, y - 0.25 * s]);
Screen('FrameArc', w, [0.1 0.1 0.1], [x - 1.2 * s, y - 0.05 * s, x - 0.85 * s, y + 0.2 * s], 90, 180, max(1, 0.1 * s));   % closed eye
Screen('FillOval', w, c.mouseEar, disc(x - 1.42 * s, y + 0.18 * s, 0.1 * s));             % nose
zee(w, c.text, x - 1.2 * s, y - 1.3 * s, 0.45 * s, lw);
zee(w, c.text, x - 1.7 * s, y - 2.1 * s, 0.6 * s, lw);
end

function zee(w, colour, x, y, h, lw)
% A letter Z of height h centred at (x, y), from three lines.
a = h / 2;
Screen('DrawLine', w, colour, x - a, y - a, x + a, y - a, lw);
Screen('DrawLine', w, colour, x + a, y - a, x - a, y + a, lw);
Screen('DrawLine', w, colour, x - a, y + a, x + a, y + a, lw);
end

function roundRect(w, colour, r, rad)
% Filled rectangle with rounded corners of radius rad (opaque colours only).
rad = max(0, min([rad, (r(3) - r(1)) / 2, (r(4) - r(2)) / 2]));
Screen('FillRect', w, colour, [r(1) + rad, r(2), r(3) - rad, r(4)]);
Screen('FillRect', w, colour, [r(1), r(2) + rad, r(3), r(4) - rad]);
for x = [r(1) + rad, r(3) - rad]
    for y = [r(2) + rad, r(4) - rad]
        Screen('FillOval', w, colour, disc(x, y, rad));
    end
end
end

function r = disc(x, y, rad)
r = [x - rad, y - rad, x + rad, y + rad];
end
