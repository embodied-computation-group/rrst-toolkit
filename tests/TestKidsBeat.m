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
            for b = ["move" "ready"]
                for p = tc.P
                    tc.verifyEqual(kidsBeat(b, p, tc.ctx(3, 1, 0)), kidsBeat(b, p, tc.ctx(3, 1, 80)), b);
                end
            end
            s = kidsBeat("move", 0.5, tc.ctx());
            tc.verifyEqual(s.mouseX, 0.5, 'AbsTol', 1e-12);
            tc.verifyEqual(s.mousePose, "run"); tc.verifyFalse(s.straw);
            s = kidsBeat("ready", 1, tc.ctx());
            tc.verifyEqual(s.pose, "ready"); tc.verifyTrue(s.straw);
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
