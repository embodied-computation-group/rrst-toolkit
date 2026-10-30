classdef TestKidsBeat < matlab.unittest.TestCase
    % RRST-Kids session beats (kidsBeat): which pose, mouse, reveal, star flight, cup
    % tip and nap each moment of the session shows, its length and its cue sound.
    % Pure: no screen, no clock. The scenes are checked through kidsPose and drawn
    % against the Psychtoolbox stand-ins (tests/ptbstubs).
    % Plan: docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, section 5.3 (U5-U8).

    properties (Constant)
        Beats = ["calibrating" "story1" "story2" "story3" "move" "ready" "reveal" ...
            "star" "cup" "nap" "stretch" "pause" "sticker" "thanks"]
        P = 0:0.05:1
        Win = [0 0 1600 900]
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', {'config', 'code'});
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(p));
        end
    end

    methods
        function c = ctx(~, stars, cupsDone, level)
            if nargin < 2, stars = 3; end
            if nargin < 3, cupsDone = 1; end
            if nargin < 4, level = 70; end
            cfg = kidsConfig();
            c = struct('stars', stars, 'cupsDone', cupsDone, 'nCups', 4, ...
                'txt', kidsText("en"), 'timing', cfg.timing, 'level', level);
        end
    end

    methods (Test)
        % --- every beat ----------------------------------------------------------------
        function everyBeatIsAValidScene(tc)
            for b = tc.Beats
                for p = tc.P
                    [s, dur, cue] = kidsBeat(b, p, tc.ctx());
                    g = kidsPose(s, tc.Win);                     % errors on a bad field
                    tc.verifyEqual(g.s.flavour, mod(s.cupsDone, 4) + 1, sprintf('%s %.2f: flavour = cupsDone + 1', b, p));
                    tc.verifyGreaterThanOrEqual(dur, 0);
                    tc.verifyTrue(cue == "" || ismember(cue, kidsSound.cueNames), b);
                    tc.verifyFalse(isfield(s, 't'), 'the clock is kidsMain''s');
                end
            end
        end

        function unknownBeatOrMissingLevelIsAnError(tc)
            tc.verifyError(@() kidsBeat("dance", 0, tc.ctx()), 'rrst:badBeat');
            c = rmfield(tc.ctx(), 'level');
            tc.verifyError(@() kidsBeat("reveal", 0, c), 'rrst:badBeat');
        end

        function lengthsAndCues(tc)
            c = tc.ctx(); t = c.timing;
            want = {"story1", 3, ""; "story2", 0.8, "mouse"; "story3", 1.5, ""; ...
                "move", t.moveMin, "mouse"; "ready", 0, "ready"; "reveal", 1.5, "mouse"; ...
                "star", t.reward, "star"; "cup", t.dance, "cup"; "nap", t.pause, ""; ...
                "stretch", 0.6, ""};
            for k = 1:size(want, 1)
                [~, dur, cue] = kidsBeat(want{k, 1}, 0, c);
                tc.verifyEqual(dur, want{k, 2}, 'AbsTol', 1e-12, want{k, 1});
                tc.verifyEqual(cue, want{k, 3}, want{k, 1});
            end
            [~, ~, cue] = kidsBeat("reveal", 0, tc.ctx(3, 1, 0));
            tc.verifyEqual(cue, "", 'catch reveal: the mouse is asleep, no scamper');
        end

        % --- story (U6) ------------------------------------------------------------------
        function storyBeatOneDrinksThenAhh(tc)
            c = tc.ctx();
            s = kidsBeat("story1", 0, c);
            tc.verifyEqual(s.pose, "slurp"); tc.verifyEqual(s.cup, 1);
            s = kidsBeat("story1", 1/3, c);
            tc.verifyEqual(s.pose, "slurp"); tc.verifyEqual(s.cup, 0.5, 'AbsTol', 1e-12, 'drains over the first 2 s');
            tc.verifyTrue(isnan(s.bubbles));
            s = kidsBeat("story1", 0.9, c);
            tc.verifyEqual(s.pose, "ahh"); tc.verifyEqual(s.cup, 0);
            tc.verifyTrue(s.bubbles > 0 && s.bubbles <= 1, 'bubbles');
            tc.verifyEqual(s.text, c.txt.story1);
            tc.verifyTrue(isnan(s.mouseX) && s.mousePose == "hidden", 'no mouse yet');
        end

        function storyBeatTwoShowsThePinch(tc)
            c = tc.ctx();
            for p = tc.P
                s = kidsBeat("story2", p, c);
                tc.verifyEqual(s.pose, "strain");
                tc.verifyEqual(s.mousePose, "pinch");
                g = kidsPose(s, tc.Win);
                tc.verifyTrue(g.straw.pinch.active);
                tc.verifyEqual(s.text, c.txt.story2);
            end
        end

        function storyBeatThreeTheMouseRunsOff(tc)
            c = tc.ctx();
            tc.verifyEqual(kidsBeat("story3", 0, c).mouseX, 0.3, 'AbsTol', 1e-12);
            tc.verifyEqual(kidsBeat("story3", 0.5, c).mouseX, 0.65, 'AbsTol', 1e-12);
            tc.verifyEqual(kidsBeat("story3", 1, c).mouseX, 1, 'AbsTol', 1e-12);
            s = kidsBeat("story3", 1, c);
            tc.verifyEqual(s.pose, "idle"); tc.verifyEqual(s.mousePose, "run");
            tc.verifyEqual(s.text, c.txt.story3);
            tc.verifyNotEqual(c.txt.story1, c.txt.story2);
            tc.verifyNotEqual(c.txt.story2, c.txt.story3);
        end

        % --- trial ------------------------------------------------------------------------
        function catchAndLoadTrialsLookTheSame(tc)
            % The move (scene, length, cue and the squeak mark) and the ready screen
            % do not depend on the level: a catch trial cannot be told from the screen.
            for b = ["move" "ready"]
                for p = tc.P
                    [s0, d0, c0, m0] = kidsBeat(b, p, tc.ctx(3, 1, 0));
                    for lv = [5 50 80 100]
                        [s1, d1, c1, m1] = kidsBeat(b, p, tc.ctx(3, 1, lv));
                        tc.verifyEqual({s1, d1, c1, m1}, {s0, d0, c0, m0}, sprintf('%s p %.2f level %g', b, p, lv));
                    end
                end
            end
            s = kidsBeat("ready", 1, tc.ctx());
            tc.verifyEqual(s.pose, "ready"); tc.verifyTrue(s.straw);
        end

        function moveRunsToTheCupThenCheekyThenHides(tc)
            % Second real run (2026-10-30): the mouse runs from the left to the cup (0
            % to 0.6 of the beat), stops there with a cheeky face (0.6 to 0.9) and hides
            % behind the cup (0.9 to 1). No straw: the monster waits.
            c = tc.ctx();
            prev = -Inf;
            for p = 0:0.01:0.59
                s = kidsBeat("move", p, c);
                tc.verifyEqual(s.mousePose, "toCup", sprintf('p %.2f', p));
                tc.verifyEqual(s.mouseProgress, p / 0.6, 'AbsTol', 1e-12);
                tc.verifyGreaterThan(s.mouseProgress, prev, 'runs one way');
                prev = s.mouseProgress;
                tc.verifyFalse(s.straw);
            end
            for p = 0.6:0.01:0.89
                s = kidsBeat("move", p, c);
                tc.verifyEqual(s.mousePose, "cheeky", sprintf('p %.2f', p));
                tc.verifyFalse(s.straw);
            end
            for p = 0.9:0.01:1
                s = kidsBeat("move", p, c);
                tc.verifyEqual(s.mousePose, "hide", sprintf('p %.2f', p));
                tc.verifyEqual(s.mouseProgress, (p - 0.9) / 0.1, 'AbsTol', 1e-9);
            end
            % on screen: from the left edge to the cup, then behind it
            g0 = kidsPose(kidsBeat("move", 0, c), tc.Win);
            gRun = kidsPose(kidsBeat("move", 0.59, c), tc.Win);
            gCheeky = kidsPose(kidsBeat("move", 0.75, c), tc.Win);
            gHid = kidsPose(kidsBeat("move", 1, c), tc.Win);
            tc.verifyLessThan(g0.mouse.x, 0.1 * tc.Win(3), 'starts at the left');
            tc.verifyEqual(gRun.mouse.x, gCheeky.mouse.x, 'AbsTol', 0.02 * tc.Win(3), 'stops where it ran to');
            tc.verifyTrue(gCheeky.mouse.cheeky.active);
            tc.verifyTrue(gHid.mouse.behind, 'hidden: drawn behind the cup');
        end

        function moveMarksTheSqueakAtTheCheekyMoment(tc)
            c = tc.ctx();
            [~, dur, cue, marks] = kidsBeat("move", 0, c);
            tc.verifyEqual(dur, c.timing.moveMin);
            tc.verifyEqual(cue, "mouse", 'the scamper at the start');
            tc.verifyEqual(numel(marks), 1);
            tc.verifyEqual(marks.p, 0.6, 'AbsTol', 1e-12, 'when the cheeky face starts');
            tc.verifyEqual(marks.cue, "squeak");
            tc.verifyTrue(ismember("squeak", kidsSound.cueNames));
            for b = setdiff(tc.Beats, "move")
                [~, ~, ~, m] = kidsBeat(b, 0, tc.ctx(3, 1, 70));
                tc.verifyEmpty(m, b);
            end
        end

        function moveProgressFollowsTheFirmware(tc)
            % p = min(elapsed / max(moveMin, moveSoFar + 0.5), 1): while the firmware
            % has not confirmed (moveS NaN) moveSoFar = elapsed and p stays below the
            % hide (0.9); after the confirmation at moveS, p reaches 1 at
            % max(moveMin, moveS + 0.5). Measured moves: 1.3-2.8 s; moveMin 1.5 s.
            moveMin = 1.5; tail = 0.5;
            for moveS = [0.05 0.4 1.3 2.8 6]
                tGrid = 0:0.01:moveS;
                p = arrayfun(@(e) kidsMoveProgress(e, NaN, moveMin, tail), tGrid);
                tc.verifyTrue(all(diff(p) >= 0), 'never runs backwards');
                tc.verifyLessThan(max(p), 0.9, sprintf('%.2f s: never hides before the wedge is in place', moveS));
                tEnd = max(moveMin, moveS + tail);
                tAfter = moveS:0.01:tEnd + 0.2;
                q = arrayfun(@(e) kidsMoveProgress(e, moveS, moveMin, tail), tAfter);
                tc.verifyEqual(q(1), kidsMoveProgress(moveS, NaN, moveMin, tail), 'AbsTol', 1e-12, 'no jump at the confirmation');
                tc.verifyTrue(all(diff(q) >= 0));
                tc.verifyLessThan(q(tAfter < tEnd - 1e-9), 1, 'not done before moveMin and the tail');
                tc.verifyEqual(q(tAfter >= tEnd), ones(1, nnz(tAfter >= tEnd)), 'done after both');
            end
            % a short move: the old linear animation over moveMin
            tc.verifyEqual(kidsMoveProgress(0.75, 0.2, moveMin, tail), 0.5, 'AbsTol', 1e-12);
            tc.verifyEqual(kidsMoveProgress(0, NaN, moveMin, tail), 0);
        end

        function moveSequenceForMeasuredMoveLengths(tc)
            % The frames kidsMain draws for a move of moveS seconds: run, cheeky, hide in
            % that order, the squeak mark crossed once, no hiding before the
            % confirmation, and every frame draws with the stand-ins.
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(here, 'ptbstubs')));
            scr = struct('win', 1, 'winRect', tc.Win, 'colours', sceneColours());
            c = tc.ctx(); order = ["toCup" "cheeky" "hide"];
            [~, ~, ~, marks] = kidsBeat("move", 0, c);
            for moveS = [0.3 1.3 2.8]
                tEnd = max(c.timing.moveMin, moveS + 0.5);
                pPrev = 0; nSqueak = 0; k = 1;
                for e = 0:1 / 60:tEnd + 1 / 60
                    if e < moveS, mS = NaN; else, mS = moveS; end
                    p = kidsMoveProgress(e, mS, c.timing.moveMin, 0.5);
                    s = kidsBeat("move", p, c);
                    i = find(order == s.mousePose);
                    tc.verifyGreaterThanOrEqual(i, k, 'run, cheeky, hide in order'); k = i;
                    if isnan(mS), tc.verifyNotEqual(s.mousePose, "hide", 'not before the wedge is in place'); end
                    nSqueak = nSqueak + (pPrev < marks.p && p >= marks.p);
                    pPrev = p;
                    s.t = e;
                    kidsScene(scr, s);
                end
                tc.verifyEqual(pPrev, 1, 'the sequence finishes');
                tc.verifyEqual(nSqueak, 1, 'one squeak');
            end
        end

        function practiceRevealShowsTheTruth(tc)
            for lv = [80 75 5]
                s = kidsBeat("reveal", 0.5, tc.ctx(3, 1, lv));
                tc.verifyEqual(s.reveal, "pinch"); tc.verifyEqual(s.cup, 0);
                tc.verifyEqual(s.text, kidsText("en").yesFeedback, 'the sentence stays for the experimenter');
            end
            s = kidsBeat("reveal", 0.5, tc.ctx(3, 1, 0));
            tc.verifyEqual(s.reveal, "sleep"); tc.verifyEqual(s.cup, 0);
            tc.verifyEqual(s.text, kidsText("en").noFeedback);
        end

        % --- reward (U7) -------------------------------------------------------------------
        function starFliesToTheNextSlot(tc)
            for n = 0:9
                c = tc.ctx(n, 1);
                for p = tc.P
                    s = kidsBeat("star", p, c);
                    tc.verifyEqual(s.flyStar, p, 'AbsTol', 1e-12);
                    tc.verifyEqual(s.stars, n, 'stars before the increment');
                    g = kidsPose(s, tc.Win);
                    tc.verifyEqual(g.fly.slot, n + 1);
                    tc.verifyFalse(g.slotFilled(n + 1), 'the slot fills when kidsMain counts the star');
                end
            end
        end

        function cupTipsThenTheMonsterCelebrates(tc)
            for n = 0:3
                c = tc.ctx(10, n);
                for p = tc.P
                    s = kidsBeat("cup", p, c);
                    tc.verifyEqual(s.pose, "celebrate");
                    tc.verifyEqual(s.stars, 10);
                    if p < 0.5
                        tc.verifyEqual(s.cupTip, 2 * p, 'AbsTol', 1e-12, 'tips over the first half');
                        tc.verifyEqual(s.cupsDone, n);
                        tc.verifyEqual(kidsPose(s, tc.Win).tip.slot, n + 1);
                    else
                        tc.verifyTrue(isnan(s.cupTip));
                        tc.verifyEqual(s.cupsDone, n + 1, 'the tipped cup is in the done row');
                        tc.verifyEqual(s.cup, 1, 'a new milkshake...');
                        tc.verifyEqual(s.flavour, n + 2, '...in the next flavour');
                    end
                end
                w = arrayfun(@(p) kidsBeat("cup", p, c).wiggle, tc.P);
                tc.verifyEqual(w(tc.P < 0.5), zeros(1, nnz(tc.P < 0.5)), 'still while tipping');
                tc.verifyGreaterThan(max(abs(w)), 10, 'then the celebrate wiggle');
            end
        end

        % --- rest (U8) ------------------------------------------------------------------------
        function napDrainsTheBarThenStretch(tc)
            for p = tc.P
                s = kidsBeat("nap", p, tc.ctx());
                tc.verifyEqual(s.pose, "sleep"); tc.verifyFalse(s.straw);
                tc.verifyEqual(s.restLeft, 1 - p, 'AbsTol', 1e-12);
                tc.verifyTrue(isnan(s.mouseX));
            end
            s = kidsBeat("stretch", 0.5, tc.ctx());
            tc.verifyEqual(s.pose, "celebrate"); tc.verifyFalse(s.straw);
            tc.verifyTrue(isnan(s.restLeft));
        end

        function experimenterLineStaysSmall(tc)
            % Every beat's sentence is the experimenter's line (text), never childText.
            for b = tc.Beats
                s = kidsBeat(b, 0.5, tc.ctx());
                tc.verifyFalse(isfield(s, 'childText') && ~isempty(s.childText), b);
            end
        end

        % --- drawing ----------------------------------------------------------------------------
        function everyBeatDrawsWithTheStandIns(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(here, 'ptbstubs')));
            scr = struct('win', 1, 'winRect', tc.Win, 'colours', struct('background', [0.55 0.82 0.95], ...
                'monster', [150 80 200] / 255, 'monsterDark', [110 55 160] / 255, 'belly', [200 160 235] / 255, ...
                'mouth', [0.25 0.05 0.2], 'shake', [1 0.6 0.75], 'straw', [1 0.95 0.5], 'bubble', [1 1 1], ...
                'mouse', [0.6 0.6 0.62], 'mouseEar', [1 0.7 0.75], 'star', [1 0.82 0.1], 'slot', [1 1 1], ...
                'text', [0.1 0.1 0.25]));
            for b = tc.Beats
                for p = [0 0.3 0.6 1]
                    s = kidsBeat(b, p, tc.ctx(9, 3, 0));
                    s.t = 2.5;
                    kidsScene(scr, s);
                end
            end
            tc.verifyTrue(true);
        end
    end
end

function c = sceneColours()
% The colours openScreen in kidsMain sets.
c = struct('background', [0.55 0.82 0.95], 'monster', [150 80 200] / 255, ...
    'monsterDark', [110 55 160] / 255, 'belly', [200 160 235] / 255, 'mouth', [0.25 0.05 0.2], ...
    'shake', [1 0.6 0.75], 'straw', [1 0.95 0.5], 'bubble', [1 1 1], 'mouse', [0.6 0.6 0.62], ...
    'mouseEar', [1 0.7 0.75], 'star', [1 0.82 0.1], 'slot', [1 1 1], 'text', [0.1 0.1 0.25]);
end
