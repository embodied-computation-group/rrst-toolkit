classdef TestTaskSupport < matlab.unittest.TestCase
    % Device records, port choice, masking noise and task configuration.

    methods (TestClassSetup)
        function addConfigPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = [fullfile(root, 'task', 'RRST_2-0', {'config', 'code'}), {fullfile(root, 'task', 'helpers')}];
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

        function rainLoopLoadsAsStereo48k(tc)
            [x, fs] = rrst.loadMaskingSound(rainLoopFile());
            tc.verifyEqual(fs, 48000);
            tc.verifySize(x, [30 * 48000 2]);
            tc.verifyLessThanOrEqual(max(abs(x(:))), 1);
            tc.verifyGreaterThan(min(std(x)), 0.01);
        end

        function rainLoopLoopsWithoutAJump(tc)
            % Played as a loop: the step from the last sample back to the first
            % must be as small as an ordinary sample-to-sample step.
            x = rrst.loadMaskingSound(rainLoopFile());
            for ch = 1:2
                tc.verifyLessThan(abs(x(end, ch) - x(1, ch)), 4 * std(diff(x(:, ch))));
            end
        end

        function missingSoundFileIsAnError(tc)
            tc.verifyError(@() rrst.loadMaskingSound(fullfile(tempdir, 'no_such_sound.wav')), ...
                'rrst:badNoise');
        end

        % --- task configuration ---------------------------------------------
        function pilotConfigUsesTheRainLoop(tc)
            cfg = pilotConfig();
            tc.verifyTrue(isfile(cfg.noise.file));
            tc.verifyEqual(string(cfg.noise.file), string(rainLoopFile()));
        end

        function missingNoiseFileIsRejected(tc)
            cfg = pilotConfig();
            cfg.noise.file = fullfile(tempdir, 'no_such_sound.wav');
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function pilotConfigIsValid(tc)
            cfg = pilotConfig();
            validateConfig(cfg);
            tc.verifyEqual(cfg.label, "PILOT");
        end

        function tutorialNeedsABreathForEveryPracticeLevel(tc)
            cfg = pilotConfig();
            cfg.tutorial.stimInAlt = [1 2];
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function tutorialBreathMustBeFirstOrSecond(tc)
            cfg = pilotConfig();
            cfg.tutorial.stimInAlt = [1 3 2];
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
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

        % --- event markers --------------------------------------------------
        function markersSwitchMustBeLogical(tc)
            cfg = pilotConfig();
            cfg.markers.lsl = "yes";
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function requireRecorderMustBeLogical(tc)
            cfg = pilotConfig();
            cfg.markers.requireRecorder = 1;
            tc.verifyError(@() validateConfig(cfg), 'rrst:badConfig');
        end

        function markerIsANoOpUntilOpened(tc)
            rrstMarker('close');
            rrstMarker('trial_1_interval1_onset_load', 12.3);   % no outlet: no error, no LSL needed
            tc.verifyFalse(rrstMarker('recorded'));
        end

        function missingLiblslIsAClearError(tc)
            rrstMarker('close');
            tc.verifyError(@() rrstMarker('open', fullfile(tempdir, 'no_liblsl_here')), 'rrst:noLiblsl');
        end

        function zurichConfigRefusesUntilDecided(tc)
            tc.verifyError(@() zurichConfig(), 'rrst:decisionsPending');
        end

        % --- session files: several sessions per ID, nothing overwritten ----
        function fileStemCarriesIdAndSession(tc)
            tc.verifyEqual(sessionFileStem(1, 2, false), 'RRST_0001_s2');
            tc.verifyEqual(sessionFileStem(17, 3, true), 'MOCK_RRST_0017_s3');
        end

        function sessionMustBeAPositiveWholeNumber(tc)
            tc.verifyError(@() sessionFileStem(1, 0, false), 'rrst:badSession');
            tc.verifyError(@() sessionFileStem(1, 1.5, false), 'rrst:badSession');
            tc.verifyError(@() sessionFileStem(1, [], false), 'rrst:badSession');
        end

        function nextSessionOfTheSameIdIsAllowed(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            touch(d, 'RRST_0001_s1_psi_2026-11-02_0900.mat');
            checkSessionIsNew(d, 'RRST_0001_s2');               % no error
            checkSessionIsNew(d, 'RRST_0002_s1');
        end

        function completedSessionCannotBeRunAgain(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            touch(d, 'RRST_0001_s2_psi_2026-11-09_0900.mat');
            tc.verifyError(@() checkSessionIsNew(d, 'RRST_0001_s2'), 'rrst:dataExists');
        end

        function abortedSessionCanBeRunAgain(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            touch(d, 'Aborted_RRST_0001_s2_psi_2026-11-09_0900.mat');
            touch(d, 'Error_RRST_0001_s2_psi_2026-11-09_0910.mat');
            checkSessionIsNew(d, 'RRST_0001_s2');               % no error
        end

        function sessionTenIsNotSessionOne(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            touch(d, 'RRST_0001_s10_psi_2026-11-09_0900.mat');
            checkSessionIsNew(d, 'RRST_0001_s1');               % no error
        end

        function savingNeverOverwrites(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            tc.verifyEqual(uniqueFileName(d, 'Aborted_RRST_0001_s2_psi_2026-11-09_0900'), ...
                'Aborted_RRST_0001_s2_psi_2026-11-09_0900');
            touch(d, 'Aborted_RRST_0001_s2_psi_2026-11-09_0900.mat');
            tc.verifyEqual(uniqueFileName(d, 'Aborted_RRST_0001_s2_psi_2026-11-09_0900'), ...
                'Aborted_RRST_0001_s2_psi_2026-11-09_0900_2');
            touch(d, 'Aborted_RRST_0001_s2_psi_2026-11-09_0900_2.csv');   % a .csv alone also counts
            tc.verifyEqual(uniqueFileName(d, 'Aborted_RRST_0001_s2_psi_2026-11-09_0900'), ...
                'Aborted_RRST_0001_s2_psi_2026-11-09_0900_3');
        end
    end
end

function touch(d, name)
fclose(fopen(fullfile(d, name), 'w'));
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

function f = rainLoopFile()
    f = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'task', 'helpers', 'audio', ...
        'rain_loop_30s.wav');
end

function r = bandPowerRatio(x, fs)
    X = abs(fft(x)).^2;
    f = (0:numel(x) - 1)' * fs / numel(x);
    lo = mean(X(f >= 50 & f <= 100));
    hi = mean(X(f >= 2000 & f <= 4000));
    r = lo / hi;
end
