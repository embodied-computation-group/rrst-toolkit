function g = kidsPose(s, winRect)
%KIDSPOSE Geometry and pose of the Milkshake Monster scene (pure, no Screen).
%   g = kidsPose(s, winRect)   s: the kidsScene struct (missing fields take their
%   defaults); winRect: [0 0 W H]. Returns everything kidsScene draws, in pixels:
%     s           the scene struct with every field filled in (see kidsScene)
%     groundY, ground, groundColour    the ground strip under everything
%     table       top (rect), legs (2 rects)
%     cup         poly (glass, 4x2), fill (milkshake, 4x2), visible (false while tipping)
%     shake       milkshake colour of this cup (flavour); flavours: all four (4x3)
%     straw       visible, mouth/elbow/bottom points, width, pinch (active, x,
%                 halfLen, halfWidth: the straw squeezed narrow at x)
%     monster     centre, R, tilt (rad), body, feet, belly, eyes (struct array: centre,
%                 r, rect, pupil, pupilR, state open|closed|happy|content|wide),
%                 brows (n x 4 lines), mouth (type, centre, r, rect), cheeks (blush
%                 rects), smile (arc rect, start, sweep in degrees or empty), puffs
%                 (blown-out cheeks, n x 3 discs), hollows (sucked-in cheeks: dents
%                 cut into the outline, rects), sweat (drop), arms (n x 4 lines),
%                 hands (n x 3 discs), motion (n x 4 lines at the straw), zees (n x 4:
%                 x y h alpha)
%     blink       true while the idle eyes are shut
%     mouse       pose run|pinch|sleep|hidden, x, y, size, zees, spotlight
%                 (active, disc)
%     bubbles     n x 3 [x y r] (exhale bubbles; empty for none)
%     slots, slotFilled, starR      the star row (rects round each star)
%     cupSlots, cupSlotFilled, cupSlotColour    the done-cups row
%     fly         active, slot, pos, r, angle: the star flying to its slot
%     tip         active, slot, poly, angle, colour, fill (alpha): the cup tipping into
%                 the done row
%     restBar     active, outer, fill: the draining nap bar
%     textX, textBottom, textScale  experimenter line (bottom left, smaller)
%     childTextY, childTextScale    child line (centred, large)
%   Everything scales with the window: x with the width, y and sizes with the height,
%   as the original scene did. Unknown pose names error rrst:badPose.
if nargin < 1 || isempty(s), s = struct(); end
s = fillIn(s);
W = winRect(3) - winRect(1); H = winRect(4) - winRect(2);
g.s = s;

% --- ground, table, cup ------------------------------------------------------------
g.groundY = 0.8 * H;
g.ground = [0, g.groundY, W, H];
g.groundColour = [0.66 0.86 0.56];
g.flavours = [1 0.6 0.75; 0.58 0.38 0.25; 0.55 0.88 0.68; 0.5 0.5 0.92];   % pink, chocolate, mint, blueberry
g.shake = g.flavours(s.flavour, :);

ux = 0.72 * W;                              % cup centre (as before)
tableY = 0.745 * H;                         % table surface
g.table.top = [ux - 0.15 * H, tableY, ux + 0.15 * H, tableY + 0.02 * H];
legW = 0.018 * H;
g.table.legs = [ux - 0.11 * H - legW / 2, tableY + 0.02 * H, ux - 0.11 * H + legW / 2, g.groundY; ...
    ux + 0.11 * H - legW / 2, tableY + 0.02 * H, ux + 0.11 * H + legW / 2, g.groundY];
cupH = 0.16 * H; topW = 0.14 * H; botW = 0.105 * H;
cupTop = tableY - cupH;
g.cup.poly = [ux - topW / 2, cupTop; ux + topW / 2, cupTop; ux + botW / 2, tableY; ux - botW / 2, tableY];
level = min(max(s.cup, 0), 1);
yl = tableY - level * cupH; wl = botW + (topW - botW) * level;   % glass width at the level
g.cup.fill = [ux - wl / 2, yl; ux + wl / 2, yl; ux + botW / 2, tableY; ux - botW / 2, tableY];
g.cup.visible = true;

