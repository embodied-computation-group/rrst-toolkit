classdef TestKidsSlurpPhase < matlab.unittest.TestCase
    % RRST-Kids slurp phase (kidsSlurpPhase): breath-driven with a kidsSimFlow on a
    % test clock, the timed fallback, keys, the timeout prompt and a lost stream.
    % The session's io handles are fakes that record every call; each draw is one
    % 60 Hz frame on the test clock. No screen, no sound card, no LSL.
    % Plan: docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, section 3.3.

    properties
        T = 0                % test clock, s
        scenes = {}          % every scene passed to io.draw
        drawT = []           % clock at each draw
        markers = strings(0, 1)
        markerT = []
        sounds = strings(0, 1)
        prompts = strings(0, 1)
        keyPlan = cell(0, 2) % {time, key}: io.keys returns key once the clock reaches time
        actions = cell(0, 2) % {time, fn}: fn() runs once the clock reaches time
    end

    properties (Constant)
        FRAME = 1 / 60
        ANIM_TOL = 2 / 60    % a timed animation lasts its duration plus up to 2 frames
        MAX_FRAMES = 60 * 90 % a phase that runs longer than 90 s is a bug
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
        function p = peakFor(volumeL)
            % Peak (slm) of a 1 s half-sine breath of volumeL litres; the detector
            % measures about 3 mL less (onset threshold and filter).
            p = (volumeL + 0.003) * 60 * pi / 2;
        end
    end

    methods
        function cfg = config(~)
            cfg = kidsConfig();
            cfg.debug.simulateChild = [];
            cfg.debug.timeScale = 1;
        end

        function io = fakeIo(tc, sim, free)
            if nargin < 2, sim = false; end
            if nargin < 3, free = false; end
            io.draw = @(s) tc.draw(s);
            io.keys = @() tc.key();
            io.now = @() tc.T;
            io.marker = @(label, t) tc.marker(label, t);
            io.sound = @(name) tc.sound(name);
            io.prompt = @(msg) tc.prompt(msg);
            io.sim = sim;
            io.free = free;
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
            while ~isempty(tc.actions) && tc.T >= tc.actions{1, 1}
                fn = tc.actions{1, 2};
                tc.actions(1, :) = [];
                fn();
            end
            if numel(tc.scenes) > tc.MAX_FRAMES
                error('test:runaway', 'The slurp phase did not end.');
            end
        end

        function k = key(tc)
            k = "";
            if ~isempty(tc.keyPlan) && tc.T >= tc.keyPlan{1, 1}
                k = tc.keyPlan{1, 2};
                tc.keyPlan(1, :) = [];
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
            % One value per drawn scene (NaN where the scene has no such field).
            v = nan(1, numel(tc.scenes));
            for k = 1:numel(tc.scenes)
                if isfield(tc.scenes{k}, name)
                    v(k) = tc.scenes{k}.(name);
                end
            end
        end

        function p = poses(tc)
            % The pose of every drawn scene ("idle" where the scene has none).
            p = repmat("idle", 1, numel(tc.scenes));
            for k = 1:numel(tc.scenes)
                if isfield(tc.scenes{k}, 'pose'), p(k) = tc.scenes{k}.pose; end
            end
        end

        function reset(tc)
            % A fresh recording for a second phase in the same test (the clock runs on).
            tc.scenes = {}; tc.drawT = []; tc.markers = strings(0, 1); tc.markerT = [];
            tc.sounds = strings(0, 1); tc.prompts = strings(0, 1);
        end

        function verifyCupPasses(tc, values)
            cup = tc.field('cup');
            for v = values
                tc.verifyTrue(any(abs(cup - v) < 1e-9), sprintf('cup %.3f never drawn', v));
            end
        end
    end

    methods (Test)
        % --- breath-driven ---------------------------------------------------------
        function threeGoodBreathsFinishThePhase(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEqual(sum([slurps.counted]), 3);
            tc.verifyNumElements(slurps, 3);
            tc.verifyFalse(info.shortSlurps);
            tc.verifyFalse(info.flowLost);
            tc.verifyEqual(info.durationS, tc.T, 'AbsTol', 2 * tc.FRAME);
            tc.assertNumElements(tc.markers, 6);
            for k = 1:3
                tc.verifyEqual(tc.markers(2 * k - 1), "slurp_" + k + "_onset");
                tc.verifyEqual(tc.markers(2 * k), string(sprintf('slurp_%d_end_%.2f_%.0f', ...
                    k, slurps(k).volumeL, slurps(k).peakSlm)));
                tc.verifyEqual(tc.markerT(2 * k - 1), slurps(k).onsetT, 'AbsTol', 1e-9, ...
                    'onset marker carries the sample time of the onset');
                tc.verifyEqual(tc.markerT(2 * k), slurps(k).endT, 'AbsTol', 1e-9);
                tc.verifyEqual(slurps(k).onsetT, 0.5 + 2.5 * (k - 1), 'AbsTol', 0.15);
            end
            tc.verifyEqual(tc.sounds', repmat(["slurp" "bubbles"], 1, 3));
            tc.verifyCupPasses([1 2/3 1/3 0]);
            cup = tc.field('cup');
            tc.verifyLessThanOrEqual(diff(cup), 1e-12, 'the milkshake never refills');
            tc.verifyEqual(cup(end), 0, 'AbsTol', 1e-12, 'the phase ends on an empty cup');
            tc.verifyEmpty(tc.prompts(contains(tc.prompts, "No slurp seen")));
        end

        function bellyFollowsTheBreathAndBubblesFollowTheEnd(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            kidsSlurpPhase(fl, cfg, tc.fakeIo());
            belly = tc.field('belly');
            t = tc.drawT;
            tc.verifyEqual(max(belly(t < 0.45)), 0, 'no belly before the first breath');
            during = t > 0.7 & t < 1.9;
            tc.verifyGreaterThan(max(belly(during)), 0.9, 'a full breath fills the belly');
            first = find(during & belly > 0, 1);
            tc.verifyLessThan(belly(first), 0.5, 'the belly grows, it does not jump');
            bubbles = tc.field('bubbles');
            tc.verifyTrue(all(isnan(bubbles(t < 2))), 'no bubbles before the first end');
            tc.verifyTrue(any(bubbles(t > 2.2 & t < 3.8) > 0), 'bubbles after the end');
            tc.verifyTrue(all(bubbles(~isnan(bubbles)) >= 0 & bubbles(~isnan(bubbles)) <= 1));
        end

        function weakBreathIsNotCountedAndThePhaseWaits(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(6, 0.8, 1, 0, 0.5);           % 0.05 L: weak
            tc.keyPlan = {6, "abort"};
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "abort");
            tc.verifyEqual(tc.drawT(end), 6, 'AbsTol', 2 * tc.FRAME, 'still waiting at 6 s');
            tc.assertNumElements(slurps, 1);
            tc.verifyFalse(slurps.counted);
            tc.verifyEqual(tc.markers, ["slurp_1_onset"; "slurp_1_weak"]);
            tc.verifyEqual(tc.sounds, ["slurp"; "tryagain"]);
            tc.verifyTrue(info.shortSlurps);
            tc.verifyEqual(tc.field('cup'), ones(1, numel(tc.scenes)), 'no drain');
            tc.verifyTrue(any(contains(tc.prompts, "weak")), 'console says why');
            belly = tc.field('belly');
            tc.verifyEqual(belly(end), 0, 'the belly has deflated');
            tc.verifyTrue(all(isnan(tc.field('bubbles'))), 'no bubbles for a weak slurp');
        end

        function overlongBreathIsNotCounted(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(20, 7, 1, 0, 0.5);
            tc.keyPlan = {10, "abort"};
            [~, slurps] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.assertNumElements(slurps, 1);
            tc.verifyFalse(slurps.counted);
            tc.verifyEqual(tc.markers, ["slurp_1_onset"; "slurp_1_overlong"]);
            tc.verifyEqual(tc.sounds, ["slurp"; "tryagain"]);
            tc.verifyTrue(any(contains(tc.prompts, "leak")), 'console names the likely cause');
        end

        function spaceAfterOneBreathEndsThePhaseShort(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 1, 0, 0.5);
            tc.keyPlan = {4, "skip"};
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "skip");
            tc.verifyTrue(info.shortSlurps);
            tc.verifyEqual(sum([slurps.counted]), 1);
            tc.verifyEqual(tc.drawT(end), 4, 'AbsTol', 2 * tc.FRAME);
        end

        function spaceNeverEndsASimulatedChildsPhase(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            tc.keyPlan = {1, "skip"; 4, "skip"};
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo(true));
            tc.verifyEqual(status, "done");
            tc.verifyFalse(info.shortSlurps);
            tc.verifyEqual(sum([slurps.counted]), 3);
        end

        function escAborts(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            tc.keyPlan = {1, "abort"};
            [status, ~, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo(true));
            tc.verifyEqual(status, "abort");
            tc.verifyEqual(info.durationS, 1, 'AbsTol', 2 * tc.FRAME);
            tc.verifyFalse(fl.started, 'the detector is stopped');
        end

        function xMarksABadBreath(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            tc.keyPlan = {3, "bad"};
            [status, slurps] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "bad");
            tc.verifyEqual(sum([slurps.counted]), 1);
        end

        function noBreathPromptsTheExperimenterOnceAndKeepsWaiting(tc)
            cfg = tc.config();
            fl = tc.flow(cfg);
            tc.keyPlan = {20, "abort"};
            [status, slurps] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "abort");
            tc.verifyEqual(tc.drawT(end), 20, 'AbsTol', 2 * tc.FRAME);
            p = tc.prompts(contains(tc.prompts, "No slurp seen"));
            tc.verifyNumElements(p, 1);
            tc.verifyEqual(p, string(sprintf(['No slurp seen for %g s: mouthpiece in? ' ...
                'Space = go on, x = repeat, Esc = abort'], cfg.flow.slurpTimeout)));
            tc.verifyEmpty(slurps);
            tc.verifyEmpty(tc.markers);
        end

        function timeoutPromptComesBackAfterTheNextSlurp(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            tc.actions = {9, @() src.breathe(30, 1.5)};
            tc.keyPlan = {28, "abort"};
            kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyNumElements(tc.prompts(contains(tc.prompts, "No slurp seen")), 2);
        end

        function lostStreamFinishesWithTheTimedAnimation(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            tc.actions = {2.8, @() setLost(src)};         % after the first counted slurp
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyTrue(info.flowLost);
            tc.verifyFalse(info.shortSlurps);
            tc.verifyEqual(sum([slurps.counted]), 1);
            tc.verifyNumElements(tc.prompts(contains(tc.prompts, "lost")), 1);
            tc.verifyEqual(tc.markers, ["slurp_1_onset"; tc.markers(2)]);
            tc.verifyTrue(startsWith(tc.markers(2), "slurp_1_end_"));
            tc.verifyEqual(info.durationS, 2.8 + 2 * (cfg.timing.inhale + cfg.timing.exhale), ...
                'AbsTol', 4 * tc.ANIM_TOL + tc.FRAME, 'two timed slurps after the loss');
            tc.verifyCupPasses([1 2/3 1/3 0]);
            tc.verifyEqual(tc.scenes{end}.cup, 0, 'AbsTol', 1e-12);
        end

        function feedbackNoneRunsTimedButRecordsTheBreaths(tc)
            cfg = tc.config();
            cfg.flow.feedback = "none";
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEqual(sum([slurps.counted]), 3, 'the detector runs in the background');
            tc.verifyEmpty(tc.markers);
            tc.verifyEmpty(tc.sounds);
            tc.verifyFalse(info.flowLost);
            tc.verifyEqual(info.durationS, 3 * (cfg.timing.inhale + cfg.timing.exhale), 'AbsTol', 6 * tc.ANIM_TOL);
        end

        % --- poses (UX pass) ----------------------------------------------------------
        function posesFollowTheSlurp(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            kidsSlurpPhase(fl, cfg, tc.fakeIo());
            pose = tc.poses(); t = tc.drawT;
            tc.verifyTrue(all(pose(t < 0.45) == "idle"), 'waiting: idle');
            tc.verifyTrue(all(pose(t > 0.8 & t < 1.8) == "slurp"), 'slurping while the child inhales');
            tc.verifyTrue(all(pose(t > 2.3 & t < 2.9) == "ahh"), 'ahh during the bubbles, before the next slurp');
            tc.verifyTrue(any(pose == "ahh"));
            tc.verifyFalse(any(pose == "tryagain"), 'three good slurps: never try again');
        end

        function weakSlurpShowsTryAgainNotSad(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(6, 0.8, 1, 0, 0.5);           % 0.05 L: weak
            tc.keyPlan = {6, "abort"};
            kidsSlurpPhase(fl, cfg, tc.fakeIo());
            pose = tc.poses(); t = tc.drawT;
            k = find(pose == "tryagain", 1);
            tc.assertNotEmpty(k, 'the try-again pose after a weak slurp');
            tc.verifyGreaterThan(t(k), 1.3, 'after the slurp has ended');
            tc.verifyLessThan(t(find(pose == "tryagain", 1, 'last')), t(k) + cfg.timing.exhale + 0.1, ...
                'only while the belly deflates');
            tc.verifyEqual(pose(end), "idle", 'then waiting again');
        end

        % --- free slurps: the tutorial and the reference ---------------------------------
        function freeSlurpsNeverShowTryAgain(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(TestKidsSlurpPhase.peakFor(0.12), 1, 3, 2.5, 0.5);  % below the default 0.15 L
            [status, slurps, info] = kidsSlurpPhase(fl, cfg, tc.fakeIo(false, true));
            tc.verifyEqual(status, "done", 'every free slurp is drunk on screen');
            tc.assertNumElements(slurps, 3);
            tc.verifyEqual([slurps.type], repmat("weak", 1, 3), 'the records keep the type');
            tc.verifyFalse(any([slurps.counted]));
            tc.verifyEqual(info.counted, 3);
            tc.verifyFalse(any(tc.sounds == "tryagain"), 'no try-again sound');
            tc.verifyFalse(any(tc.poses() == "tryagain"), 'no try-again pose');
            tc.verifyEqual(tc.sounds', repmat(["slurp" "bubbles"], 1, 3));
            tc.verifyCupPasses([1 2/3 1/3 0]);
            tc.verifyEqual(tc.markers(2:2:end)', "slurp_" + (1:3) + "_weak", 'markers keep the type');
            tc.verifyEmpty(tc.prompts(contains(tc.prompts, "try again")), 'no try-again line either');
            % an overlong free slurp: not drunk, still no try-again
            tc.reset();
            [fl, src] = tc.flow(cfg);
            src.breathe(20, 7, 1, 0, 0.5);
            tc.keyPlan = {tc.T + 12, "skip"};
            kidsSlurpPhase(fl, cfg, tc.fakeIo(false, true));
            tc.verifyFalse(any(tc.sounds == "tryagain"));
            tc.verifyFalse(any(tc.poses() == "tryagain"));
            tc.verifyTrue(any(contains(tc.prompts, "leak")), 'the leak warning stays');
        end

        function smallFreeSlurpsSetTheReferenceAndASmallSlurpThenCounts(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(TestKidsSlurpPhase.peakFor(0.12), 1, 2, 2.5, 0.5);
            tc.keyPlan = {8, "skip"};
            [~, free] = kidsSlurpPhase(fl, cfg, tc.fakeIo(false, true));
            tc.assertNumElements(free, 2);
            tc.verifyEqual([free.volumeL], [0.12 0.12], 'AbsTol', 0.01);
            tc.verifyEqual([free.type], ["weak" "weak"], 'weak against the 0.6 L default');
            ref = kidsReferenceSlurps(free);
            tc.verifyNumElements(ref, 2, 'weak free slurps set the reference');
            minL = fl.setReference([ref.volumeL]);
            tc.verifyEqual(fl.refVolume, 0.15, 'AbsTol', 1e-12, 'clamped to the 0.15 L floor');
            tc.verifyEqual(minL, cfg.flow.minVolumeL, 'the 0.10 L floor applies to counting');
            % a later 0.11 L slurp counts
            tc.reset();
            src.quiet();
            src.breathe(TestKidsSlurpPhase.peakFor(0.11), 1, 1, 0, 0.5);
            tc.keyPlan = {tc.T + 5, "skip"};
            [~, later] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            tc.assertNumElements(later, 1);
            tc.verifyEqual(later.volumeL, 0.11, 'AbsTol', 0.006);
            tc.verifyGreaterThan(later.volumeL, cfg.flow.minVolumeL);
            tc.verifyTrue(later.counted, 'a 0.11 L slurp counts once the reference is set');
            tc.verifyEqual(later.type, "end");
        end

        function referenceUsesEndAndWeakSlurpsOnly(tc)
            sl = @(v, type) struct('onsetT', 1, 'endT', 2, 'durationS', 1, 'peakSlm', 20, ...
                'volumeL', v, 'counted', type == "end", 'type', type);
            s = [sl(0.3, "end"); sl(0.12, "weak"); sl(2.5, "overlong"); sl(0.05, "interrupted")];
            r = kidsReferenceSlurps(s);
            tc.verifyEqual([r.volumeL], [0.3 0.12]);
            tc.verifyEqual(r, s(1:2));
            tc.verifyEmpty(kidsReferenceSlurps(s(3:4)));
            tc.verifyEmpty(kidsReferenceSlurps(s([])));
            tc.verifyEmpty(kidsReferenceSlurps([]));
        end

        % --- timed fallback (no flow) ---------------------------------------------------
        function timedFallbackIsTodaysAnimation(tc)
            cfg = tc.config();
            [status, slurps, info] = kidsSlurpPhase([], cfg, tc.fakeIo());
            tc.verifyEqual(status, "done");
            tc.verifyEmpty(slurps);
            tc.verifyFalse(info.shortSlurps);
            tc.verifyFalse(info.flowLost);
            tc.verifyEmpty(tc.markers);
            tc.verifyEmpty(tc.sounds);
            tc.verifyEmpty(tc.prompts);
            n = cfg.child.slurps;
            cycle = cfg.timing.inhale + cfg.timing.exhale;
            tc.verifyEqual(info.durationS, n * cycle, 'AbsTol', 2 * n * tc.ANIM_TOL);
            txt = kidsText(cfg.text.language);
            % Replay the old frame loop on the recorded clock: same scenes, same order.
            k = 1;
            for s = 1:n
                left = 1 - (s - 1) / n;
                for ph = 1:2
                    if ph == 1, dur = cfg.timing.inhale; else, dur = cfg.timing.exhale; end
                    t0 = tc.drawT(k);
                    while true
                        p = min((tc.drawT(k) - t0) / dur, 1);
                        if ph == 1
                            want = struct('belly', p, 'cup', left - p / n, 'text', txt.inhale);
                        else
                            want = struct('belly', 1 - p, 'cup', left - 1 / n, 'bubbles', p, 'text', txt.exhale);
                        end
                        got = tc.scenes{k};
                        if ph == 1, pose = "slurp"; else, pose = "ahh"; end
                        tc.assertEqual(got.pose, pose, sprintf('frame %d: pose', k));
                        tc.assertEqual(rmfield(got, 'pose'), want, sprintf('frame %d', k));
                        k = k + 1;
                        if p >= 1, break; end
                    end
                end
            end
            tc.verifyEqual(k - 1, numel(tc.scenes), 'no extra frames');
        end

        function timedFallbackSpaceEndsEarly(tc)
            cfg = tc.config();
            tc.keyPlan = {4, "skip"};
            [status, ~, info] = kidsSlurpPhase([], cfg, tc.fakeIo());
            tc.verifyEqual(status, "skip");
            tc.verifyTrue(info.shortSlurps);
            tc.verifyEqual(info.durationS, 4, 'AbsTol', 2 * tc.FRAME);
        end

        function timedFallbackIgnoresSpaceForASimulatedChild(tc)
            cfg = tc.config();
            tc.keyPlan = {4, "skip"};
            status = kidsSlurpPhase([], cfg, tc.fakeIo(true));
            tc.verifyEqual(status, "done");
        end

        function timedFallbackFollowsTheTimeScale(tc)
            cfg = tc.config();
            cfg.debug.timeScale = 0.2;
            [~, ~, info] = kidsSlurpPhase([], cfg, tc.fakeIo(true));
            tc.verifyEqual(info.durationS, 0.2 * 3 * (cfg.timing.inhale + cfg.timing.exhale), 'AbsTol', 6 * tc.ANIM_TOL);
        end

        function slurpRecordsHaveTheSameFieldsWithAndWithoutFlow(tc)
            cfg = tc.config();
            [fl, src] = tc.flow(cfg);
            src.breathe(30, 1.5, 3, 2.5, 0.5);
            [~, withFlow] = kidsSlurpPhase(fl, cfg, tc.fakeIo());
            [~, timed] = kidsSlurpPhase([], cfg, tc.fakeIo(true));
            tc.verifyEqual(sort(fieldnames(timed)), sort(fieldnames(withFlow)));
            tc.verifySize(timed, [0 1]);
        end

        % --- configuration ------------------------------------------------------------
        function defaultFlowAndSoundAreValid(tc)
            cfg = kidsConfig();
            validateKidsConfig(cfg);
            cfg.flow.enabled = false;
            cfg.flow.feedback = "none";
            validateKidsConfig(cfg);                    % the tested fallback
            cfg.flow.enabled = true;
            validateKidsConfig(cfg);                    % detector on, no feedback
            tc.verifyTrue(true);
        end

        function breathFeedbackNeedsTheSensor(tc)
            cfg = kidsConfig();
            cfg.flow.enabled = false;                   % feedback stays "breath"
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
        end

        function badFlowSettingsAreRejected(tc)
            bad = {'enabled', "yes"; 'enabled', 1; 'enabled', [true true]; ...
                'feedback', "proportional"; 'feedback', 3; 'feedback', ["breath" "none"]; ...
                'timeout', 0; 'timeout', -1; 'timeout', NaN; 'timeout', [1 2]};
            for k = 1:size(bad, 1)
                cfg = kidsConfig();
                cfg.flow.(bad{k, 1}) = bad{k, 2};
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig', ...
                    sprintf('flow.%s = %s', bad{k, 1}, mat2str(bad{k, 2})));
            end
            tc.verifyError(@() validateKidsConfig(rmfield(kidsConfig(), 'flow')), 'rrst:badConfig');
        end

        function badSoundSettingsAreRejected(tc)
            bad = {'enabled', "yes"; 'enabled', [true false]; 'volume', 0; 'volume', 1.5; ...
                'volume', -0.2; 'fs', 0; 'fs', -48000; 'fs', NaN};
            for k = 1:size(bad, 1)
                cfg = kidsConfig();
                cfg.sound.(bad{k, 1}) = bad{k, 2};
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig', ...
                    sprintf('sound.%s = %s', bad{k, 1}, mat2str(bad{k, 2})));
            end
            cfg = kidsConfig();
            cfg.sound.volume = 1;                       % (0, 1]
            validateKidsConfig(cfg);
            tc.verifyError(@() validateKidsConfig(rmfield(kidsConfig(), 'sound')), 'rrst:badConfig');
        end

        % --- saving ---------------------------------------------------------------------
        function csvHasFlatSlurpColumnsAndMatHasTheRecords(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            cfg = kidsConfig(); cfg.output.dir = d; cfg.device.mock = false;
            cfg.debug.simulateChild = [];
            stim = struct('summary', @() struct('deviceId', "TEST"));   % stands in for rrst.Stimulator
            sl = @(v, pk, ok) struct('onsetT', 1, 'endT', 2, 'durationS', 1, 'peakSlm', pk, ...
                'volumeL', v, 'counted', ok, 'type', "end");
            three = [sl(0.3, 20, true); sl(0.05, 6, false); sl(0.5, 30, true)];
            none = three([]);
            tr = struct('n', {1, 2}, 'phase', "main", 'level', {70, 0}, 'isCatch', {false, true}, ...
                'proposed', NaN, 'limited', false, 'answer', "yes", 'response', 1, 'rt', 1, ...
                'moveT', 1, 'slurpT', 5, 'tStart', {10, 20}, 'slurps', {three, none}, ...
                'shortSlurps', {false, true}, 'flowLost', {false, true});
            result = struct('outcome', "aborted", 'trials', tr, 'practice', tr([]), ...
                'flags', [], 'kp', []);
            f = kidsSave(cfg, struct('subNo', 7), stim, result);
            [folder, name] = fileparts(f);
            t = readtable(fullfile(folder, name + ".csv"), 'TextType', 'string');
            tc.assertEqual(height(t), 2);
            tc.verifyFalse(ismember('slurps', t.Properties.VariableNames));
            tc.verifyEqual(t.nSlurps, [2; 0], 'counted slurps');
            tc.verifyEqual(t.slurpVolumeL, [0.4; NaN], 'AbsTol', 1e-12, 'mean of counted');
            tc.verifyEqual(t.slurpPeakSlm, [25; NaN], 'AbsTol', 1e-12);
            tc.verifyEqual(logical(t.shortSlurps), [false; true]);
            tc.verifyEqual(logical(t.flowLost), [false; true]);
            m = load(f);
            tc.verifyEqual(m.result.trials(1).slurps, three, 'full records in the .mat');
        end
    end
end

function setLost(src)
src.lost = true;
end
