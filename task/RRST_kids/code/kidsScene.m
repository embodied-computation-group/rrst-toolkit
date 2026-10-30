function kidsScene(scr, s)
%KIDSSCENE Draw the Milkshake Monster scene (no Flip).
%   kidsScene(scr, s)   s fields (all optional):
%     belly     0-1   size of the monster's belly (breath)
%     cup       0-1   milkshake left in the cup
%     straw     true  straw from the cup to the mouth
%     mouseX    0-1   running mouse position along the bottom (NaN: hidden)
%     bubbles   0-1   exhale bubbles rising (NaN: none)
%     wiggle    px    sideways offset of the monster (dance)
%     stars     n     stars in the current cup (of starsPerCup, default 10)
%     cupsDone  n     finished cups (of nCups, default 4)
%     text      char  experimenter line, small, bottom left ('')
%     pose      "idle" (default: looks at the cup, blinks every 3 s), "ready" (looks at
%               the child, mouth open on the straw, eyebrows up), "slurp" (cheeks in,
%               happy eyes), "ahh" (eyes closed, smiling), "tryagain" (head tilt, one
%               eyebrow up; never sad), "celebrate" (arms up), "sleep" (rest, Z's),
%               "strain" (story only: cheeks puffed, eyes wide)
%     t         s     animation clock for blink, Z's, straw wiggle, waving (0)
%     mousePose ""    "run" (at mouseX), "pinch" (squeezing the straw), "sleep" (curled
%               up by the table), "hidden"; "" (default): "run" when mouseX is set
%     reveal    ""    "pinch" | "sleep": practice feedback, the mouse in that pose in a
%               spotlight (overrides mousePose)
%     flyStar   0-1   star flying from the belly to slot stars+1 (NaN: none)
%     cupTip    0-1   the cup tipping into done slot cupsDone+1 (NaN: none)
%     restLeft  0-1   nap bar, the part of the rest still to go (NaN: none)
%     flavour   1-4   milkshake colour: pink, chocolate, mint, blueberry (wraps after 4)
%     childText char  large centred line for the child ('')
%   Geometry and poses come from kidsPose (pure); this function only draws. Drawn
%   from simple shapes, scaled to the window. The mouse's pinch and sleep poses and
%   the monster's smile and cheek repeat kidsQuestion's drawing (one character).
g = kidsPose(s, scr.winRect);
s = g.s;
w = scr.win; H = scr.winRect(4) - scr.winRect(2);
c = scr.colours;
m = g.monster; R = m.R;
Screen('FillRect', w, c.background);

% Ground and table
Screen('FillRect', w, g.groundColour, g.ground);
Screen('FillRect', w, 0.9 * g.groundColour, [g.ground(1:3), g.groundY + 0.008 * H]);
if g.restBar.active
    o = g.restBar.outer; rad = (o(4) - o(2)) / 2;
    pill(w, 0.55 * c.background + 0.45, o, rad);            % opaque: the pill's parts overlap
    if g.restBar.fill(3) - g.restBar.fill(1) > 0.5
        pill(w, [1 0.88 0.45], g.restBar.fill, rad);
    end
end
wood = [0.8 0.6 0.42];
Screen('FillRect', w, 0.85 * wood, g.table.legs');
Screen('FillRect', w, wood, g.table.top);

% Glass and milkshake (outline after the straw)
if g.cup.visible
    Screen('FillPoly', w, [1 1 1 0.35], g.cup.poly, 1);
    if s.cup > 0, Screen('FillPoly', w, g.shake, g.cup.fill, 1); end
end

% Monster
dark = [0.1 0.1 0.15]; lw = max(1, 0.05 * R);
for k = 1:size(m.arms, 1)                                   % arms behind the body
    a = m.arms(k, :);
    thickLine(w, c.monster, a(1:2), a(3:4), 0.17 * R);
    Screen('FillOval', w, c.monster, disc(m.hands(k, 1), m.hands(k, 2), m.hands(k, 3)));
end
Screen('FillOval', w, c.monster, m.body);
for k = 1:size(m.puffs, 1)                                  % blown-out cheeks
    p = m.puffs(k, :);
    Screen('FillOval', w, c.monster, disc(p(1), p(2), p(3)));
    Screen('FillOval', w, c.mouseEar, disc(p(1), p(2) + 0.05 * R, 0.13 * R));
end
Screen('FillOval', w, c.monsterDark, m.feet');
Screen('FillOval', w, c.belly, m.belly);
for k = 1:size(m.hollows, 1)                                % sucked-in cheeks: dents in the outline
    Screen('FillOval', w, c.background, m.hollows(k, :));
end
for k = 1:size(m.cheeks, 1)
    Screen('FillOval', w, c.mouseEar, m.cheeks(k, :));
end
for e = m.eyes
    drawEye(w, e, dark, lw);
end
for k = 1:size(m.brows, 1)
    b = m.brows(k, :);
    arch(w, c.monsterDark, b(1:2), b(3:4), 0.06 * R, 0.035 * R);
end
for k = 1:size(m.sweat, 1)                                  % a sweat drop: round bottom, pointed top
    d = m.sweat(k, :);
    Screen('FillOval', w, [0.75 0.92 1], disc(d(1), d(2), d(3)));
    Screen('FillPoly', w, [0.75 0.92 1], [d(1) - 0.95 * d(3), d(2) - 0.3 * d(3); d(1), d(2) - 2.2 * d(3); d(1) + 0.95 * d(3), d(2) - 0.3 * d(3)], 1);
end
if ~isempty(m.smile)
    Screen('FrameArc', w, c.mouth, m.smile.rect, m.smile.start + m.tilt * 180 / pi, m.smile.sweep, max(1, 0.035 * R));
end

% Straw (from the cup up and across to the mouth; squeezed narrow at a pinch)
st = g.straw;
if st.visible
    thickLine(w, c.straw, st.bottom, st.elbow, st.width);
    Screen('FillOval', w, c.straw, disc(st.elbow(1), st.elbow(2), st.width / 2));
    if st.pinch.active
        Screen('FillPoly', w, c.straw, pinchedStraw(st), 0);
    else
        thickLine(w, c.straw, st.mouth, st.elbow, st.width);
    end
end
drawMouth(w, m, c);
if g.cup.visible
    Screen('FramePoly', w, [1 1 1], g.cup.poly, max(2, 0.005 * H));
end
for k = 1:size(m.motion, 1)                                 % slurp lines along the straw
    l = m.motion(k, :);
    thickLine(w, [1 1 1 0.85], l(1:2), l(3:4), 0.006 * H);
end

% Exhale bubbles and Z's
for k = 1:size(g.bubbles, 1)
    b = g.bubbles(k, :);
    Screen('FrameOval', w, c.bubble, disc(b(1), b(2), b(3)), max(1, 0.0045 * H));
end
for k = 1:size(m.zees, 1)
    z = m.zees(k, :);
    zee(w, [c.text z(4)], z(1), z(2), z(3), 0.18 * z(3));
end

% Mouse
mo = g.mouse;
if mo.spotlight.active
    sl = mo.spotlight.disc; ctr = [mean(sl([1 3])), mean(sl([2 4]))]; r0 = (sl(3) - sl(1)) / 2;
    for f = [1 0.85 0.7 0.55]
        Screen('FillOval', w, [1 1 0.88 0.14], disc(ctr(1), ctr(2), f * r0));
    end
    Screen('FrameOval', w, [1 1 1 0.9], sl, max(1, 0.005 * H));
end
switch mo.pose
    case "run", drawMouse(w, c, mo.x, mo.y, mo.size);
    case "pinch", squeezingMouse(w, c, mo.x, mo.y, st.width, mo.size);
    case "sleep"
        sleepingMouse(w, c, mo.x, mo.y, mo.size);
        for k = 1:size(mo.zees, 1)
            z = mo.zees(k, :);
            zee(w, [c.text z(4)], z(1), z(2), z(3), 0.18 * z(3));
        end
end

% Progress: stars for the current cup, small cups done (in their flavours)
for k = 1:size(g.slots, 1)
    r = g.slots(k, :); x = mean(r([1 3])); y = mean(r([2 4]));
    if g.slotFilled(k)
        Screen('FillPoly', w, c.star, star(x, y, g.starR, 0), 0);
    else
        Screen('FramePoly', w, c.slot, star(x, y, g.starR, 0), 2);
    end
end
for k = 1:size(g.cupSlots, 1)
    r = g.cupSlots(k, :);
    if g.cupSlotFilled(k), Screen('FillRect', w, g.cupSlotColour(k, :), r); end
    Screen('FrameRect', w, [1 1 1], r, 2);
end
if g.tip.active
    Screen('FillPoly', w, [1 1 1 0.35], g.tip.poly, 1);
    Screen('FillPoly', w, [g.tip.colour g.tip.fill], g.tip.poly, 1);
    Screen('FramePoly', w, [1 1 1], g.tip.poly, max(2, 0.004 * H));
end
if g.fly.active
    p = star(g.fly.pos(1), g.fly.pos(2), g.fly.r, g.fly.angle);
    Screen('FillPoly', w, c.star, p, 0);
    Screen('FramePoly', w, 0.8 * c.star, p, max(1, 0.002 * H));
end

% Text: the experimenter's line small in the corner, the child's line large
base = Screen('TextSize', w);
if ~isempty(s.text)
    setSize(w, base, g.textScale);
    nLines = numel(strfind(s.text, '\n')) + 1;
    lineH = 1.15 * g.textScale * textSizeOr(base, 0.033 * H);
    muted = 0.55 * c.text + 0.45 * g.groundColour;
    DrawFormattedText(w, s.text, g.textX, g.textBottom - nLines * lineH, muted);
end
if ~isempty(s.childText)
    setSize(w, base, g.childTextScale);
    DrawFormattedText(w, s.childText, 'center', g.childTextY, c.text);
end
setSize(w, base, 1);
end

% --- drawing helpers ------------------------------------------------------------------

function drawEye(w, e, dark, lw)
switch e.state
    case {"open", "wide"}
        Screen('FillOval', w, [1 1 1], e.rect);
        Screen('FillOval', w, dark, disc(e.pupil(1), e.pupil(2), e.pupilR));
        Screen('FillOval', w, [1 1 1], disc(e.pupil(1) - 0.35 * e.pupilR, e.pupil(2) - 0.35 * e.pupilR, 0.3 * e.pupilR));
    case "happy"                                            % squeezed "^"
        Screen('FrameArc', w, dark, e.rect + [0 0.25 0 0.25] * e.r, 270, 180, 1.4 * lw);
    case {"content", "closed"}                              % closed "u"
        Screen('FrameArc', w, dark, e.rect - [0 0.2 0 0.2] * e.r, 90, 180, 1.4 * lw);
end
end

function drawMouth(w, m, c)
mo = m.mouth; ctr = mo.centre; r = mo.r; R = m.R;
switch mo.type
    case {"smile", "content", "snore"}
        Screen('FillOval', w, c.mouth, mo.rect);
    case "round"                                            % open "O" on the straw
        Screen('FillOval', w, c.mouth, mo.rect);
        Screen('FrameOval', w, c.monsterDark, mo.rect, max(1, 0.035 * R));
    case {"pucker", "tight"}                                % pursed lips round the straw
        Screen('FillOval', w, c.mouth, mo.rect);
        Screen('FrameOval', w, c.monsterDark, mo.rect + [-1 -1 1 1] * 0.03 * R, max(1, 0.06 * R));
    case "flat"                                             % "hmm": short, a little lopsided
        a = rot2([-0.13 0.0], m.tilt) * R + ctr; b = rot2([0.13 -0.04], m.tilt) * R + ctr;
        thickLine(w, c.mouth, a, b, 0.045 * R);
        Screen('FillOval', w, c.mouth, disc(a(1), a(2), 0.0225 * R));
        Screen('FillOval', w, c.mouth, disc(b(1), b(2), 0.0225 * R));
    case "grin"                                             % big open "D"
        Screen('FillArc', w, c.mouth, mo.rect, 90, 180);
        Screen('FillArc', w, c.mouseEar, [ctr(1) - 0.5 * r, ctr(2) + 0.35 * r, ctr(1) + 0.5 * r, ctr(2) + 0.95 * r], 90, 180);
end
end

function p = pinchedStraw(st)
% Straw from the mouth to the elbow, squeezed to halfWidth at pinch.x.
a = st.mouth; b = st.elbow; d = (b - a) / norm(b - a); n = [-d(2) d(1)];
L = norm(b - a); u0 = (st.pinch.x - a(1)) / max(d(1), eps);   % pinch, along the straw
k = st.pinch.halfLen; hw = st.width / 2; nw = st.pinch.halfWidth;
u = [0, u0 - k, u0, u0 + k, L];
h = [hw, hw, nw, hw, hw];
top = a + u' * d - h' * n; bot = a + u' * d + h' * n;
p = [top; flipud(bot)];
end

function thickLine(w, colour, a, b, width)
% A straight band of the given width from a to b (no line-width limits).
d = b - a; L = norm(d);
if L == 0, return; end
n = [-d(2) d(1)] / L * width / 2;
Screen('FillPoly', w, colour, [a + n; b + n; b - n; a - n], 1);
end

function arch(w, colour, a, b, width, bow)
% A band from a to b bowed upwards by bow at the middle (eyebrows).
n = [b(2) - a(2), a(1) - b(1)] / norm(b - a);
if n(2) > 0, n = -n; end                                    % the bow points up
ctrl = (a + b) / 2 + 2 * bow * n;
u = linspace(0, 1, 9)';
p = (1 - u).^2 * a + 2 * (1 - u) .* u * ctrl + u.^2 * b;
for k = 1:size(p, 1) - 1
    thickLine(w, colour, p(k, :), p(k + 1, :), width);
end
for k = 1:size(p, 1)
    Screen('FillOval', w, colour, disc(p(k, 1), p(k, 2), width / 2));
end
end

function pill(w, colour, r, rad)
Screen('FillRect', w, colour, [r(1) + rad, r(2), r(3) - rad, r(4)]);
Screen('FillOval', w, colour, disc(r(1) + rad, (r(2) + r(4)) / 2, rad));
Screen('FillOval', w, colour, disc(r(3) - rad, (r(2) + r(4)) / 2, rad));
end

function zee(w, colour, x, y, h, lw)
% A letter Z of height h centred at (x, y), from three bands.
a = h / 2;
thickLine(w, colour, [x - a, y - a], [x + a, y - a], lw);
thickLine(w, colour, [x + a, y - a], [x - a, y + a], lw);
thickLine(w, colour, [x - a, y + a], [x + a, y + a], lw);
end

function drawMouse(w, c, x, y, s)
% The running mouse (as before).
Screen('FillOval', w, c.mouse, [x - s, y - 0.6 * s, x + s, y + 0.6 * s]);      % body
Screen('FillOval', w, c.mouse, [x + 0.6 * s, y - 0.9 * s, x + 1.4 * s, y - 0.1 * s]);   % head
Screen('FillOval', w, c.mouseEar, [x + 0.7 * s, y - 1.2 * s, x + 1.1 * s, y - 0.8 * s]);
Screen('FillOval', w, [0.1 0.1 0.1], [x + 1.15 * s, y - 0.6 * s, x + 1.25 * s, y - 0.5 * s]);   % eye
Screen('DrawLine', w, c.mouse, x - s, y, x - 1.8 * s, y - 0.4 * s, 3);          % tail
end

function squeezingMouse(w, c, px, py, sw, s)
% Mouse sitting on the straw at px, eye open, front paws squeezing it from both sides
% (as on kidsQuestion's "squishy" card).
by = py - sw / 2 - 0.55 * s;                        % body rests on the straw
dark = 0.75 * c.mouse;
thickLine(w, c.mouse, [px - 0.9 * s, by + 0.1 * s], [px - 1.35 * s, by - 0.5 * s], 0.12 * s);   % tail, curling up
thickLine(w, c.mouse, [px - 1.35 * s, by - 0.5 * s], [px - 1.1 * s, by - 0.95 * s], 0.12 * s);
Screen('FillOval', w, c.mouse, [px - 1.1 * s, by - 0.75 * s, px + 0.7 * s, by + 0.6 * s]);   % body
Screen('FillOval', w, c.mouse, [px + 0.2 * s, by - 1.3 * s, px + 1.3 * s, by - 0.2 * s]);    % head
Screen('FillOval', w, c.mouseEar, [px + 0.2 * s, by - 1.7 * s, px + 0.75 * s, by - 1.1 * s]);
Screen('FillOval', w, [0.1 0.1 0.1], disc(px + 0.88 * s, by - 0.82 * s, 0.13 * s));    % open eye
Screen('FillOval', w, [1 1 1], disc(px + 0.92 * s, by - 0.87 * s, 0.045 * s));
Screen('FillOval', w, c.mouseEar, disc(px + 1.3 * s, by - 0.68 * s, 0.11 * s));           % nose
thickLine(w, c.mouse, [px - 0.2 * s, by + 0.3 * s], [px - 0.1 * s, py + 0.62 * sw], 0.18 * s);   % arm round the straw
for dy = [-1 1]                                     % paws clamping the pinch from above and below
    Screen('FillOval', w, c.mouseEar, [px - 0.38 * s, py + dy * 0.62 * sw - 0.2 * s, px + 0.38 * s, py + dy * 0.62 * sw + 0.2 * s]);
end
for dx = [-1 1]                                     % squeeze marks
    x0 = px + dx * 0.75 * s;
    thickLine(w, dark, [x0, py + 0.9 * sw], [x0 + dx * 0.3 * s, py + 1.6 * sw], 0.09 * s);
    thickLine(w, dark, [x0 + dx * 0.25 * s, py + 0.7 * sw], [x0 + dx * 0.65 * s, py + 1.2 * sw], 0.09 * s);
end
end

function sleepingMouse(w, c, x, y, s)
% Mouse curled up asleep, head to the left, closed eye (as on kidsQuestion's "easy"
% card; the Z's are drawn by the caller, animated).
lw = max(1, 0.12 * s);
Screen('FrameArc', w, c.mouse, [x - 1.3 * s, y - 0.6 * s, x + 1.4 * s, y + 0.95 * s], 110, 140, lw);   % tail round the front
Screen('FillOval', w, c.mouse, [x - 1.1 * s, y - 0.75 * s, x + 1.1 * s, y + 0.7 * s]);          % body
Screen('FillOval', w, c.mouse, [x - 1.45 * s, y - 0.35 * s, x - 0.45 * s, y + 0.6 * s]);        % head, tucked low
Screen('FillOval', w, c.mouseEar, [x - 1.0 * s, y - 0.75 * s, x - 0.55 * s, y - 0.25 * s]);
Screen('FrameArc', w, [0.1 0.1 0.1], [x - 1.2 * s, y - 0.05 * s, x - 0.85 * s, y + 0.2 * s], 90, 180, max(1, 0.1 * s));   % closed eye
Screen('FillOval', w, c.mouseEar, disc(x - 1.42 * s, y + 0.18 * s, 0.1 * s));             % nose
end

% --- small maths ------------------------------------------------------------------------

function setSize(w, base, scale)
% Text size relative to the window's (set by openScreen); no-op without one.
if ~isempty(base) && base > 0
    Screen('TextSize', w, max(10, round(scale * base)));
end
end

function v = textSizeOr(base, fallback)
if isempty(base) || base <= 0, v = fallback; else, v = base; end
end

function r = disc(x, y, rad)
r = [x - rad, y - rad, x + rad, y + rad];
end

function q = rot2(p, a)
q = p * [cos(a) sin(a); -sin(a) cos(a)];
end

function p = star(x, y, r, angle)
a = (0:9)' * pi / 5 - pi / 2 + angle;
rr = repmat([r; 0.45 * r], 5, 1);
p = [x + rr .* cos(a), y + rr .* sin(a)];
end