% --- monster -------------------------------------------------------------------------
R = 0.22 * H;
cx = 0.36 * W + s.wiggle; cy = g.groundY - R;
m.centre = [cx cy]; m.R = R;
m.tilt = 0;
if s.pose == "tryagain", m.tilt = -14 * pi / 180; end   % head on one side: "hmm?"
P = @(u, v) rot([u v], m.tilt) * R + [cx cy];           % face point, in body radii
m.body = disc(cx, cy, R);
m.feet = [cx - 0.75 * R, cy + 0.8 * R, cx - 0.25 * R, cy + 1.05 * R; ...
    cx + 0.25 * R, cy + 0.8 * R, cx + 0.75 * R, cy + 1.05 * R];
m.belly = disc(cx, cy + 0.25 * R, R * (0.28 + 0.34 * min(max(s.belly, 0), 1)));

g.blink = s.pose == "idle" && mod(s.t, 3) >= 3 - 0.18;  % shut for 0.18 s every 3 s
eyeState = struct('idle', "open", 'ready', "open", 'slurp', "happy", 'ahh', "content", ...
    'tryagain', "open", 'celebrate', "happy", 'sleep', "content", 'strain', "wide");
state = eyeState.(s.pose);
if g.blink, state = "closed"; end
eyeR = 0.17 * R; look = [0 0]; pupilR = 0.08 * R;
switch s.pose
    case "idle", look = [0.05 0.01];        % at the cup
    case "ready", eyeR = 0.19 * R; pupilR = 0.095 * R; look = [0 0.02];   % at the viewer
    case "tryagain", look = [0 0];
    case "strain", eyeR = 0.21 * R; pupilR = 0.06 * R;
end
for k = 1:2
    side = 2 * k - 3;                       % -1 left, +1 right
    c = P(side * 0.35, -0.45);
    e.centre = c; e.r = eyeR; e.rect = disc(c(1), c(2), eyeR);
    e.pupil = c + rot(look, m.tilt) * R; e.pupilR = pupilR;
    e.state = state;
    m.eyes(k) = e;
end

% eyebrows: lines [x1 y1 x2 y2]
m.brows = zeros(0, 4);
switch s.pose
    case "ready"                            % both up: "ready?"
        m.brows = [brow(P, -0.35, -0.8, 0); brow(P, 0.35, -0.8, 0)];
    case "tryagain"                         % one up, the other eye plain
        m.brows = brow(P, 0.36, -0.79, 0.04);
    case "strain"                           % raised in the middle: "uh-oh, hard!" (never cross)
        m.brows = [brow(P, -0.35, -0.84, 0.1); brow(P, 0.35, -0.84, -0.1)];
end

% mouth (on the straw for the drinking poses), cheeks
mouthAt = P(0.62, -0.1);
mouthR = struct('idle', 0.1, 'ready', 0.14, 'slurp', 0.075, 'ahh', 0.07, 'tryagain', 0.1, ...
    'celebrate', 0.3, 'sleep', 0.06, 'strain', 0.06);
mouthType = struct('idle', "smile", 'ready', "round", 'slurp', "pucker", 'ahh', "content", ...
    'tryagain', "flat", 'celebrate', "grin", 'sleep', "snore", 'strain', "tight");
m.mouth.type = mouthType.(s.pose);
m.mouth.r = mouthR.(s.pose) * R;
switch s.pose
    case "celebrate", mouthAt = P(0.05, 0.02);           % big grin in the middle
    case "tryagain", mouthAt = P(0.14, -0.13);
    case "sleep", mouthAt = P(0.1, -0.08);
end
m.mouth.centre = mouthAt;
m.mouth.rect = disc(mouthAt(1), mouthAt(2), m.mouth.r);
m.smile = [];                               % FrameArc: rect, start, sweep (degrees)
switch s.pose
    case {"idle", "ahh"}                    % the question card's smile
        m.smile = struct('rect', [cx - 0.25 * R, cy - 0.55 * R, cx + 0.62 * R, cy - 0.05 * R], 'start', 105, 'sweep', 140);
