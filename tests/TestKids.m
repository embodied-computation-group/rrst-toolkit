classdef TestKids < matlab.unittest.TestCase
    % RRST-Kids ("Milkshake Monster"): configuration, safety cap, trial schedule and
    % the yes/no Psi procedure, driven by a simulated child. No hardware, no screen.

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', {'config', 'code'});
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
            tc.assumeNotEmpty(which('PAL_AMPM_setupPM'), 'Palamedes is not on the path.');
        end
    end

    methods (Test)
        % --- configuration and safety cap -----------------------------------
        function kidsConfigIsValid(tc)
            cfg = kidsConfig();
            validateKidsConfig(cfg);
            tc.verifyEqual(cfg.label, "KIDS PILOT");
            tc.verifyLessThanOrEqual(cfg.child.hardCap, 85);
        end

        function capAboveAbsoluteMaximumIsRejected(tc)
            cfg = kidsConfig();
            cfg.child.hardCap = 90;
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
        end

        function levelsAboveTheCapAreRejected(tc)
            cfg = kidsConfig();
            cfg.child.hardCap = 80;                  % grid still reaches 85
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg = kidsConfig();
            cfg.practice.levels(end) = 90;
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            cfg = kidsConfig();
            cfg.stim.restRange = [10 90];
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
        end

        function catchLevelMustBeOnTheGrid(tc)
            cfg = kidsConfig();
            cfg.psi.stimRange = 5:5:85;              % no 0 for catch trials
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
        end

        function checkLevelStopsAnythingAboveTheCap(tc)
            cfg = kidsConfig();
            kidsCheckLevel(cfg.child.hardCap, cfg);  % at the cap is fine
            tc.verifyError(@() kidsCheckLevel(cfg.child.hardCap + 0.1, cfg), 'rrst:kidsCap');
            tc.verifyError(@() kidsCheckLevel(-1, cfg), 'rrst:kidsCap');
        end

        % --- schedule --------------------------------------------------------
        function scheduleHasTheRightCatchTrials(tc)
            s = kidsSchedule(30, 10, 3);
            tc.verifySize(s, [1 40]);
            tc.verifyEqual(nnz(s), 10);
            tc.verifyFalse(s(1));                     % never first
            tc.verifyFalse(any(s(1:end-1) & s(2:end)));   % never two in a row
            tc.verifyEqual(s, kidsSchedule(30, 10, 3));   % reproducible
        end

        function impossibleScheduleIsAnError(tc)
            tc.verifyError(@() kidsSchedule(5, 6, 1), 'rrst:badConfig');
        end

        % --- procedure -------------------------------------------------------
        function firstTrialIsTheStartLevel(tc)
            cfg = kidsConfig();
            kp = kidsProcedure(cfg, 1);
            [level, info] = kidsNextLevel(kp, cfg);
            tc.verifyEqual(level, cfg.child.startLevel);
            tc.verifyFalse(info.isCatch);
        end

        function catchTrialsAreLevelZero(tc)
            cfg = kidsConfig();
            kp = kidsProcedure(cfg, 1);
            kp.schedule(1:2) = [false true];
            kp = kidsRecord(kp, kidsNextLevel(kp, cfg), 1, getInfo(kp, cfg));
            [level, info] = kidsNextLevel(kp, cfg);
            tc.verifyEqual(level, 0);
            tc.verifyTrue(info.isCatch);
        end

        function rampLimitsJumpsAboveTheRunningMaximum(tc)
            cfg = kidsConfig();
            kp = kidsProcedure(cfg, 1);
            kp.nPsiDone = 3; kp.runningMax = 50; kp.schedule(:) = false;
            kp.PM.xCurrent = 85;                     % Psi asks for far more
            level = kidsNextLevel(kp, cfg);
            tc.verifyLessThanOrEqual(level, 50 + cfg.child.rampMax);
            tc.verifyTrue(ismember(level, cfg.psi.stimRange));
        end

        function failedTrialIsRepeatedLaterWithItsType(tc)
            cfg = kidsConfig();
            kp = kidsProcedure(cfg, 1);
            n = numel(kp.schedule);
            first = kp.schedule(kp.k);
            kp = kidsRequeue(kp);
            tc.verifyEqual(numel(kp.schedule), n + 1);
            tc.verifyEqual(kp.schedule(end), first);
            tc.verifyEqual(kp.k, 2);
            tc.verifyEqual(kp.nRepeats, 1);
        end

        function simulatedChildRunStaysUnderTheCapAndFindsTheThreshold(tc)
            cfg = kidsConfig();
            [kp, levels] = simulateChild(cfg, [72 8 0.1 0.1], 11);
            tc.verifyLessThanOrEqual(max(levels), cfg.child.hardCap);
            tc.verifyTrue(kidsShouldStop(kp, cfg));
            tc.verifyLessThan(abs(kp.PM.threshold(end) - 72), 15);
            tc.verifyLessThanOrEqual(numel(levels), cfg.child.numPsiTrials + cfg.child.numCatchTrials);
        end

        function preciseRunCanStopEarly(tc)
            cfg = kidsConfig();
            cfg.child.stopSE = 100;                  % any SE is good enough
            [kp, levels] = simulateChild(cfg, [72 8 0.1 0.1], 2);
            [stop, why] = kidsShouldStop(kp, cfg);
            tc.verifyTrue(stop);
            tc.verifyEqual(why, "precise");
            tc.verifyEqual(kp.nPsiDone, cfg.child.stopMinTrials);
            tc.verifyLessThan(numel(levels), cfg.child.numPsiTrials + cfg.child.numCatchTrials);
        end

        % --- bias flags ------------------------------------------------------
        function yesSayerIsFlagged(tc)
            cfg = kidsConfig();
            kp = kidsProcedure(cfg, 1);
            kp.history = struct('level', num2cell([0 0 0 0 80 80]), ...
                'response', num2cell([1 1 1 0 1 1]), 'isCatch', num2cell([true true true true false false]));
            f = kidsFlags(kp, cfg);
            tc.verifyEqual(f.faRate, 0.75);
            tc.verifyTrue(f.unusable);
        end

        function goodChildIsNotFlagged(tc)
            cfg = kidsConfig();
            kp = kidsProcedure(cfg, 1);
            kp.history = struct('level', num2cell([0 0 0 0 80 85 80]), ...
                'response', num2cell([0 0 1 0 1 1 1]), 'isCatch', num2cell([true true true true false false false]));
            f = kidsFlags(kp, cfg);
            tc.verifyEqual(f.faRate, 0.25);
            tc.verifyEqual(f.hitRateHigh, 1);
            tc.verifyFalse(f.unusable);
        end

        % --- answer screen ----------------------------------------------------
        function clickSideGivesTheAnswer(tc)
            W = 1000;                                   % "easy" is drawn left, "squishy" right
            tc.verifyEqual(kidsClickAnswer(100, W), "no");
            tc.verifyEqual(kidsClickAnswer(440, W), "no");
            tc.verifyEqual(kidsClickAnswer(900, W), "yes");
            tc.verifyEqual(kidsClickAnswer(560, W), "yes");
        end

        function clickInTheMiddleIsIgnored(tc)
            W = 1000;
            tc.verifyEqual(kidsClickAnswer(500, W), "none");
            tc.verifyEqual(kidsClickAnswer(460, W), "none");
            tc.verifyEqual(kidsClickAnswer(540, W), "none");
        end
    end
end

function info = getInfo(kp, cfg)
    [~, info] = kidsNextLevel(kp, cfg);
end

function [kp, levels] = simulateChild(cfg, params, seed)
    % A simulated child answering yes/no with a Weibull: params = [alpha beta gamma lambda].
    kp = kidsProcedure(cfg, seed);
    rs = RandStream('mt19937ar', 'Seed', seed);
    levels = [];
    while ~kidsShouldStop(kp, cfg)
        [level, info] = kidsNextLevel(kp, cfg);
        kidsCheckLevel(level, cfg);
        levels(end + 1) = level; %#ok<AGROW>
        r = rand(rs) < PAL_Weibull(params, level);
        kp = kidsRecord(kp, level, r, info);
    end
end
