classdef TestTaskSupport < matlab.unittest.TestCase
    % Device records, port choice, masking noise and task configuration.

    methods (TestClassSetup)
        function addConfigPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_2-0', {'config', 'code'});
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
        end
    end

    methods (Test)
        % --- device records -------------------------------------------------
        function realRecordLoads(tc)
            rec = rrst.loadDeviceRecord("2E4441D76D5F2996", devicesDir());
            tc.verifyEqual(rec.anchors.zeroOffset, 25600);
            tc.verifyEqual(rec.anchors.fullOffset, 800);
            tc.verifyEqual(rec.anchors.maxPositionAtMeasurement, 41296);
        end

        function missingRecordIsAnError(tc)
            tc.verifyError(@() rrst.loadDeviceRecord("FFFFFFFFFFFFFFFF", devicesDir()), ...
                'rrst:noDeviceRecord');
        end

        % --- port choice ----------------------------------------------------
        function explicitPortIsUsed(tc)
            tc.verifyEqual(rrst.choosePort("COM7", ["COM3" "COM7"]), "COM7");
        end

        function explicitPortMustExist(tc)
            tc.verifyError(@() rrst.choosePort("COM9", ["COM3"]), 'rrst:noPort');
        end

        function autoPicksTheOnlyPort(tc)
            tc.verifyEqual(rrst.choosePort("auto", "COM4"), "COM4");
        end

        function autoRefusesToGuessBetweenPorts(tc)
            tc.verifyError(@() rrst.choosePort("auto", ["COM3" "COM4"]), 'rrst:ambiguousPort');
            tc.verifyError(@() rrst.choosePort("auto", strings(1, 0)), 'rrst:noPort');
        end

        % --- masking noise --------------------------------------------------
        function noiseHasRequestedLengthAndStaysInRange(tc)
            x = rrst.maskingNoise(8000, 2, "pink", 1);
            tc.verifySize(x, [16000 1]);
            tc.verifyLessThanOrEqual(max(abs(x)), 1);
            tc.verifyGreaterThan(std(x), 0.05);
        end

        function noiseIsReproducibleWithSeed(tc)
            tc.verifyEqual(rrst.maskingNoise(8000, 1, "pink", 7), rrst.maskingNoise(8000, 1, "pink", 7));
            tc.verifyNotEqual(rrst.maskingNoise(8000, 1, "pink", 7), rrst.maskingNoise(8000, 1, "pink", 8));
        end

        function pinkNoiseHasMoreLowThanHighFrequencyPower(tc)
            % Pink: power ~ 1/f, so the 50-100 Hz band carries far more power per Hz
            % than 2-4 kHz. White noise would give a ratio near 1.
            fs = 16000;
            p = bandPowerRatio(rrst.maskingNoise(fs, 4, "pink", 3), fs);
            w = bandPowerRatio(rrst.maskingNoise(fs, 4, "white", 3), fs);
            tc.verifyGreaterThan(p, 10);
            tc.verifyLessThan(w, 2);
        end

        function noiseLoopsWithoutAJump(tc)
            % The buffer is looped; the step from last to first sample must be as
            % small as an ordinary sample-to-sample step.
            x = rrst.maskingNoise(8000, 2, "pink", 5);
            tc.verifyLessThan(abs(x(end) - x(1)), 4 * std(diff(x)));
        end

        % --- task configuration ---------------------------------------------
        function pilotConfigIsValid(tc)
            cfg = pilotConfig();
            validateConfig(cfg);
            tc.verifyEqual(cfg.label, "PILOT");
        end

        function oddTrialCountIsRejected(tc)
            cfg = pilotConfig();
            cfg.psi.numTrials = 99;
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function percentGridAbove100IsRejected(tc)
            cfg = pilotConfig();
            cfg.psi.stimRange = linspace(0, 110, 45);
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function pilotConfigSetsMotion(tc)
            cfg = pilotConfig();
            tc.verifyTrue(all(isfield(cfg.device.motion, {'speed', 'acceleration', 'chopperMode'})));
        end

        function stealthChopAbove16000IsRejected(tc)
            % Martin, 2026-10-28: StealthChop lost steps at peak speeds of 20000 and above.
            cfg = pilotConfig();
            cfg.device.motion = struct('speed', 20000, 'acceleration', 10000, 'chopperMode', "StealthChop");
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
            cfg.device.motion.chopperMode = "SpreadCycle";
            validateConfig(cfg);   % SpreadCycle passed up to 32000
        end

        function badMotionIsRejected(tc)
            cfg = pilotConfig();
            cfg.device.motion.chopperMode = "Silent";
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
            cfg = pilotConfig();
            cfg.device.motion.acceleration = 0;
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function unportedProcedureIsRejected(tc)
            cfg = pilotConfig();
            cfg.procedure = "ndown";
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        % --- trial table (the CSV) ------------------------------------------
        function trialTableKeepsOnlyPerTrialColumns(tc)
            R = fictionalResults(6);
            T = trialTable(R);
            tc.verifyEqual(height(T), 6);
            tc.verifyEqual(T.Properties.VariableNames, {'trialN', 'Stim', 'Resp', 'StimMoveT'});
            tc.verifyEqual(T.Stim, R.Stim);
        end

        function trialTableIgnoresRatingsShapedLikeTrials(tc)
            % 4 trials and one break: ExpRateTask is 4x1, like a trial column
            R = fictionalResults(4);
            R.ExpRateTask = [10; 0.5; 1; 1];
            R.ExpRareEnd = [1; 2; 3; 4];
            T = trialTable(R);
            tc.verifyFalse(any(ismember({'ExpRateTask', 'ExpRareEnd'}, T.Properties.VariableNames)));
        end

        function zurichConfigRefusesUntilDecided(tc)
            tc.verifyError(@() zurichConfig(), 'rrst:decisionsPending');
        end
    end
end

function R = fictionalResults(n)
% FICTIONAL Results struct shaped like main.m's.
R.trialN = (1:n)';
R.Stim = linspace(10, 90, n)';
R.Resp = mod((1:n)', 2);
R.StimMoveT = repmat(0.5, n, 1);
R.Calibrations = 2;
R.SessionStartT = 123.4;
R.ExpRateTask = [10 20; 0.5 0.6; 1 1; 1 2];
R.ExpRareEnd = magic(4);
R.stair = struct('PM', struct('xCurrent', 50));
end

function d = devicesDir()
    d = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'devices');
end

function r = bandPowerRatio(x, fs)
    X = abs(fft(x)).^2;
    f = (0:numel(x) - 1)' * fs / numel(x);
    lo = mean(X(f >= 50 & f <= 100));
    hi = mean(X(f >= 2000 & f <= 4000));
    r = lo / hi;
end
