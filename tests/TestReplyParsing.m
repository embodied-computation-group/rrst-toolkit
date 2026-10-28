classdef TestReplyParsing < matlab.unittest.TestCase
    % Parser tests on firmware transcripts in tests/fixtures (constructed from the
    % firmware source; see tests/fixtures/README.md).

    methods (Test)
        % --- framing ---------------------------------------------------------
        function splitStripsCrPromptAndBlankLines(tc)
            [lines, complete] = rrst.splitReply(readFixture('calibrate_ok.txt'));
            tc.verifyTrue(complete);
            tc.verifyEqual(lines, [ ...
                "Starting calibration..."; ...
                "Min Endstop found. Position set to 0."; ...
                "Max Endstop found. Max Position: 45123 (previous saved: 45100, diff: +23)"; ...
                "First-contact position (retract 15.000 mm): 21123"]);
        end

        function replyWithoutPromptIsIncomplete(tc)
            [lines, complete] = rrst.splitReply(sprintf('\nEnter absolute target position (steps):\r\n'));
            tc.verifyFalse(complete);
            tc.verifyEqual(lines, "Enter absolute target position (steps):");
        end

        function emptyTextIsIncompleteWithNoLines(tc)
            [lines, complete] = rrst.splitReply('');
            tc.verifyFalse(complete);
            tc.verifyEmpty(lines);
        end

        % --- calibration -----------------------------------------------------
        function calibrationSuccess(tc)
            cal = rrst.parseCalibrationReply(rrst.splitReply(readFixture('calibrate_ok.txt')));
            tc.verifyTrue(cal.ok);
            tc.verifyEqual(cal.maxPosition, 45123);
            tc.verifyEqual(cal.firstContact, 21123);
            tc.verifyEqual(cal.retractMm, 15);
            tc.verifyEqual(cal.previousSaved, 45100);
            tc.verifyEqual(cal.errorText, "");
        end

        function calibrationSuccessWithoutSavedValue(tc)
            cal = rrst.parseCalibrationReply(rrst.splitReply(readFixture('calibrate_ok_first.txt')));
            tc.verifyTrue(cal.ok);
            tc.verifyEqual(cal.maxPosition, 44987);
            tc.verifyEqual(cal.firstContact, 20987);
            tc.verifyTrue(isnan(cal.previousSaved));
        end

        function calibrationCapturedFromDevice(tc)
            % Real reply from device 2E4441D76D5F2996, 2026-10-28 (no tube fitted).
            [lines, complete] = rrst.splitReply(readFixture('calibrate_ok__device_2E4441D76D5F2996__2026-10-28.txt'));
            tc.verifyTrue(complete);
            cal = rrst.parseCalibrationReply(lines);
            tc.verifyTrue(cal.ok);
            tc.verifyEqual(cal.maxPosition, 40079);
            tc.verifyEqual(cal.firstContact, 16079);
            tc.verifyEqual(cal.previousSaved, 39963);
            tc.verifyEqual(cal.retractMm, 15);
        end

        function enableCapturedFromDevice(tc)
            [lines, complete] = rrst.splitReply(readFixture('enable__device_2E4441D76D5F2996__2026-10-28.txt'));
            tc.verifyTrue(complete);
            tc.verifyTrue(any(startsWith(lines, "Stepper enabled")));
        end

        function calibrationFailures(tc)
            cal = rrst.parseCalibrationReply(rrst.splitReply(readFixture('calibrate_fail_min.txt')));
            tc.verifyFalse(cal.ok);
            tc.verifyEqual(cal.errorText, "ERROR: Min endstop not found - calibration aborted.");
            tc.verifyTrue(isnan(cal.maxPosition));

            cal = rrst.parseCalibrationReply(rrst.splitReply(readFixture('calibrate_fail_max.txt')));
            tc.verifyFalse(cal.ok);
            tc.verifyEqual(cal.errorText, "ERROR: Max endstop not found - calibration aborted.");
        end

        function calibrationWithErrorLineIsNotOk(tc)
            % A success line alongside any ERROR line must not count as success.
            lines = [rrst.splitReply(readFixture('calibrate_ok.txt')); ...
                "ERROR: Driver fault detected - stepper disabled. (overtemperature shutdown ) Investigate before re-enabling (e)."];
            cal = rrst.parseCalibrationReply(lines);
            tc.verifyFalse(cal.ok);
        end

        % --- moves -----------------------------------------------------------
        function moveSuccess(tc)
            mv = rrst.parseMoveReply(rrst.splitReply(readFixture('move_ok.txt')));
            tc.verifyTrue(mv.ok);
            tc.verifyEqual(mv.target, 32500);
            tc.verifyEmpty(mv.warnings);
            tc.verifyEqual(mv.errorText, "");
        end

        function moveSuccessKeepsWarnings(tc)
            mv = rrst.parseMoveReply(rrst.splitReply(readFixture('move_ok_with_warning.txt')));
            tc.verifyTrue(mv.ok);
            tc.verifyEqual(mv.warnings, ...
                "WARNING: Unexpected MAX endstop hit! Position auto-corrected to 45123.");
        end

        function moveRefusals(tc)
            mv = rrst.parseMoveReply(rrst.splitReply(readFixture('move_out_of_bounds.txt')));
            tc.verifyFalse(mv.ok);
            tc.verifyEqual(mv.errorText, "Error: Target out of calibrated bounds!");
            tc.verifyTrue(isnan(mv.target));

            mv = rrst.parseMoveReply(rrst.splitReply(readFixture('move_not_calibrated.txt')));
            tc.verifyFalse(mv.ok);
            tc.verifyEqual(mv.errorText, "Error: Must calibrate ('c') before moving.");
        end

        function moveSafetyDisable(tc)
            mv = rrst.parseMoveReply(rrst.splitReply(readFixture('move_safety_disable.txt')));
            tc.verifyFalse(mv.ok);
            tc.verifyNumElements(mv.warnings, 3);
            tc.verifyTrue(startsWith(mv.errorText, "ERROR: Repeated unexpected endstop hits"));
        end

        function moveWithoutCompletionIsNotOk(tc)
            % The connection-lost path prints no ERROR line, so only the missing
            % "Move complete." shows the move did not finish.
            mv = rrst.parseMoveReply(rrst.splitReply(readFixture('move_connection_lost.txt')));
            tc.verifyFalse(mv.ok);
            tc.verifyEqual(mv.target, 32500);
            tc.verifyNotEqual(mv.errorText, "");
        end

        % --- status ----------------------------------------------------------
        function statusCalibrated(tc)
            st = rrst.parseStatus(rrst.splitReply(readFixture('status_calibrated.txt')));
            tc.verifyEqual(st.softwareVersion, "Patient-Regulator (Oct  7 2026 08:45:06)");
            tc.verifyEqual(st.deviceId, "0123456789ABCDEF");
            tc.verifyTrue(st.stepperEnabled);
            tc.verifyTrue(st.calibrated);
            tc.verifyEqual(st.currentPosition, 32500);
            tc.verifyEqual(st.maxPosition, 45123);
            tc.verifyEqual(st.firstContact, 21123);
            tc.verifyEqual(st.retractSteps, 24000);
            tc.verifyEqual(st.retractMm, 15);
            tc.verifyEqual(st.speed, 16000);
            tc.verifyEqual(st.acceleration, 10000);
            tc.verifyEqual(st.runCurrent, 800);
            tc.verifyEqual(st.holdPercent, 50);
            tc.verifyEqual(st.microsteps, 16);
            tc.verifyEqual(st.chopperMode, "SpreadCycle");
        end

        function statusUncalibratedDoesNotTrustStaleMax(tc)
            st = rrst.parseStatus(rrst.splitReply(readFixture('status_uncalibrated.txt')));
            tc.verifyFalse(st.calibrated);
            tc.verifyFalse(st.stepperEnabled);
            tc.verifyTrue(isnan(st.maxPosition));
            tc.verifyTrue(isnan(st.firstContact));
            tc.verifyEqual(st.currentPosition, 20000);
        end

        function statusCapturedFromVigilantPiston(tc)
            % Real reply from the first 2.0 unit at the bench, 2026-10-28 (no device ID line).
            st = rrst.parseStatus(rrst.splitReply(readFixture('status_uncalibrated__fw_Vigilant-Piston__2026-10-28.txt')));
            tc.verifyEqual(st.softwareVersion, "Vigilant-Piston (Oct  1 2026 11:30:50)");
            tc.verifyEqual(st.deviceId, "");
            tc.verifyFalse(st.calibrated);
            tc.verifyFalse(st.stepperEnabled);
            tc.verifyEqual(st.currentPosition, 0);
            tc.verifyTrue(isnan(st.maxPosition));
            tc.verifyTrue(isnan(st.firstContact));
            tc.verifyEqual(st.retractSteps, 24000);
            tc.verifyEqual(st.acceleration, 10000);
            tc.verifyEqual(st.runCurrent, 795);
            tc.verifyEqual(st.chopperMode, "SpreadCycle");
        end

        function statusCapturedAfterFlash(tc)
            % Same unit after flashing Patient-Regulator, 2026-10-28: settings and saved max kept.
            st = rrst.parseStatus(rrst.splitReply(readFixture('status_uncalibrated__device_2E4441D76D5F2996__2026-10-28.txt')));
            tc.verifyEqual(st.softwareVersion, "Patient-Regulator (Oct  7 2026 08:45:06)");
            tc.verifyEqual(st.deviceId, "2E4441D76D5F2996");
            tc.verifyFalse(st.calibrated);
            tc.verifyTrue(isnan(st.maxPosition));
            tc.verifyEqual(st.runCurrent, 795);
        end

        function statusWithoutHeaderIsAnError(tc)
            tc.verifyError(@() rrst.parseStatus(["Move complete."]), 'rrst:badStatus');
        end
    end
end

function txt = readFixture(name)
    p = fullfile(fileparts(mfilename('fullpath')), 'fixtures', name);
    fid = fopen(p, 'r', 'n', 'UTF-8');
    cleaner = onCleanup(@() fclose(fid));
    txt = fread(fid, '*char')';
end
