classdef TestKidsTutorial < matlab.unittest.TestCase
    % RRST-Kids intro tutorial (cfg.tutorial), between the story and the practice:
    % free play (the child slurps as often as they like; every slurp sets the
    % reference), two demos (the mouse pinching, then asleep, shown during the
    % slurps, each followed by its reveal) and a bridge to the answer cards.
    % kidsTutorialPlan is pure; kidsFreePlay runs on a kidsSimFlow and a test clock
    % with fake io handles (one draw = one 60 Hz frame), as TestKidsSlurpPhase.
    % After the first real run (2026-10-30): the adult experimenter did not know
    % they were in practice; the tutorial makes the pinch felt and shown first.

    properties
        T = 0
        scenes = {}
        drawT = []
        markers = strings(0, 1)
        markerT = []
        sounds = strings(0, 1)
        prompts = strings(0, 1)
        keyPlan = cell(0, 2)
    end

    properties (Constant)
        FRAME = 1 / 60
        MAX_FRAMES = 60 * 90
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = [fullfile(root, 'task', 'RRST_kids', {'config', 'code'}), ...
                {fullfile(root, 'task', 'RRST_2-0', 'code')}];     % uniqueFileName (kidsSave)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(p));
        end
    end

    methods (Static)
        function p = peakFor(volumeL, dur)
            % Peak (slm) of a half-sine breath of volumeL litres lasting dur s.
            p = volumeL * 60 * pi / (2 * dur);
        end

        function m = markerOrder(plan)
            % Every marker of the plan in session order.
            m = strings(1, 0);
            for k = 1:numel(plan)
                m = [m plan(k).markersBefore plan(k).markersAfter]; %#ok<AGROW>
            end
        end
    end

    methods
        function cfg = config(~)
            cfg = kidsConfig();
            cfg.debug.simulateChild = [];
            cfg.debug.timeScale = 1;
        end

        function io = fakeIo(tc, sim)
            if nargin < 2, sim = false; end
            io.draw = @(s) tc.draw(s);
            io.keys = @() tc.key();
            io.now = @() tc.T;
            io.marker = @(label, t) tc.marker(label, t);
            io.sound = @(name) tc.sound(name);
            io.prompt = @(msg) tc.prompt(msg);
            io.sim = sim;
        end

        function [fl, src] = flow(tc, cfg)
            src = kidsSimFlow('Clock', @() tc.T, 'Noise', 0.3, 'Seed', 1);
            fl = kidsFlow(src, cfg.flow);
        end

        function t = draw(tc, s)
            tc.scenes{end+1} = s;
            tc.drawT(end+1) = tc.T;
            tc.T = tc.T + tc.FRAME;
            t = tc.T;
            if numel(tc.scenes) > tc.MAX_FRAMES
                error('test:runaway', 'Free play did not end.');
            end
        end

        function k = key(tc)
            % keyPlan rows {t, key}: key once the clock reaches t; a row {[t1 t2], key}
            % holds key on every call from t1 to t2 (a held Space).
            k = "";
            while ~isempty(tc.keyPlan)
                when = tc.keyPlan{1, 1};
                if numel(when) == 2 && tc.T > when(2)
                    tc.keyPlan(1, :) = [];
                    continue
                end
                if tc.T >= when(1)
                    k = tc.keyPlan{1, 2};
                    if isscalar(when), tc.keyPlan(1, :) = []; end
                end
                return
            end
        end

        function marker(tc, label, t)
            tc.markers(end+1, 1) = string(label);
            tc.markerT(end+1, 1) = t;
        end

        function sound(tc, name)
            tc.sounds(end+1, 1) = string(name);
        end

        function prompt(tc, msg)
            tc.prompts(end+1, 1) = string(msg);
        end

        function v = field(tc, name)
            v = nan(1, numel(tc.scenes));
            for k = 1:numel(tc.scenes)
                if isfield(tc.scenes{k}, name), v(k) = tc.scenes{k}.(name); end
            end
        end

        function p = poses(tc)
            p = repmat("idle", 1, numel(tc.scenes));
            for k = 1:numel(tc.scenes)
                if isfield(tc.scenes{k}, 'pose'), p(k) = tc.scenes{k}.pose; end
            end
        end
    end

    methods (Test)
        % --- configuration -------------------------------------------------------------
        function defaultsReplaceTheFreeSlurps(tc)
            cfg = kidsConfig();
            validateKidsConfig(cfg);
            tc.verifyTrue(cfg.tutorial.enabled);
            tc.verifyEqual(cfg.tutorial.pinchLevel, 80);
            tc.verifyEqual(cfg.tutorial.demoOrder, ["pinch" "sleep"]);
            tc.verifyEqual(cfg.practice.nFree, 0, 'free play replaces the free slurps');
            tc.verifyLessThanOrEqual(cfg.tutorial.pinchLevel, cfg.child.hardCap);
        end

        function pinchLevelAboveTheCapIsRejected(tc)
            cfg = kidsConfig();
            cfg.tutorial.pinchLevel = cfg.child.hardCap + 5;
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg.tutorial.pinchLevel = 0;              % a pinch demo with no pinch
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg.tutorial.pinchLevel = NaN;
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg.tutorial.pinchLevel = cfg.child.hardCap;   % at the cap is fine
            validateKidsConfig(cfg);
        end

        function badTutorialSettingsAreRejected(tc)
            cfg = kidsConfig(); cfg.tutorial.enabled = 1;
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg = kidsConfig(); cfg.tutorial.demoOrder = ["pinch" "dance"];
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg = kidsConfig(); cfg.tutorial.demoOrder = ["pinch" "pinch"];
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg = kidsConfig(); cfg.practice.nFree = 2;
            cfg.practice.levels = [0 0 cfg.practice.levels];
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig', ...
                'free play and the old free slurps are one or the other');
            tc.verifyError(@() validateKidsConfig(rmfield(kidsConfig(), 'tutorial')), 'rrst:badConfig');
        end

        function oldFreeSlurpsStillValidWithoutTheTutorial(tc)
            cfg = kidsConfig();
            cfg.tutorial.enabled = false;
            cfg.practice.nFree = 2;
            cfg.practice.levels = [0 0 cfg.practice.levels];
            validateKidsConfig(cfg);
            tc.verifyEmpty(kidsTutorialPlan(cfg));
        end

        % --- the plan --------------------------------------------------------------------
        function planIsFreePlayTwoDemosAndTheBridge(tc)
            cfg = kidsConfig();
            plan = kidsTutorialPlan(cfg);
            tc.assertNumElements(plan, 4);
            tc.verifyEqual([plan.kind], ["freeplay" "demo" "demo" "bridge"]);
            tc.verifyEqual([plan.name], ["freeplay" "pinch" "sleep" "bridge"]);
            tc.verifyEqual([plan(1:3).level], [0 80 0], 'free play at 0, the pinch at pinchLevel');
            tc.verifyEqual([plan.mousePose], ["" "pinch" "sleep" ""], 'the mouse during the slurps');
            tc.verifyEqual([plan.reveal], ["" "pinch" "sleep" ""], 'the reveal after the demo');
            tc.verifyEqual([plan.prompt], ["freeplay" "demo" "demo" "bridge"]);
            tc.verifyEqual(tc.markerOrder(plan), ["tutorial_start" "freeplay_start" ...
                "freeplay_end" "demo_pinch_level_80" "demo_sleep_level_0" "tutorial_end"]);
            for k = 1:numel(plan)
                if plan(k).kind ~= "bridge"
                    kidsCheckLevel(plan(k).level, cfg);
                end
            end
        end

        function planFollowsTheConfiguration(tc)
            cfg = kidsConfig();
            cfg.tutorial.pinchLevel = 70;
            cfg.tutorial.demoOrder = ["sleep" "pinch"];
            plan = kidsTutorialPlan(cfg);
            tc.verifyEqual([plan.name], ["freeplay" "sleep" "pinch" "bridge"]);
            tc.verifyEqual([plan(2:3).level], [0 70]);
            tc.verifyEqual(tc.markerOrder(plan), ["tutorial_start" "freeplay_start" ...
                "freeplay_end" "demo_sleep_level_0" "demo_pinch_level_70" "tutorial_end"]);
            cfg.tutorial.demoOrder = "pinch";
            plan = kidsTutorialPlan(cfg);
            tc.verifyEqual([plan.name], ["freeplay" "pinch" "bridge"]);
        end

        function demoRevealsMatchTheBeat(tc)
            % kidsBeat "reveal" picks pinch for a level above 0, sleep at 0: the demo's
            % level gives the reveal the plan names.
            cfg = kidsConfig();
            plan = kidsTutorialPlan(cfg);
            ctx = struct('stars', 0, 'cupsDone', 0, 'nCups', 4, 'txt', kidsText("en"), ...
                'timing', cfg.timing, 'level', NaN);
            for k = find([plan.kind] == "demo")
                ctx.level = plan(k).level;
                s = kidsBeat("reveal", 0.5, ctx);
                tc.verifyEqual(s.reveal, plan(k).reveal, plan(k).name);
            end
        end

        % --- free play -----------------------------------------------------------------
        function referenceIsSetFromEverySlurp(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            vols = [0.3 0.5 0.9 0.7];
            for k = 1:numel(vols)                      % one breath every 3 s from 0.5 s
                src.breathe(tc.peakFor(vols(k), 1.2), 1.2, 1, 0, 0.5 + 3 * (k - 1));
            end
            tc.keyPlan = {12.5, "skip"};
            [status, slurps, info] = kidsFreePlay(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.assertNumElements(slurps, 4);
            tc.verifyEqual(info.nSlurps, 4);
            tc.verifyEqual(fl.refVolume, median([slurps.volumeL]), 'AbsTol', 1e-12, ...
                'the reference is the median of every free slurp');
            tc.verifyEqual(fl.refVolume, 0.6, 'AbsTol', 0.03);
            tc.verifyTrue(any(contains(tc.prompts, "Reference slurp")), 'console line');
            tc.verifyEqual(tc.markers(1:2)', ["slurp_1_onset" ...
                string(sprintf('slurp_1_end_%.2f_%.0f', slurps(1).volumeL, slurps(1).peakSlm))]);
        end

        function smallSlurpsAreDrunkAndSetTheReference(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(tc.peakFor(0.12, 1), 1, 2, 3, 0.5);   % weak against the 0.6 L default
            tc.keyPlan = {7, "skip"};
            [status, slurps, info] = kidsFreePlay(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEqual([slurps.type], ["weak" "weak"]);
            tc.verifyEqual(info.nSlurps, 2, 'both drunk');
            tc.verifyFalse(any(tc.poses() == "tryagain"), 'never a try-again in free play');
            tc.verifyFalse(any(tc.sounds == "tryagain"));
            tc.verifyEqual(fl.refVolume, 0.15, 'AbsTol', 1e-12, 'clamped to the lowest reference');
        end

        function cupRefillsWhenEmpty(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            n = cfg.child.slurps;
            src.breathe(30, 1.2, n + 1, 3, 0.5);
            tc.keyPlan = {3 * (n + 1) + 0.5, "skip"};
            kidsFreePlay(fl, cfg, tc.fakeIo());
            cup = tc.field('cup');
            t = tc.drawT;
            empty = find(abs(cup) < 1e-9, 1);
            tc.assertNotEmpty(empty, 'the milkshake runs out after cfg.child.slurps slurps');
            tc.verifyLessThan(t(empty), 3 * n + 0.5, 'empty after the third slurp');
            refill = find(t > t(empty) & cup == 1, 1);
            tc.assertNotEmpty(refill, 'a new milkshake when the old one is empty');
            tc.verifyLessThan(t(refill) - t(empty), 0.2, 'refilled at once');
            tc.verifyEqual(cup(end), 1 - 1 / n, 'AbsTol', 1e-9, 'the fourth slurp drinks from the new one');
            tc.verifyTrue(all(cup >= 0 & cup <= 1));
        end

        function spaceEndsOnlyAfterASlurp(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.2, 1, 0, 2);
            tc.keyPlan = {0.5, "skip"; 1, "skip"; 5, "skip"};
            [status, slurps] = kidsFreePlay(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEqual(tc.drawT(end), 5, 'AbsTol', 2 * tc.FRAME, ...
                'Space before the first slurp does not end free play');
            tc.verifyNumElements(slurps, 1);
            tc.verifyTrue(any(contains(tc.prompts, "slurp")), 'the console says a slurp is needed');
        end

        function holdingSpaceForOneSecondEndsWithoutASlurp(tc)
            cfg = tc.config();
            [fl, ~] = tc.flow(cfg);
            tc.keyPlan = {[1 3], "skip"};
            [status, slurps, info] = kidsFreePlay(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEqual(tc.drawT(end), 2, 'AbsTol', 3 * tc.FRAME, 'Space held 1 s');
            tc.verifyEmpty(slurps);
            tc.verifyEqual(info.nSlurps, 0);
            tc.verifyEqual(fl.refVolume, cfg.flow.refVolumeDefault, 'no slurp: the default stays');
        end

        function shortSpacePressesDoNotAddUpToAHold(tc)
            cfg = tc.config();
            [fl, ~] = tc.flow(cfg);
            tc.keyPlan = {[1 1.6], "skip"; [1.7 2.3], "skip"; 4, "abort"};
            status = kidsFreePlay(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "abort", 'two 0.6 s presses are not a 1 s hold');
        end

        function simulatedChildEndsAfterTwoSlurps(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(25, 1.3, 5, 2.5, 0.5);
            tc.keyPlan = {1, "skip"};                   % ignored for a simulated child
            [status, slurps, info] = kidsFreePlay(fl, cfg, tc.fakeIo(true));
            tc.verifyEqual(status, "done");
            tc.verifyEqual(info.nSlurps, 2);
            tc.verifyNumElements(slurps, 2);
            tc.verifyLessThan(tc.drawT(end), 2.5 + 2.5 + cfg.timing.drain, ...
                'ends when the second slurp has drained');
        end

        function escAborts(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.2, 3, 3, 0.5);
            tc.keyPlan = {2, "abort"};
            [status, ~, info] = kidsFreePlay(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "abort");
            tc.verifyEqual(info.durationS, 2, 'AbsTol', 2 * tc.FRAME);
            tc.verifyFalse(fl.started, 'the detector is stopped');
        end

        function posesAndText(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.2, 1, 0, 1);
            tc.keyPlan = {5, "skip"};
            kidsFreePlay(fl, cfg, tc.fakeIo());
            pose = tc.poses();
            t = tc.drawT;
            tc.verifyTrue(all(pose(t < 0.9) == "ready"), 'waiting: the ready pose');
            tc.verifyTrue(any(pose(t > 1.2 & t < 2.1) == "slurp"));
            tc.verifyTrue(any(pose == "ahh"));
            tc.verifyEqual(pose(end), "ready", 'back to ready after the drain');
            for k = 1:numel(tc.scenes)
                s = tc.scenes{k};
                tc.verifyTrue(~isfield(s, 'childText') || isempty(s.childText));
                tc.verifyTrue(isempty(s.text), 'only the experimenter line (kidsMain adds it)');
            end
            ahh = t(pose == "ahh");
            tc.verifyEqual(ahh(end) - ahh(1), cfg.timing.drain, 'AbsTol', 3 * tc.FRAME, ...
                'the drain lasts cfg.timing.drain');
        end

        function withoutASensorSpaceEndsAtOnce(tc)
            cfg = tc.config();
            cfg.flow.enabled = false; cfg.flow.feedback = "none";
            tc.keyPlan = {0.5, "skip"};
            [status, slurps, info] = kidsFreePlay([], cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEmpty(slurps);
            tc.verifyEqual(info.nSlurps, 0);
            tc.verifyEqual(tc.drawT(end), 0.5, 'AbsTol', 2 * tc.FRAME);
            tc.reset();
            [status, ~, ~] = kidsFreePlay([], cfg, tc.fakeIo(true));
            tc.verifyEqual(status, "done", 'a simulated child without a sensor goes straight on');
        end

        % --- saving with the tutorial phase ----------------------------------------------
        function tutorialRowsAreSavedWithThePractice(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            cfg = kidsConfig(); cfg.output.dir = d; cfg.device.mock = false;
            cfg.debug.simulateChild = [];
            stim = struct('summary', @() struct('deviceId', "TEST"));
            sl = struct('onsetT', 1, 'endT', 2, 'durationS', 1, 'peakSlm', 30, ...
                'volumeL', 0.6, 'counted', true, 'type', "end");
            tr = struct('n', {1, 2, 3}, 'phase', {"tutorial", "tutorial", "practice"}, ...
                'level', {0, 80, 80}, 'isCatch', {true, false, false}, 'proposed', NaN, ...
                'limited', false, 'answer', {"", "", "yes"}, 'response', {NaN, NaN, 1}, ...
                'rt', NaN, 'moveT', 1, 'slurpT', 5, 'tStart', {1, 20, 40}, ...
                'slurps', {[sl; sl; sl; sl], sl, sl}, 'shortSlurps', false, 'flowLost', false);
            result = struct('outcome', "practiceFailed", 'trials', tr([]), 'practice', tr, ...
                'flags', [], 'kp', []);
            f = kidsSave(cfg, struct('subNo', 7), stim, result);
            [folder, name] = fileparts(f);
            t = readtable(fullfile(folder, name + ".csv"), 'TextType', 'string');
            tc.verifyEqual(t.phase, ["tutorial"; "tutorial"; "practice"]);
            tc.verifyEqual(t.nSlurps, [4; 1; 1]);
            m = load(f);
            tc.verifyEqual(numel(m.result.practice(1).slurps), 4, 'every free-play slurp kept');
        end
    end

    methods
        function reset(tc)
            tc.scenes = {}; tc.drawT = []; tc.markers = strings(0, 1); tc.markerT = [];
            tc.sounds = strings(0, 1); tc.prompts = strings(0, 1); tc.keyPlan = cell(0, 2);
        end
    end
end
