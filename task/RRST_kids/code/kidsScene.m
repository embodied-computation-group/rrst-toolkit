function kidsScene(scr, s)
%KIDSSCENE Draw the Milkshake Monster scene (no Flip).
%   kidsScene(scr, s)   s fields (all optional):
%     belly     0-1   size of the monster's belly (breath)
%     cup       0-1   milkshake left in the cup
%     straw     true  straw from the cup to the mouth
%     mouseX    0-1   mouse position along the bottom (NaN: hidden)
%     bubbles   0-1   exhale bubbles rising (NaN: none)
%     wiggle    px    sideways offset of the monster (dance)
%     stars     n     stars in the current cup (of starsPerCup)
%     cupsDone  n     finished cups (of nCups)
%     text      char  caption at the bottom
%   Everything is drawn from simple shapes, scaled to the window height.
d = struct('belly', 0, 'cup', 1, 'straw', true, 'mouseX', NaN, 'bubbles', NaN, ...
    'wiggle', 0, 'stars', 0, 'cupsDone', 0, 'starsPerCup', 10, 'nCups', 4, 'text', '');
for f = fieldnames(d)'
    if ~isfield(s, f{1}), s.(f{1}) = d.(f{1}); end
end
w = scr.win; W = scr.winRect(3); H = scr.winRect(4);
c = scr.colours;
Screen('FillRect', w, c.background);

% Monster
R = 0.22 * H; cx = 0.36 * W + s.wiggle; cy = 0.55 * H;
Screen('FillOval', w, c.monster, disc(cx, cy, R));
for side = [-1 1]                                           % feet
    Screen('FillOval', w, c.monsterDark, [cx + side * 0.5 * R - 0.25 * R, cy + 0.8 * R, cx + side * 0.5 * R + 0.25 * R, cy + 1.05 * R]);
end
bellyR = R * (0.28 + 0.34 * min(max(s.belly, 0), 1));
Screen('FillOval', w, c.belly, disc(cx, cy + 0.25 * R, bellyR));
for side = [-1 1]                                           % eyes
    ex = cx + side * 0.35 * R; ey = cy - 0.45 * R;
    Screen('FillOval', w, [1 1 1], disc(ex, ey, 0.17 * R));
    Screen('FillOval', w, [0.1 0.1 0.15], disc(ex + 0.05 * R, ey, 0.08 * R));
end
mx = cx + 0.62 * R; my = cy - 0.1 * R;                      % mouth, facing the cup
Screen('FillOval', w, c.mouth, disc(mx, my, 0.1 * R));

% Cup with milkshake
cupW = 0.13 * H; cupH = 0.28 * H; ux = 0.72 * W; uy = 0.6 * H;
cupRect = [ux - cupW / 2, uy - cupH / 2, ux + cupW / 2, uy + cupH / 2];
level = min(max(s.cup, 0), 1);
Screen('FillRect', w, c.shake, [cupRect(1), cupRect(4) - level * cupH, cupRect(3), cupRect(4)]);
Screen('FrameRect', w, [1 1 1], cupRect, 6);

% Straw: up out of the cup, across to the mouth
if s.straw
    sw = 0.018 * H; topY = my - 0.02 * H;
    Screen('FillRect', w, c.straw, [ux - sw / 2, topY - sw / 2, ux + sw / 2, cupRect(4) - 0.04 * H]);
    Screen('FillRect', w, c.straw, [mx, topY - sw / 2, ux + sw / 2, topY + sw / 2]);
end

% Exhale bubbles
if ~isnan(s.bubbles)
    for k = 1:3
        p = mod(s.bubbles + (k - 1) / 3, 1);
        Screen('FrameOval', w, c.bubble, disc(mx + (0.15 + 0.3 * (k - 1)) * R, my - 0.05 * H - p * 0.4 * H, (0.04 + 0.03 * k) * R), 4);
    end
end

% Mouse along the bottom
if ~isnan(s.mouseX)
    drawMouse(w, c, 0.1 * W + 0.8 * W * s.mouseX, 0.92 * H, 0.05 * H);
end

% Progress: stars for the current cup, small cups done
starR = 0.025 * H; y0 = 0.07 * H;
for k = 1:s.starsPerCup
    x = 0.5 * W + (k - (s.starsPerCup + 1) / 2) * 2.4 * starR;
    if k <= s.stars
        Screen('FillPoly', w, c.star, star(x, y0, starR), 0);
    else
        Screen('FramePoly', w, c.slot, star(x, y0, starR), 2);
    end
end
for k = 1:s.nCups
    x = 0.9 * W + (k - s.nCups) * 0.035 * H; r = [x - 0.012 * H, y0 - 0.025 * H, x + 0.012 * H, y0 + 0.025 * H];
    if k <= s.cupsDone, Screen('FillRect', w, c.shake, r); end
    Screen('FrameRect', w, [1 1 1], r, 2);
end

if ~isempty(s.text)
    DrawFormattedText(w, s.text, 'center', 0.82 * H, c.text);
end
end

function r = disc(x, y, rad)
r = [x - rad, y - rad, x + rad, y + rad];
end

function p = star(x, y, r)
a = (0:9)' * pi / 5 - pi / 2;
rr = repmat([r; 0.45 * r], 5, 1);
p = [x + rr .* cos(a), y + rr .* sin(a)];
end

function drawMouse(w, c, x, y, s)
Screen('FillOval', w, c.mouse, [x - s, y - 0.6 * s, x + s, y + 0.6 * s]);      % body
Screen('FillOval', w, c.mouse, [x + 0.6 * s, y - 0.9 * s, x + 1.4 * s, y - 0.1 * s]);   % head
Screen('FillOval', w, c.mouseEar, [x + 0.7 * s, y - 1.2 * s, x + 1.1 * s, y - 0.8 * s]);
Screen('FillOval', w, [0.1 0.1 0.1], [x + 1.15 * s, y - 0.6 * s, x + 1.25 * s, y - 0.5 * s]);   % eye
Screen('DrawLine', w, c.mouse, x - s, y, x - 1.8 * s, y - 0.4 * s, 3);          % tail
end
