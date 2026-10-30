classdef TestKidsScene < matlab.unittest.TestCase
    % RRST-Kids Milkshake Monster scene. The geometry and the poses (kidsPose) are pure
    % and tested for any window; the drawing (kidsScene) runs against the Psychtoolbox
    % stand-ins for every pose and state and, when Psychtoolbox can open a small window
    % here, is rendered and checked.

    properties (Constant)
        % Full HD, the stim laptop's external screen, the 1/3-size test window
        % (cfg.smallWindow), a 4:3 projector and a tall window.
        Windows = {[0 0 1600 900], [0 0 2560 1440], [0 0 2560 1440] / 3, ...
            [0 0 1024 768], [0 0 900 1000]}
        Poses = ["idle" "ready" "slurp" "ahh" "tryagain" "celebrate" "sleep" "strain"]
        MousePoses = ["run" "pinch" "sleep" "hidden"]
        Reveals = ["" "pinch" "sleep"]
        Win = [0 0 1600 900]
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', 'code');
            addpath(p);
            tc.addTeardown(@() rmpath(p));
        end
    end

    methods (Test)
        % --- the fields kidsMain passes today keep their meaning and defaults -------
        function legacyDefaultsUnchanged(tc)
            g = kidsPose(struct(), tc.Win);
            s = g.s;
            tc.verifyEqual(s.belly, 0);
            tc.verifyEqual(s.cup, 1);
            tc.verifyEqual(s.straw, true);
            tc.verifyTrue(isnan(s.mouseX));
            tc.verifyTrue(isnan(s.bubbles));
            tc.verifyEqual(s.wiggle, 0);
            tc.verifyEqual(s.stars, 0);
            tc.verifyEqual(s.cupsDone, 0);
            tc.verifyEqual(s.starsPerCup, 10);
            tc.verifyEqual(s.nCups, 4);
            tc.verifyEqual(s.text, '');
            % and the new ones
            tc.verifyEqual(s.pose, "idle");
            tc.verifyEqual(s.t, 0);
            tc.verifyEqual(s.reveal, "");
            tc.verifyTrue(isnan(s.flyStar));
            tc.verifyTrue(isnan(s.cupTip));
            tc.verifyTrue(isnan(s.restLeft));
            tc.verifyEqual(s.flavour, 1);
            tc.verifyEqual(s.childText, '');
            tc.verifyEqual(g.mouse.pose, "hidden", 'no mouseX: no mouse');
            tc.verifyTrue(g.straw.visible);
            tc.verifyFalse(g.straw.pinch.active);
            tc.verifyFalse(g.fly.active);
            tc.verifyFalse(g.tip.active);
            tc.verifyFalse(g.restBar.active);
            tc.verifyTrue(g.cup.visible);
        end

        function legacyFieldsKeepTheirMeaning(tc)
            r = tc.Win; W = r(3); H = r(4);
            s = struct('belly', 0.6, 'cup', 0.25, 'straw', false, 'mouseX', 0.3, ...
                'bubbles', 0.4, 'wiggle', 15, 'stars', 4, 'cupsDone', 1, 'text', 'Big slurp!');
            g = kidsPose(s, r);
            for f = string(fieldnames(s))'
                tc.verifyEqual(g.s.(f), s.(f), f);
            end
            m = g.monster;
            tc.verifyEqual(m.centre(1), 0.36 * W + 15, 'AbsTol', 1e-9, 'wiggle shifts the monster');
            tc.verifyEqual(m.R, 0.22 * H, 'AbsTol', 1e-9);
            tc.verifyEqual(width(m.belly) / 2, m.R * (0.28 + 0.34 * 0.6), 'AbsTol', 1e-9, 'belly');
            tc.verifyEqual(g.mouse.pose, "run", 'mouseX alone: the running mouse');
            tc.verifyEqual(g.mouse.x, 0.1 * W + 0.8 * W * 0.3, 'AbsTol', 1e-9);
            tc.verifyEqual(g.mouse.y, 0.92 * H, 'AbsTol', 1e-9);
            tc.verifyFalse(g.straw.visible);
            tc.verifyEqual(size(g.bubbles, 1), 3);
            tc.verifyEqual(nnz(g.slotFilled), 4);
            tc.verifyEqual(nnz(g.cupSlotFilled), 1);
            fill = g.cup.fill; cup = g.cup.poly;
            level = (max(fill(:, 2)) - min(fill(:, 2))) / (max(cup(:, 2)) - min(cup(:, 2)));
            tc.verifyEqual(level, 0.25, 'AbsTol', 0.02, 'cup level');
        end

        % --- poses ------------------------------------------------------------------
        function everyPoseIsAccepted(tc)
            for p = tc.Poses
                g = kidsPose(struct('pose', p), tc.Win);
                tc.verifyEqual(g.s.pose, p);
                g = kidsPose(struct('pose', char(p)), tc.Win);   % char works too
                tc.verifyEqual(g.s.pose, p);
            end
            for p = tc.MousePoses
                g = kidsPose(struct('mousePose', p, 'mouseX', 0.5), tc.Win);
                tc.verifyEqual(g.mouse.pose, p);
            end
            for p = tc.Reveals
                g = kidsPose(struct('reveal', p), tc.Win);
                tc.verifyEqual(g.s.reveal, p);
            end
        end

        function unknownPosesError(tc)
            tc.verifyError(@() kidsPose(struct('pose', "sad"), tc.Win), 'rrst:badPose');
            tc.verifyError(@() kidsPose(struct('pose', 3), tc.Win), 'rrst:badPose');
            tc.verifyError(@() kidsPose(struct('mousePose', "dance"), tc.Win), 'rrst:badPose');
            tc.verifyError(@() kidsPose(struct('reveal', "mouse"), tc.Win), 'rrst:badPose');
            tc.verifyError(@() kidsPose(struct('flavour', 0), tc.Win), 'rrst:badPose');
            tc.verifyError(@() kidsPose(struct('flavour', 1.5), tc.Win), 'rrst:badPose');
        end

        function posesLookDifferent(tc)
            % Each pose changes the face: no two poses give the same eyes and mouth.
            key = strings(size(tc.Poses));
            for k = 1:numel(tc.Poses)
                m = kidsPose(struct('pose', tc.Poses(k), 't', 1), tc.Win).monster;
                key(k) = strjoin([[m.eyes.state], m.mouth.type, string(~isempty(m.arms)), ...
                    string(size(m.brows, 1)), string(m.tilt ~= 0), string(~isempty(m.puffs))], "/");
            end
            tc.verifyEqual(numel(unique(key)), numel(key), strjoin(key, ", "));
        end

        function tryAgainIsNeverSad(tc)
            m = kidsPose(struct('pose', "tryagain"), tc.Win).monster;
            tc.verifyNotEqual(m.mouth.type, "frown");
            tc.verifyNotEqual(m.tilt, 0, 'head tilt');
            tc.verifyEqual(size(m.brows, 1), 1, 'one eyebrow up');
            tc.verifyTrue(all([m.eyes.state] == "open"));
        end

        function celebrateRaisesTheArms(tc)
            m = kidsPose(struct('pose', "celebrate"), tc.Win).monster;
            tc.verifyEqual(size(m.arms, 1), 2);
            tc.verifyTrue(all(m.hands(:, 2) < m.centre(2) - 0.5 * m.R), 'hands above the head line');
            for p = setdiff(tc.Poses, "celebrate")
                tc.verifyEmpty(kidsPose(struct('pose', p), tc.Win).monster.arms, p);
            end
        end

        function readyLooksAtTheViewerAndIdleAtTheCup(tc)
            idle = kidsPose(struct('pose', "idle"), tc.Win).monster;
            ready = kidsPose(struct('pose', "ready"), tc.Win).monster;
            for k = 1:2
                tc.verifyGreaterThan(idle.eyes(k).pupil(1), idle.eyes(k).centre(1), 'idle: towards the cup');
                tc.verifyEqual(ready.eyes(k).pupil(1), ready.eyes(k).centre(1), 'AbsTol', 1e-9, 'ready: at the viewer');
            end
            tc.verifyEqual(ready.mouth.type, "round");
            tc.verifyEqual(size(ready.brows, 1), 2, 'eyebrows up');
            % the straw tip wiggles with t
            a = kidsPose(struct('pose', "ready", 't', 0.1), tc.Win).straw.mouth;
            b = kidsPose(struct('pose', "ready", 't', 0.3), tc.Win).straw.mouth;
            tc.verifyNotEqual(a, b);
            tc.verifyLessThan(norm(a - b), 0.02 * tc.Win(4), 'slightly');
        end

        function slurpShowsMotionAtTheStraw(tc)
            g = kidsPose(struct('pose', "slurp", 't', 0.2), tc.Win);
            tc.verifyNotEmpty(g.monster.motion);
            tc.verifyNotEmpty(g.monster.hollows, 'cheeks pulled in');
            tc.verifyTrue(all([g.monster.eyes.state] == "happy"));
            tc.verifyEmpty(kidsPose(struct('pose', "idle"), tc.Win).monster.motion);
        end

        function strainPuffsTheCheeks(tc)
            m = kidsPose(struct('pose', "strain"), tc.Win).monster;
            tc.verifyEqual(size(m.puffs, 1), 2);
            tc.verifyTrue(all([m.eyes.state] == "wide"));
        end

        % --- blink ------------------------------------------------------------------
        function blinkIsShortAndRegular(tc)
            dt = 0.005; t = 0:dt:9 - dt;
            closed = false(size(t));
            for k = 1:numel(t)
                g = kidsPose(struct('pose', "idle", 't', t(k)), tc.Win);
                closed(k) = g.blink;
                tc.assertEqual([g.monster.eyes.state] == "closed", [1 1] * closed(k));
            end
            tc.verifyFalse(closed(1), 'eyes open at t = 0');
            tc.verifyEqual(nnz(diff([false closed]) == 1), 3, 'one blink every 3 s');
            perBlink = nnz(closed) * dt / 3;
            tc.verifyGreaterThan(perBlink, 0.05);
            tc.verifyLessThan(perBlink, 0.3, 'a short blink');
            tc.verifyFalse(kidsPose(struct('pose', "ready", 't', t(find(closed, 1))), tc.Win).blink, ...
                'only idle blinks');
        end

        % --- nap ----------------------------------------------------------------------
        function napZeesRise(tc)
            g0 = kidsPose(struct('pose', "sleep", 't', 0), tc.Win);
            g1 = kidsPose(struct('pose', "sleep", 't', 0.1), tc.Win);
            tc.verifyEqual(size(g0.monster.zees, 2), 4);
            tc.verifyGreaterThanOrEqual(size(g0.monster.zees, 1), 2);
            tc.verifyTrue(all([g0.monster.eyes.state] == "content"));
            % every Z that has not wrapped round moved up
            moved = g1.monster.zees(:, 2) - g0.monster.zees(:, 2);
            tc.verifyTrue(any(moved < 0) && all(moved < 0 | moved > 0.05 * tc.Win(4)));
            tc.verifyTrue(all(g0.monster.zees(:, 2) < g0.monster.centre(2)), 'above the head');
            tc.verifyEmpty(kidsPose(struct('pose', "idle"), tc.Win).monster.zees);
        end

        function restBarDrains(tc)
            full = kidsPose(struct('pose', "sleep", 'restLeft', 1), tc.Win).restBar;
            half = kidsPose(struct('pose', "sleep", 'restLeft', 0.5), tc.Win).restBar;
            none = kidsPose(struct('pose', "sleep", 'restLeft', 0), tc.Win).restBar;
            tc.verifyTrue(full.active);
            tc.verifyEqual(width(full.fill), width(full.outer), 'AbsTol', 1);
            tc.verifyEqual(width(half.fill), width(full.fill) / 2, 'AbsTol', 1);
            tc.verifyLessThanOrEqual(width(none.fill), 0);
        end

        % --- mouse and reveal -----------------------------------------------------------
        function pinchNarrowsTheStraw(tc)
            for g = [kidsPose(struct('mousePose', "pinch", 'mouseX', 0.5), tc.Win), ...
                    kidsPose(struct('reveal', "pinch"), tc.Win)]
                tc.verifyEqual(g.mouse.pose, "pinch");
                tc.verifyTrue(g.straw.visible);
                tc.verifyTrue(g.straw.pinch.active);
                tc.verifyLessThan(g.straw.pinch.halfWidth, 0.3 * g.straw.width);
                x = g.straw.pinch.x;
                tc.verifyTrue(x > g.straw.mouth(1) && x < g.straw.elbow(1), 'pinch on the straw');
                tc.verifyEqual(g.mouse.x, x, 'AbsTol', 1e-9, 'mouse at the pinch');
            end
        end

        function revealUsesASpotlight(tc)
            g = kidsPose(struct('reveal', "sleep", 'mouseX', 0.1), tc.Win);
            tc.verifyEqual(g.mouse.pose, "sleep", 'reveal wins over the running mouse');
            tc.verifyFalse(g.straw.pinch.active);
            tc.verifyTrue(g.mouse.spotlight.active);
            tc.verifyNotEmpty(g.mouse.zees);
            sl = g.mouse.spotlight.disc;
            tc.verifyEqual(mean(sl([1 3])), g.mouse.x, 'AbsTol', 0.3 * width(sl));
            p = kidsPose(struct('reveal', "pinch"), tc.Win);
            tc.verifyTrue(p.mouse.spotlight.active);
            tc.verifyFalse(kidsPose(struct('mousePose', "pinch"), tc.Win).mouse.spotlight.active, ...
                'spotlight only for the reveal');
            tc.verifyFalse(kidsPose(struct('mouseX', 0.5), tc.Win).mouse.spotlight.active);
            tc.verifyEqual(kidsPose(struct('mousePose', "hidden", 'mouseX', 0.5), tc.Win).mouse.pose, "hidden");
        end

        function sleepingMouseStaysOnScreen(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k};
                for rv = ["" "sleep"]
                    g = kidsPose(struct('mousePose', "sleep", 'reveal', rv), r);
                    tc.verifyTrue(g.mouse.x + 1.5 * g.mouse.size <= r(3) && g.mouse.x - 1.5 * g.mouse.size >= 0);
                    tc.verifyTrue(g.mouse.y + g.mouse.size <= r(4) && g.mouse.y >= g.groundY);
                end
            end
        end

        % --- star flight and cup tip --------------------------------------------------
        function starFliesFromTheBellyToTheNextSlot(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k};
                for n = 0:9
                    g0 = kidsPose(struct('stars', n, 'flyStar', 0), r);
                    g1 = kidsPose(struct('stars', n, 'flyStar', 1), r);
                    tc.verifyTrue(g0.fly.active);
                    tc.verifyEqual(g0.fly.slot, n + 1);
                    tc.verifyEqual(g0.fly.pos, belly(g0), 'AbsTol', 1e-9, 'starts at the belly');
                    slot = g1.slots(n + 1, :);
                    tc.verifyTrue(inside([g1.fly.pos g1.fly.pos], slot), sprintf('lands in slot %d', n + 1));
                    tc.verifyLessThanOrEqual(g1.fly.r, g1.starR + 1e-9, 'lands at slot size');
                    tc.verifyGreaterThan(g0.fly.r, g1.fly.r, 'scales down as it lands');
                    tc.verifyFalse(g1.slotFilled(n + 1), 'the slot fills when stars goes up');
                    % the path is an arc: halfway is not on the straight line
                    gm = kidsPose(struct('stars', n, 'flyStar', 0.5), r);
                    a = g0.fly.pos; b = g1.fly.pos; m = gm.fly.pos;
                    off = abs((b(1) - a(1)) * (a(2) - m(2)) - (a(1) - m(1)) * (b(2) - a(2))) / norm(b - a);
                    tc.verifyGreaterThan(off, 0.02 * r(4), 'arc');
                end
            end
            tc.verifyFalse(kidsPose(struct('stars', 10, 'flyStar', 0.5), tc.Win).fly.active, 'no empty slot');
        end

        function cupTipsIntoTheDoneRow(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k};
                for n = 0:3
                    g0 = kidsPose(struct('cupsDone', n, 'cupTip', 0, 'cup', 0), r);
                    g1 = kidsPose(struct('cupsDone', n, 'cupTip', 1, 'cup', 0), r);
                    gm = kidsPose(struct('cupsDone', n, 'cupTip', 0.5, 'cup', 0), r);
                    tc.verifyTrue(g1.tip.active);
                    tc.verifyFalse(g0.cup.visible, 'the table cup is the one tipping');
                    tc.verifyEqual(g1.tip.slot, n + 1);
                    tc.verifyEqual(bbox(g0.tip.poly), bbox(g0.cup.poly), 'AbsTol', 1e-6, 'starts on the table');
                    tc.verifyEqual(bbox(g1.tip.poly), g1.cupSlots(n + 1, :), 'AbsTol', 1e-6, 'ends in the done row');
                    tc.verifyNotEqual(gm.tip.angle, 0, 'tilts on the way');
                    tc.verifyEqual(g1.tip.colour, g1.shake);
                end
            end
            tc.verifyFalse(kidsPose(struct('cupsDone', 4, 'cupTip', 0.5), tc.Win).tip.active, 'no empty cup slot');
        end

        % --- flavours ----------------------------------------------------------------
        function flavoursAreDistinct(tc)
            cols = zeros(4, 3);
            for f = 1:4
                cols(f, :) = kidsPose(struct('flavour', f), tc.Win).shake;
            end
            tc.verifyEqual(cols(1, :), [1 0.6 0.75], 'AbsTol', 1e-9, 'flavour 1 is the pink of today');
            for a = 1:4
                for b = a + 1:4
                    tc.verifyGreaterThan(norm(cols(a, :) - cols(b, :)), 0.25, sprintf('%d vs %d', a, b));
                end
            end
            tc.verifyTrue(all(cols(:) >= 0 & cols(:) <= 1));
            g = kidsPose(struct('flavour', 3, 'cupsDone', 4), tc.Win);
            tc.verifyEqual(g.cupSlotColour, cols, 'AbsTol', 1e-9, 'cup k in the done row has flavour k');
            tc.verifyEqual(kidsPose(struct('flavour', 5), tc.Win).shake, cols(1, :), 'AbsTol', 1e-9, 'wraps round');
            g = kidsPose(struct('nCups', 6, 'cupsDone', 6), tc.Win);
            tc.verifyEqual(g.cupSlotColour(5:6, :), cols(1:2, :), 'AbsTol', 1e-9);
        end

        % --- scaling -----------------------------------------------------------------
        function everythingScalesWithTheWindow(tc)
            big = [0 0 2560 1440]; small = big / 3;
            states = {struct(), struct('pose', "celebrate", 'wiggle', 30, 'belly', 0.5), ...
                struct('pose', "sleep", 't', 1.3, 'restLeft', 0.4, 'mousePose', "sleep"), ...
                struct('pose', "strain", 'reveal', "pinch"), struct('pose', "slurp", 't', 0.4, 'bubbles', 0.3), ...
                struct('stars', 3, 'flyStar', 0.4), struct('cupsDone', 2, 'cupTip', 0.6), ...
                struct('mouseX', 0.4), struct('pose', "ready", 't', 0.7), struct('pose', "tryagain")};
            for k = 1:numel(states)
                s = states{k};
                if isfield(s, 'wiggle'), sb = s; sb.wiggle = 3 * s.wiggle; else, sb = s; end
                b = geometry(kidsPose(sb, big)); a = geometry(kidsPose(s, small));
                tc.verifyEqual(fieldnames(a), fieldnames(b));
                for f = fieldnames(a)'
                    tc.verifyEqual(a.(f{1}), b.(f{1}) / 3, 'AbsTol', 1e-6, sprintf('state %d: %s', k, f{1}));
                end
            end
        end

        function sceneStandsOnTheGround(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k}; g = kidsPose(struct(), r);
                tc.verifyEqual(g.ground([1 3 4]), [0 r(3) r(4)], 'AbsTol', 1e-9);
                tc.verifyEqual(g.ground(2), g.groundY);
                tc.verifyEqual(max(g.cup.poly(:, 2)), g.table.top(2), 'AbsTol', 1e-9, 'cup on the table');
                tc.verifyEqual(max(g.table.legs(:, 4)), g.groundY, 'AbsTol', 1e-9, 'table on the ground');
                tc.verifyGreaterThanOrEqual(g.monster.feet(1, 4), g.groundY, 'monster on the ground');
                tc.verifyLessThan(g.monster.feet(1, 2), g.groundY);
                tc.verifyLessThan(g.straw.elbow(2), min(g.cup.poly(:, 2)), 'straw comes out of the top');
                tc.verifyLessThan(g.childTextY, g.monster.body(2), 'child text above the monster');
            end
        end

        % --- drawing --------------------------------------------------------------------
        function drawsEveryPoseAndStateWithTheStandIns(tc)
            here = fileparts(mfilename('fullpath'));
            stubs = fullfile(here, 'ptbstubs');
            addpath(stubs);
            tc.addTeardown(@() rmpath(stubs));
            states = {struct(), struct('straw', false, 'text', 'Getting the straw ready...'), ...
                struct('mouseX', 0.9, 'text', 'Line one\nLine two'), struct('mouseX', 0.1, 'straw', false), ...
                struct('belly', 0.7, 'cup', 0.4, 'text', 'Big slurp!'), struct('bubbles', 0.3, 'cup', 0.2), ...
                struct('cup', 0, 'wiggle', 15), struct('stars', 10, 'cupsDone', 4), ...
                struct('childText', 'Hello!')};
            for k = 1:numel(tc.Windows)
                scr = struct('win', 1, 'winRect', tc.Windows{k}, 'colours', colours());
                for i = 1:numel(states), kidsScene(scr, states{i}); end
                for p = tc.Poses
                    for t = [0 0.4 2.9]
                        kidsScene(scr, struct('pose', p, 't', t, 'belly', 0.4, 'bubbles', 0.5));
                    end
                end
                for mp = tc.MousePoses, kidsScene(scr, struct('mousePose', mp, 'mouseX', 0.5)); end
                for rv = tc.Reveals, kidsScene(scr, struct('reveal', rv, 'cup', 0)); end
                for p = [0 0.3 1], kidsScene(scr, struct('stars', 5, 'flyStar', p)); end
                for p = [0 0.3 1], kidsScene(scr, struct('cupsDone', 1, 'cupTip', p, 'cup', 0)); end
                for f = 1:4, kidsScene(scr, struct('flavour', f, 'cupsDone', 3, 'cup', 0.5)); end
                kidsScene(scr, struct('pose', "sleep", 'restLeft', 0.3, 'straw', false));
            end
        end

        function rendersTheSceneInARealWindow(tc)
            tc.assumeTrue(endsWith(which('Screen'), mexext), 'Psychtoolbox is not on the path.');
            oldSync = Screen('Preference', 'SkipSyncTests', 1);
            oldDebug = Screen('Preference', 'VisualDebugLevel', 0);
            oldVerb = Screen('Preference', 'Verbosity', 0);
            tc.addTeardown(@() Screen('Preference', 'SkipSyncTests', oldSync));
            tc.addTeardown(@() Screen('Preference', 'VisualDebugLevel', oldDebug));
            tc.addTeardown(@() Screen('Preference', 'Verbosity', oldVerb));
            c = colours();
            try
                [w, r] = Screen('OpenWindow', max(Screen('Screens')), c.background * 255, [0 0 640 360]);
            catch err
                tc.assumeFail(['Psychtoolbox cannot open a window here: ' err.message]);
            end
            tc.addTeardown(@() Screen('Close', w));
            Screen('ColorRange', w, 1);
            Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            Screen('TextFont', w, 'Arial');
            Screen('TextSize', w, round(48 * r(4) / 1440));
            scr = struct('win', w, 'winRect', r, 'colours', c);
            for f = 1:4
                s = struct('flavour', f, 'cup', 1);
                kidsScene(scr, s);
                img = double(Screen('GetImage', w, [], 'backBuffer')) / 255;
                Screen('Flip', w);
                g = kidsPose(s, r);
                tc.verifyTrue(hasColour(region(img, bbox(g.cup.fill)), g.shake), sprintf('flavour %d in the cup', f));
                tc.verifyTrue(hasColour(region(img, g.monster.body), c.monster), 'monster');
                tc.verifyTrue(hasColour(img(end - 2, :, :), g.groundColour), 'ground');
            end
        end
    end
