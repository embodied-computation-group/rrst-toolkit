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

        function mockSpeedMatchesFixture(tc)
            port = rrst.MockPort();
            writeline(port, 'f');
            writeline(port, '12000');
            tc.verifyEqual(read(port, port.NumBytesAvailable, 'char'), readFixture('speed_set.txt'));
        end

        function mockAccelerationMatchesFixture(tc)
            port = rrst.MockPort();
            writeline(port, 'g');
            writeline(port, '20000');
            tc.verifyEqual(read(port, port.NumBytesAvailable, 'char'), readFixture('acceleration_set.txt'));
        end

        function mockChopperToggleMatchesFixture(tc)
            port = rrst.MockPort('ChopperMode', "SpreadCycle");
            writeline(port, 't');
            tc.verifyEqual(read(port, port.NumBytesAvailable, 'char'), ...
                readFixture('chopper_toggle_to_stealthchop.txt'));
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

        function calibrationFailureDisablesTheDriver(tc)
            % A failed 'c' leaves the driver energised; the toolkit sends 'd' before raising.
            port = rrst.MockPort('MaxPosition', 45123, 'Fault', "calibrateMinMissing");
            dev = rrst.Device(port);
            tc.verifyError(@() dev.calibrate(), 'rrst:calibrationFailed');
            tc.verifyEqual(port.Written, ["c"; "d"]);
            tc.verifyFalse(port.Enabled);
            tc.verifyFalse(dev.Enabled);
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

        function connectionLostMidMoveRaises(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            setDTR(port, false);
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

        % --- motion settings (speed, acceleration, chopper mode) ----------------
        function applyMotionSendsOnlyWhatDiffersAndNeverSaves(tc)
            port = rrst.MockPort('Speed', 16000, 'Acceleration', 10000, 'ChopperMode', "SpreadCycle");
            dev = rrst.Device(port);
            st = dev.applyMotion(struct('speed', 16000, 'acceleration', 20000, 'chopperMode', "StealthChop"));
            tc.verifyEqual(port.Written, ["s"; "g"; "20000"; "t"; "s"]);   % no 'f', no 'v'
            tc.verifyEqual([port.Speed port.Acceleration], [16000 20000]);
            tc.verifyEqual(port.ChopperMode, "StealthChop");
            tc.verifyEqual(st.acceleration, 20000);
            tc.verifyEqual(st.chopperMode, "StealthChop");
        end

        function applyMotionAlreadyMatchingOnlyReadsStatus(tc)
            port = rrst.MockPort('Speed', 16000, 'Acceleration', 10000, 'ChopperMode', "SpreadCycle");
            dev = rrst.Device(port);
            dev.applyMotion(struct('speed', 16000, 'acceleration', 10000, 'chopperMode', "SpreadCycle"));
            tc.verifyEqual(port.Written, "s");
        end

        function applyMotionSetsSpeed(tc)
            port = rrst.MockPort('Speed', 16000);
            dev = rrst.Device(port);
            dev.applyMotion(struct('speed', 12000, 'acceleration', 10000, 'chopperMode', "SpreadCycle"));
            tc.verifyEqual(port.Written, ["s"; "f"; "12000"; "s"]);
            tc.verifyEqual(port.Speed, 12000);
        end

        function invalidMotionSendsNothing(tc)
            port = rrst.MockPort();
            dev = rrst.Device(port);
            ok = struct('speed', 16000, 'acceleration', 10000, 'chopperMode', "SpreadCycle");
            bad = {setfield(ok, 'speed', 0), setfield(ok, 'acceleration', 1.5), ...
                   setfield(ok, 'chopperMode', "Silent"), rmfield(ok, 'speed')};
            for k = 1:numel(bad)
                tc.verifyError(@() dev.applyMotion(bad{k}), 'rrst:badSetting');
            end
            tc.verifyEmpty(port.Written);
        end

        function unconfirmedSettingRaises(tc)
            port = rrst.MockPort('Speed', 16000, 'Fault', "settingIgnored");
            dev = rrst.Device(port);
            tc.verifyError(@() dev.applyMotion( ...
                struct('speed', 12000, 'acceleration', 10000, 'chopperMode', "SpreadCycle")), ...
                'rrst:settingFailed');
        end

        function chopperToggleWithDriverLinkDownRaises(tc)
            port = rrst.MockPort('ChopperMode', "SpreadCycle", 'Fault', "uartDown");
            dev = rrst.Device(port);
            tc.verifyError(@() dev.applyMotion( ...
                struct('speed', 16000, 'acceleration', 10000, 'chopperMode', "StealthChop")), ...
                'rrst:settingFailed');
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

        function strayPromptIsNotTakenAsTheNextReply(tc)
            % Pilot 2026-10-28 14:00: a move sent 9 ms after the previous one read the
            % previous move's extra empty prompt as its reply and failed; the park
            % that followed then read the leftover reply and failed too.
            port = rrst.MockPort('MaxPosition', 45123, 'StrayPromptAfterMove', true);
            dev = rrst.Device(port);
            dev.calibrate();
            dev.moveTo(33108);
            mv = dev.moveTo(15604);              % sent at once, before the stray is read
            tc.verifyTrue(mv.ok);
            tc.verifyEqual(mv.target, 15604);
            mv = dev.moveTo(1600);
            tc.verifyTrue(mv.ok);
            tc.verifyEqual(mv.target, 1600);
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

        % --- WhileWaiting: work done while the firmware moves (2026-10-30) -------
        function mockMoveDelayHoldsTheConfirmation(tc)
            % MoveDelay: "Moving to" at once, "Move complete" and the prompt only
            % after the delay, as the real firmware (1.3-2.8 s per trial on 2E44...).
            port = rrst.MockPort('MaxPosition', 45123, 'MoveDelay', 0.3);
            writeline(port, 'c');
            read(port, port.NumBytesAvailable, 'char');
            t0 = tic;
            writeline(port, 'a');
            writeline(port, '32500');
            first = read(port, port.NumBytesAvailable, 'char');
            tc.verifyTrue(contains(first, 'Moving to absolute position: 32500'));
            tc.verifyFalse(contains(first, 'Move complete'));
            while port.NumBytesAvailable == 0 && toc(t0) < 2
                pause(0.01);
            end
            tc.verifyGreaterThanOrEqual(toc(t0), 0.3);
            rest = read(port, port.NumBytesAvailable, 'char');
            tc.verifyEqual([first rest], readFixture('move_ok.txt'));
        end

        function whileWaitingRunsDuringAMove(tc)
            port = rrst.MockPort('MaxPosition', 45123, 'MoveDelay', 0.3);
            dev = rrst.Device(port);
            dev.calibrate();
            [nTick, n] = counter();
            mv = dev.moveTo(32500, 'WhileWaiting', nTick);
            tc.verifyTrue(mv.ok);
            tc.verifyEqual(mv.target, 32500);
            tc.verifyGreaterThanOrEqual(mv.elapsed, 0.3);
            tc.verifyGreaterThanOrEqual(n('n'), 10, 'called on every poll while the firmware moves');
            tc.verifyEqual(port.Written, ["c"; "a"; "32500"], 'nothing else sent');
        end

        function whileWaitingWithATimeout(tc)
            port = rrst.MockPort('MaxPosition', 45123, 'MoveDelay', 0.2);
            dev = rrst.Device(port);
            dev.calibrate();
            [nTick, n] = counter();
            mv = dev.moveTo(32500, 30, 'WhileWaiting', nTick);
            tc.verifyTrue(mv.ok);
            tc.verifyGreaterThan(n('n'), 0);
            port.Fault = "silent";
            [n2Tick, n2] = counter();
            tc.verifyError(@() dev.moveTo(30000, 0.2, 'WhileWaiting', n2Tick), 'rrst:timeout');
            tc.verifyGreaterThan(n2('n'), 0, 'called until the timeout');
        end

        function whileWaitingDoesNotReplaceTheFirmwareCheck(tc)
            % The firmware reply stays the source of truth: a refused move still fails.
            port = rrst.MockPort('MaxPosition', 45123, 'MoveDelay', 0.1);
            dev = rrst.Device(port);
            dev.calibrate();
            port.Fault = "moveSafetyDisable";
            [nTick, n] = counter();
            tc.verifyError(@() dev.moveTo(32500, 'WhileWaiting', nTick), 'rrst:moveFailed');
            tc.verifyGreaterThan(n('n'), 0);
        end

        function whileWaitingOnCommand(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            [nTick, n] = counter();
            lines = dev.command("s", 10, 'WhileWaiting', nTick);
            tc.verifyTrue(any(startsWith(lines, "Device ID")));
        end

        function badWhileWaitingSendsNothing(tc)
            port = rrst.MockPort('MaxPosition', 45123);
            dev = rrst.Device(port);
            dev.calibrate();
            nBefore = numel(port.Written);
            tc.verifyError(@() dev.moveTo(32500, 'WhileWaiting', 5), 'rrst:badArgument');
            tc.verifyError(@() dev.moveTo(32500, 'Whilst', @() 1), 'rrst:badArgument');
            tc.verifyEqual(numel(port.Written), nBefore);
        end
    end
end

function [tick, m] = counter()
% A WhileWaiting callback for the tests: tick() adds one to m('n') (a
% containers.Map, so the count is shared by handle).
m = containers.Map({'n'}, {0});
tick = @() bump(m);
end

function bump(m)
m('n') = m('n') + 1; %#ok<NASGU> a handle: the caller's map changes
end

function txt = readFixture(name)
    p = fullfile(fileparts(mfilename('fullpath')), 'fixtures', name);
    fid = fopen(p, 'r', 'n', 'UTF-8');
    cleaner = onCleanup(@() fclose(fid));
    txt = fread(fid, '*char')';
end
