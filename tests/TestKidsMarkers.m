classdef TestKidsMarkers < matlab.unittest.TestCase
    % RRST-Kids LSL event markers: configuration, the open/no-op rule, the
    % wait-for-recorder rule and the exact marker labels. No hardware, no screen,
    % no liblsl: no real stream is ever opened here.

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = [fullfile(root, 'task', 'RRST_kids', {'config', 'code'}), ...
                {fullfile(root, 'task', 'helpers')}];               % rrstMarker
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
            tc.addTeardown(@() rrstMarker('close'));
        end
    end

    methods (Test)
        % --- configuration ---------------------------------------------------
        function defaultsAreValid(tc)
            cfg = kidsConfig();
            validateKidsConfig(cfg);
            tc.verifyEqual(cfg.markers.lsl, true);
            tc.verifyEqual(cfg.markers.requireRecorder, true);
            tc.verifyEqual(cfg.markers.liblslDir, "C:\toolbox\liblsl-Matlab");
        end

        function markerFlagsMustBeLogical(tc)
            for bad = {"yes", 1, [true true], []}
                cfg = kidsConfig();
                cfg.markers.lsl = bad{1};
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
                cfg = kidsConfig();
                cfg.markers.requireRecorder = bad{1};
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            end
        end

        function liblslDirMustBeText(tc)
            cfg = kidsConfig();
            cfg.markers.liblslDir = 'C:\toolbox\liblsl-Matlab';   % char is fine
            validateKidsConfig(cfg);
            for bad = {3, "", ["a" "b"], []}
                cfg.markers.liblslDir = bad{1};
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            end
        end

        function missingMarkersBlockIsRejected(tc)
            cfg = rmfield(kidsConfig(), 'markers');
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
        end

        % --- open / no-op ----------------------------------------------------
        function markersOffAreNoOpsWithoutLiblsl(tc)
            cfg = kidsConfig();
            cfg.markers.lsl = false;
            cfg.markers.liblslDir = fullfile(tempdir, 'no_liblsl_here');
            closer = kidsOpenMarkers(cfg); %#ok<NASGU>   no error: liblsl not needed
            labels = {'RRST_ready', 'calibration_start', 'calibration_end', 'story', ...
                'practice_start', 'main_start', kidsMarkerLabel("level", 1, 0), ...
                kidsMarkerLabel("go", 1), 'question', kidsMarkerLabel("answer", "yes"), ...
                kidsMarkerLabel("outcome", 1, 0, 1), 'rest_start', 'rest_end', 'aborted', 'done'};
            for k = 1:numel(labels)
                rrstMarker(labels{k});
                rrstMarker(labels{k}, 12.3);
            end
            tc.verifyFalse(rrstMarker('recorded'));
        end

        function markersOnOpenTheStream(tc)
            % With markers on, the stream is opened: a missing liblsl is the clear error.
            cfg = kidsConfig();
            cfg.markers.liblslDir = fullfile(tempdir, 'no_liblsl_here');
            tc.verifyError(@() kidsOpenMarkers(cfg), 'rrst:noLiblsl');
        end

        % --- wait for a recorder -----------------------------------------------
        function realSessionWaitsForTheRecorder(tc)
            tc.verifyTrue(kidsWaitsForRecorder(kidsConfig()));
        end

        function mockOrSimulatedRunsDoNotWait(tc)
            cfg = kidsConfig();
            cfg.device.mock = true;
            tc.verifyFalse(kidsWaitsForRecorder(cfg));
            cfg = kidsConfig();
            cfg.debug.simulateChild = [70 8 0.1 0.1];
            tc.verifyFalse(kidsWaitsForRecorder(cfg));
        end

        function noWaitWithoutMarkersOrWhenNotRequired(tc)
            cfg = kidsConfig();
            cfg.markers.lsl = false;
            tc.verifyFalse(kidsWaitsForRecorder(cfg));
            cfg = kidsConfig();
            cfg.markers.requireRecorder = false;
            tc.verifyFalse(kidsWaitsForRecorder(cfg));
        end

        % --- labels ----------------------------------------------------------
        function levelLabelForANormalTrial(tc)
            tc.verifyEqual(kidsMarkerLabel("level", 7, 70), 'trial_7_level_70');
            tc.verifyEqual(kidsMarkerLabel("level", 3, 72.5), 'trial_3_level_72.5');
        end

        function catchTrialCarriesLevelZero(tc)
            tc.verifyEqual(kidsMarkerLabel("level", 8, 0), 'trial_8_level_0');
        end

        function goLabel(tc)
            tc.verifyEqual(kidsMarkerLabel("go", 12), 'trial_12_go');
        end

        function answerLabels(tc)
            tc.verifyEqual(kidsMarkerLabel("answer", "yes"), 'answer_yes');
            tc.verifyEqual(kidsMarkerLabel("answer", "no"), 'answer_no');
            tc.verifyEqual(kidsMarkerLabel("answer", "bad"), 'bad_breath');
            tc.verifyEqual(kidsMarkerLabel("answer", "none"), 'no_answer');
            tc.verifyEqual(kidsMarkerLabel("answer", "pause"), 'pause');
            tc.verifyEqual(kidsMarkerLabel("answer", "abort"), '');   % 'aborted' follows
            tc.verifyError(@() kidsMarkerLabel("answer", "maybe"), 'rrst:badMarker');
        end

        function outcomeIsCorrectWhenTheAnswerMatchesTheLoad(tc)
            % correct: "yes" (1) on a loaded trial, "no" (0) on a catch trial
            tc.verifyEqual(kidsMarkerLabel("outcome", 4, 70, 1), 'trial_4_correct');
            tc.verifyEqual(kidsMarkerLabel("outcome", 4, 70, 0), 'trial_4_wrong');
            tc.verifyEqual(kidsMarkerLabel("outcome", 5, 0, 0), 'trial_5_correct');
            tc.verifyEqual(kidsMarkerLabel("outcome", 5, 0, 1), 'trial_5_wrong');
        end

        function unknownEventIsAnError(tc)
            tc.verifyError(@() kidsMarkerLabel("slurp", 1), 'rrst:badMarker');
        end
    end
end