end
m.cheeks = zeros(0, 4);
switch s.pose
    case {"idle", "ready", "ahh", "tryagain", "sleep"}
        c = P(-0.54, -0.14); m.cheeks = [c - [0.14 0.08] * R, c + [0.14 0.08] * R];
    case "celebrate"
        for side = [-1 1]
            c = P(side * 0.62, -0.1); m.cheeks(end + 1, :) = [c - [0.13 0.08] * R, c + [0.13 0.08] * R];
        end
end
m.puffs = zeros(0, 3); m.hollows = zeros(0, 4); m.sweat = zeros(0, 3);
if s.pose == "strain"                       % cheeks blown out past the outline, a sweat drop
    m.puffs = [P(-0.84, 0.05), 0.36 * R; P(0.78, 0.12), 0.32 * R];
    m.sweat = [P(0.62, -0.78), 0.07 * R];
elseif s.pose == "slurp"                    % cheeks sucked in: dents in the outline
    for side = [-1 1]
        c = P(side * 1.08, 0.0); m.hollows(end + 1, :) = [c - [0.16 0.26] * R, c + [0.16 0.26] * R];
    end
end

% arms: only when celebrating, up and waving
m.arms = zeros(0, 4); m.hands = zeros(0, 3);
if s.pose == "celebrate"
    for side = [-1 1]
        wave = 0.06 * sin(2 * pi * 2 * s.t + (side > 0) * pi);
        sh = [cx + side * 0.85 * R, cy - 0.15 * R];
        hd = [cx + side * 1.3 * R, cy - (0.85 + wave) * R];
        m.arms(end + 1, :) = [sh hd];
        m.hands(end + 1, :) = [hd 0.13 * R];
    end
end

% Z's rising from the sleeping head
m.zees = zeros(0, 4);
if s.pose == "sleep"
    m.zees = zees([cx + 0.45 * R, cy - 0.95 * R], 0.9 * R, s.t, 0.08 * H);
end

% --- straw -----------------------------------------------------------------------
sw = 0.022 * H;
st.width = sw;
st.mouth = m.mouth.centre;
if ismember(s.pose, ["celebrate" "tryagain" "sleep"])
    st.mouth = [cx + 1.04 * R, cy - 0.1 * R];   % let go: the straw stops short of the face
end
if s.pose == "ready"                        % the tip wiggles: "come on!"
    st.mouth = st.mouth + [0, 0.006 * H * sin(2 * pi * 1.5 * s.t)];
end
st.elbow = [ux, cy - 0.1 * R];          % level with the untilted mouth
st.bottom = [ux, tableY - 0.025 * H];

% motion lines along the straw while slurping (they run towards the mouth)
m.motion = zeros(0, 4);
if s.pose == "slurp"
    len = st.elbow(1) - st.mouth(1);
    for k = 0:2
        ph = mod(k / 3 - 1.5 * s.t, 1);    % 0..1 along the straw from the mouth
        x = st.mouth(1) + (0.12 + 0.8 * ph) * len;
        for side = [-1 1]
            y = st.mouth(2) + side * 1.4 * sw;
            m.motion(end + 1, :) = [x, y, x + 0.12 * len, y];
        end
    end
end
g.monster = m;

