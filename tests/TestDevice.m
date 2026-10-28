classdef TestDevice < matlab.unittest.TestCase
    % rrst.Device driven against rrst.MockPort (a simulated firmware). No hardware.

    methods (Test)
        % --- the simulator matches the constructed transcripts ---------------
        function mockCalibrateMatchesFixture(tc)
            port = rrst.MockPort('MaxPosition', 45123, 'SavedMaxPosition', 45100);
            writeline(port, 'c');
            tc.verifyEqual(read(port, port.NumBytesAvailable, 'char'), readFixture('calibrate_ok.txt'));
        end

        function mockMoveMatchesFixture(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            writeline(port, 'c');
            read(port, port.NumBytesAvailable, 'char');
            writeline(port, 'a');
            writeline(port, '32500');
            tc.verifyEqual(read(port, port.NumBytesAvailable, 'char'), readFixture('move_ok.txt'));
        end

        % --- normal session --------------------------------------------------
        function calibrateEnableMove(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            cal = dev.calibrate();
            tc.verifyEqual(cal.maxPosition, 45123);
            tc.verifyEqual(dev.MaxPosition, 45123);
            tc.verifyEqual(dev.FirstContact, 21123);
            dev.enable();
            mv = dev.moveTo(32500);
            tc.verifyTrue(mv.ok);
            tc.verifyEqual(mv.target, 32500);
            tc.verifyEqual(port.Position, 32500);
            tc.verifyEqual(port.Written, ["c"; "e"; "a"; "32500"]);
        end

        function statusIsParsed(tc)
            port = rrst.MockPort('MaxPosition', 45123, 'DeviceId', "00AA11BB22CC33DD");
            dev = rrst.Device(port);
            st = dev.status();
            tc.verifyEqual(st.deviceId, "00AA11BB22CC33DD");
            tc.verifyFalse(st.calibrated);
        end

        function transcriptRecordsBothDirections(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            dirs = [dev.Transcript.direction];
            tc.verifyEqual(dirs, ["tx", "rx"]);
            tc.verifyEqual(dev.Transcript(1).text, "c");
            tc.verifyTrue(contains(dev.Transcript(2).text, "Max Endstop found"));
        end

        % --- refusals before anything is sent --------------------------------
        function moveBeforeCalibrationSendsNothing(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            tc.verifyError(@() dev.moveTo(32500), 'rrst:notCalibrated');
            tc.verifyEmpty(port.Written);
        end

        function moveOutsideCalibratedRangeSendsNothing(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            tc.verifyError(@() dev.moveTo(45124), 'rrst:outOfRange');
            tc.verifyError(@() dev.moveTo(-1), 'rrst:outOfRange');
            tc.verifyError(@() dev.moveTo(100.5), 'rrst:outOfRange');
            tc.verifyEqual(port.Written, "c");
        end

        % --- firmware-reported failures --------------------------------------
        function calibrationFailureRaises(tc)
            port = rrst.MockPort('MaxPosition', 45123, 'Fault', "calibrateMinMissing");
            dev = rrst.Device(port);
            tc.verifyError(@() dev.calibrate(), 'rrst:calibrationFailed');
            tc.verifyFalse(dev.Calibrated);
            tc.verifyTrue(isnan(dev.MaxPosition));
        end

        function calibrationWithoutDtrRaisesWithHint(tc)
            port = rrst.MockPort('MaxPosition', 45123, 'DtrAsserted', false);
            dev = rrst.Device(port);
            try
                dev.calibrate();
                tc.verifyFail('calibrate should have raised');
            catch err
                tc.verifyEqual(err.identifier, 'rrst:calibrationFailed');
                tc.verifyTrue(contains(err.message, "DTR"));
            end
        end

        function firmwareSafetyDisableRaises(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            port.Fault = "moveSafetyDisable";
            tc.verifyError(@() dev.moveTo(32500), 'rrst:moveFailed');
        end

        function autoCorrectedHitSucceedsWithWarning(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            port.Fault = "moveWarning";
            mv = dev.moveTo(32500);
            tc.verifyTrue(mv.ok);
            tc.verifyNumElements(mv.warnings, 1);
        end

        function noReplyTimesOut(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            port.Fault = "silent";
            t0 = tic;
            tc.verifyError(@() dev.moveTo(32500, 0.3), 'rrst:timeout');
            tc.verifyLessThan(toc(t0), 2);
        end

        % --- unsolicited output ----------------------------------------------
        function unsolicitedDriverFaultStopsNextCommand(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            queueUnsolicited(port, sprintf(['\nERROR: Driver fault detected - stepper disabled. ' ...
                '(overtemperature shutdown ) Investigate before re-enabling (e).\r\n']));
            nBefore = numel(port.Written);
            tc.verifyError(@() dev.moveTo(32500), 'rrst:deviceFault');
            tc.verifyEqual(numel(port.Written), nBefore);   % the move was not sent
            tc.verifyTrue(any([dev.Transcript.direction] == "unsolicited"));
        end

        function unsolicitedNonErrorTextIsLoggedNotFatal(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            queueUnsolicited(port, sprintf('\r\nValve>'));   % e.g. a stray prompt
            mv = dev.moveTo(32500);
            tc.verifyTrue(mv.ok);
            tc.verifyTrue(any([dev.Transcript.direction] == "unsolicited"));
        end
    end
end

function txt = readFixture(name)
    p = fullfile(fileparts(mfilename('fullpath')), 'fixtures', name);
    fid = fopen(p, 'r', 'n', 'UTF-8');
    cleaner = onCleanup(@() fclose(fid));
    txt = fread(fid, '*char')';
end