end

function c = colours()
% The colours openScreen in kidsMain sets.
c = struct('background', [0.55 0.82 0.95], 'monster', [150 80 200] / 255, ...
    'monsterDark', [110 55 160] / 255, 'belly', [200 160 235] / 255, 'mouth', [0.25 0.05 0.2], ...
    'shake', [1 0.6 0.75], 'straw', [1 0.95 0.5], 'bubble', [1 1 1], 'mouse', [0.6 0.6 0.62], ...
    'mouseEar', [1 0.7 0.75], 'star', [1 0.82 0.1], 'slot', [1 1 1], 'text', [0.1 0.1 0.25], ...
    'easy', [0.3 0.75 0.4], 'squishy', [0.9 0.35 0.35]);
end

function p = belly(g)
b = g.monster.belly; p = [(b(1) + b(3)) / 2, (b(2) + b(4)) / 2];
end

function a = geometry(g)
% The pixel geometry of a pose (positions and sizes; no colours, angles or flags).
m = g.monster;
a.body = m.body; a.belly = m.belly; a.feet = m.feet; a.R = m.R;
a.eyes = vertcat(m.eyes.rect); a.pupils = vertcat(m.eyes.pupil);
a.mouth = m.mouth.rect; a.brows = m.brows; a.arms = m.arms; a.hands = m.hands;
a.puffs = m.puffs; a.hollows = m.hollows; a.motion = m.motion;
if isempty(m.zees), a.zees = []; else, a.zees = m.zees(:, 1:3); end
a.ground = g.ground; a.tableTop = g.table.top; a.legs = g.table.legs;
a.cup = g.cup.poly; a.fill = g.cup.fill;
a.straw = [g.straw.mouth; g.straw.elbow; g.straw.bottom]; a.strawW = g.straw.width;
a.slots = g.slots; a.starR = g.starR; a.cupSlots = g.cupSlots;
a.mouse = [g.mouse.x g.mouse.y g.mouse.size];
a.bubbles = g.bubbles;
if g.fly.active, a.fly = [g.fly.pos g.fly.r]; end
if g.tip.active, a.tip = g.tip.poly; end
if g.restBar.active, a.rest = [g.restBar.outer; g.restBar.fill]; end
if g.mouse.spotlight.active, a.spot = g.mouse.spotlight.disc; end
if g.straw.pinch.active, a.pinch = [g.straw.pinch.x g.straw.pinch.halfLen g.straw.pinch.halfWidth]; end
end

function w = width(r), w = r(3) - r(1); end

function r = bbox(p), r = [min(p(:, 1)), min(p(:, 2)), max(p(:, 1)), max(p(:, 2))]; end

function tf = inside(a, b)
% Rect a lies within rect b (1 px tolerance).
tf = a(1) >= b(1) - 1 && a(2) >= b(2) - 1 && a(3) <= b(3) + 1 && a(4) <= b(4) + 1;
end

function px = region(img, r)
r = round(r);
r = [max(r(1), 0), max(r(2), 0), min(r(3), size(img, 2)), min(r(4), size(img, 1))];
px = img(r(2) + 1:r(4), r(1) + 1:r(3), :);
end

function tf = hasColour(px, rgb)
px = reshape(px, [], 3);
tf = any(all(abs(px - rgb) < 3 / 255, 2));
end