% --- mouse -------------------------------------------------------------------------
mp = s.mousePose;
if s.reveal ~= "", mp = s.reveal; end
if mp == "" && ~isnan(s.mouseX), mp = "run"; end
if mp == "" || (mp == "run" && isnan(s.mouseX)), mp = "hidden"; end
mo.pose = mp; mo.size = 0.055 * H; mo.zees = zeros(0, 4);
mo.x = NaN; mo.y = NaN;
st.pinch = struct('active', false, 'x', NaN, 'halfLen', NaN, 'halfWidth', NaN);
switch mp
    case "run"
        mo.size = 0.05 * H; mo.x = 0.1 * W + 0.8 * W * s.mouseX; mo.y = 0.92 * H;
    case "pinch"
        x = st.mouth(1) + 0.58 * (st.elbow(1) - st.mouth(1));
        st.pinch = struct('active', true, 'x', x, 'halfLen', 0.045 * H, 'halfWidth', 0.12 * sw);
        mo.x = x; mo.y = st.elbow(2);
    case "sleep"
        mo.x = min(ux + 0.25 * H, W - 0.1 * H); mo.y = g.groundY + 0.09 * H;
        mo.zees = zees([mo.x - 1.2 * mo.size, mo.y - 1.4 * mo.size], 1.6 * mo.size, s.t, 0.6 * mo.size);
end
st.visible = s.straw || st.pinch.active;    % a pinch needs a straw
g.straw = st;
mo.spotlight = struct('active', s.reveal ~= "", 'disc', [NaN NaN NaN NaN]);
if mo.spotlight.active
    if mp == "pinch", c = [mo.x, mo.y - 0.6 * mo.size]; else, c = [mo.x - 0.2 * mo.size, mo.y - 0.3 * mo.size]; end
    mo.spotlight.disc = disc(c(1), c(2), 2.6 * mo.size);
end
g.mouse = mo;

% --- bubbles (as before) ----------------------------------------------------------------
g.bubbles = zeros(0, 3);
if ~isnan(s.bubbles)
    for k = 1:3
        p = mod(s.bubbles + (k - 1) / 3, 1);
        g.bubbles(k, :) = [m.mouth.centre(1) + (0.15 + 0.3 * (k - 1)) * R, ...
            m.mouth.centre(2) - 0.05 * H - p * 0.4 * H, (0.04 + 0.03 * k) * R];
    end
end

% --- progress: star row and done cups (as before) -----------------------------------------
g.starR = 0.025 * H; y0 = 0.07 * H; n = s.starsPerCup;
k = (1:n)';
sx = 0.5 * W + (k - (n + 1) / 2) * 2.4 * g.starR;
g.slots = [sx - g.starR, y0 - g.starR + 0 * k, sx + g.starR, y0 + g.starR + 0 * k];
g.slotFilled = k <= s.stars;
k = (1:s.nCups)';
x = 0.9 * W + (k - s.nCups) * 0.035 * H;
g.cupSlots = [x - 0.012 * H, y0 - 0.025 * H + 0 * k, x + 0.012 * H, y0 + 0.025 * H + 0 * k];
g.cupSlotFilled = k <= s.cupsDone;
g.cupSlotColour = g.flavours(mod(k - 1, 4) + 1, :);

% star flight: from the belly on an arc to the next empty slot, shrinking as it lands
g.fly = struct('active', false, 'slot', NaN, 'pos', [NaN NaN], 'r', NaN, 'angle', 0);
if ~isnan(s.flyStar) && s.stars < n
    p = min(max(s.flyStar, 0), 1);
    a = [cx, cy + 0.25 * R];
    b = [sx(s.stars + 1), y0];
    d = b - a;
    ctrl = (a + b) / 2 + 0.5 * norm(d) * [d(2), -d(1)] / norm(d);   % bulges up and out
    g.fly = struct('active', true, 'slot', s.stars + 1, ...
        'pos', (1 - p)^2 * a + 2 * (1 - p) * p * ctrl + p^2 * b, ...
        'r', g.starR * (1 + 1.6 * (1 - p)), 'angle', 2 * pi * p);
end

% cup tip: the drunk cup tilts over and flies into the next empty slot of the done row
g.tip = struct('active', false, 'slot', NaN, 'poly', zeros(0, 2), 'angle', 0, 'colour', g.shake, 'fill', 0);
if ~isnan(s.cupTip) && s.cupsDone < s.nCups
    p = min(max(s.cupTip, 0), 1);
    e = p^2 * (3 - 2 * p);                  % ease in and out
    r = g.cupSlots(s.cupsDone + 1, :);
    target = [r(1) r(2); r(3) r(2); r(3) r(4); r(1) r(4)];
    poly = (1 - e) * g.cup.poly + e * target;
    ang = 0.6 * sin(pi * p);                % tips over on the way, upright on arrival
    c = mean(poly, 1);
    g.tip = struct('active', true, 'slot', s.cupsDone + 1, ...
        'poly', (poly - c) * [cos(ang) sin(ang); -sin(ang) cos(ang)] + c, ...
        'angle', ang, 'colour', g.shake, 'fill', e);   % fills with its flavour on the way
    g.cup.visible = false;
    g.straw.visible = false;                % nothing left to drink from
end

% nap bar: drains as the rest runs out
g.restBar = struct('active', false, 'outer', [NaN NaN NaN NaN], 'fill', [NaN NaN NaN NaN]);
if ~isnan(s.restLeft)
    left = min(max(s.restLeft, 0), 1);
    o = [ux - 0.2 * H, 0.17 * H, ux + 0.2 * H, 0.21 * H];   % above the cup, clear of the Z's
    g.restBar = struct('active', true, 'outer', o, 'fill', [o(1), o(2), o(1) + left * (o(3) - o(1)), o(4)]);
end

% --- text --------------------------------------------------------------------------------
g.textX = 0.02 * W; g.textBottom = 0.975 * H; g.textScale = 0.6;
g.childTextY = 0.2 * H; g.childTextScale = 1.6;
end

function s = fillIn(s)
d = struct('belly', 0, 'cup', 1, 'straw', true, 'mouseX', NaN, 'bubbles', NaN, ...
    'wiggle', 0, 'stars', 0, 'cupsDone', 0, 'starsPerCup', 10, 'nCups', 4, 'text', '', ...
    'pose', "idle", 't', 0, 'mousePose', "", 'reveal', "", 'flyStar', NaN, 'cupTip', NaN, ...
    'restLeft', NaN, 'flavour', 1, 'childText', '');
for f = fieldnames(d)'
    if ~isfield(s, f{1}), s.(f{1}) = d.(f{1}); end
end
s.pose = name(s.pose, ["idle" "ready" "slurp" "ahh" "tryagain" "celebrate" "sleep" "strain"], 'pose');
s.mousePose = name(s.mousePose, ["" "run" "pinch" "sleep" "hidden"], 'mousePose');
s.reveal = name(s.reveal, ["" "pinch" "sleep"], 'reveal');
f = s.flavour;
if ~(isnumeric(f) && isscalar(f) && f >= 1 && f == round(f))
    error('rrst:badPose', 'flavour must be a whole number from 1 (got %s).', mat2str(f));
end
s.flavour = mod(f - 1, 4) + 1;
end

function v = name(v, allowed, field)
if ~((ischar(v) && (isrow(v) || isempty(v))) || (isstring(v) && isscalar(v)))
    error('rrst:badPose', '%s must be text, one of: %s.', field, strjoin(allowed, ', '));
end
v = string(v);
if ~ismember(v, allowed)
    error('rrst:badPose', 'Unknown %s "%s"; use one of: %s.', field, v, strjoin(allowed(allowed ~= ""), ', '));
end
end

function z = zees(base, rise, t, h)
% Three Z's drifting up and to the right from base, one every 2/3 s; [x y h alpha].
z = zeros(3, 4);
for k = 1:3
    p = mod(t / 2 + (k - 1) / 3, 1);
    z(k, :) = [base(1) + 0.5 * p * rise, base(2) - p * rise, h * (0.5 + 0.5 * p), min(1, 4 * (1 - p))];
end
end

function l = brow(P, u, v, slope)
% Eyebrow centred over (u, v) in body radii; slope > 0 raises its right end.
a = P(u - 0.15, v + slope / 2); b = P(u + 0.15, v - slope / 2);
l = [a b];
end

function q = rot(p, a)
q = p * [cos(a) sin(a); -sin(a) cos(a)];
end

function r = disc(x, y, rad)
r = [x - rad, y - rad, x + rad, y + rad];
end
