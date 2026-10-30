classdef TestStimulator < matlab.unittest.TestCase
    % rrst.Stimulator: stimulus levels -> checked device moves, using a device record.
    % Known answers use the fictional mock record (devices/0123456789ABCDEF.json):
    % MaxPosition 45000, zeroOffset 25600, fullOffset 800
    %   -> zeroStep 19400, fullStep 44200, range 24800 steps = 15.5 mm.

    properties
        Port
        Stim
    end

    methods (TestMethodSetup)
        function makeStimulator(tc)
            tc.Port = rrst.MockPort('MaxPosition', 45000);
            dev = rrst.Device(tc.Port);
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            tc.Stim = rrst.Stimulator(dev, rec, 'Unit', "percent", 'RestRange', [20 80]);
        end
    end

    methods (Test)
        function calibrationSetsAnchorsFromRecord(tc)
            tc.Stim.calibrate();
            tc.verifyEqual(tc.Stim.ZeroStep, 19400);
            tc.verifyEqual(tc.Stim.FullStep, 44200);
            tc.verifyTrue(tc.Port.Enabled);          % 'e' sent after 'c'
        end

        function calibrationWithoutMotionLeavesSettingsAlone(tc)
            tc.Stim.calibrate();
            tc.verifyEqual(tc.Port.Written, ["s"; "c"; "e"]);
        end

        function calibrationAppliesMotionBeforeC(tc)
            port = rrst.MockPort('MaxPosition', 45000, 'ChopperMode', "SpreadCycle");
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            motion = struct('speed', 16000, 'acceleration', 20000, 'chopperMode', "StealthChop");
            s = rrst.Stimulator(rrst.Device(port), rec, 'Motion', motion);
            s.calibrate();
            tc.verifyEqual(port.Written, ["s"; "g"; "20000"; "t"; "s"; "c"; "e"]);
            sm = s.summary();
            tc.verifyEqual(sm.motion, motion);
            tc.verifyEqual(sm.deviceStatus.chopperMode, "StealthChop");
        end

        function summaryRecordsFirmwareIdentity(tc)
            tc.Port.GitCommit = "aa8dd72";
            tc.Stim.calibrate();
            sm = tc.Stim.summary();
            tc.verifyEqual(sm.deviceStatus.gitCommit, "aa8dd72");
            tc.verifyEqual(sm.deviceStatus.softwareVersion, tc.Port.SoftwareVersion);
        end

        function percentLevelsMapLinearly(tc)
            tc.Stim.calibrate();
            tc.verifyEqual(tc.Stim.levelToSteps(0), 19400);
            tc.verifyEqual(tc.Stim.levelToSteps(100), 44200);
            tc.verifyEqual(tc.Stim.levelToSteps(50), 31800);
            tc.verifyEqual(tc.Stim.levelToSteps(25), 25600);
        end

        function mmLevelsAre1600StepsPerMm(tc)
            dev = rrst.Device(rrst.MockPort('MaxPosition', 45000));
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            s = rrst.Stimulator(dev, rec, 'Unit', "mm", 'RestRange', [2 10]);
            tc.verifyEqual(s.ScaleMax, 15.5);
            s.calibrate();
            tc.verifyEqual(s.levelToSteps(1), 19400 + 1600);
            tc.verifyEqual(s.levelToSteps(15.5), 44200);
        end

        function levelsBeyondScaleAreErrorsNotClipped(tc)
            tc.Stim.calibrate();
            tc.verifyError(@() tc.Stim.levelToSteps(100.5), 'rrst:outOfRange');
            tc.verifyError(@() tc.Stim.levelToSteps(-1), 'rrst:outOfRange');
        end

        function gridBeyondDeviceRangeIsRejectedUpFront(tc)
            dev = rrst.Device(rrst.MockPort('MaxPosition', 45000));
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            s = rrst.Stimulator(dev, rec, 'Unit', "mm", 'RestRange', [2 10]);
            tc.verifyError(@() s.validateLevels(linspace(0, 17, 36)), 'rrst:levelOutOfRange');
            s.validateLevels(linspace(0, 15.5, 32));   % fits: no error
        end

        function restRangeOutsideScaleIsRejected(tc)
            dev = rrst.Device(rrst.MockPort());
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            tc.verifyError(@() rrst.Stimulator(dev, rec, 'Unit', "percent", 'RestRange', [20 120]), ...
                'rrst:levelOutOfRange');
        end

        function movingBeforeCalibrationIsAnError(tc)
            tc.verifyError(@() tc.Stim.present(50), 'rrst:notCalibrated');
        end

        function presentMovesAndLogs(tc)
            tc.Stim.calibrate();
            tc.Stim.present(50);
            tc.verifyEqual(tc.Port.Position, 31800);
            tc.Stim.null();
            tc.verifyEqual(tc.Port.Position, 19400);
            log = tc.Stim.Log;
            tc.verifyEqual([log.steps], [31800 19400]);
            tc.verifyEqual(string({log.kind}), ["stim" "null"]);
            tc.verifyEqual([log.level], [50 0]);
        end

        function restStaysInsideRestRange(tc)
            tc.Stim.calibrate();
            for k = 1:20
                level = tc.Stim.rest();
                tc.verifyGreaterThanOrEqual(level, 20);
                tc.verifyLessThanOrEqual(level, 80);
                tc.verifyEqual(tc.Port.Position, tc.Stim.levelToSteps(level));
            end
        end

        function parkGoesToParkStepOpen(tc)
            tc.Stim.calibrate();
            tc.Stim.present(80);
            tc.Stim.park();
            tc.verifyEqual(tc.Port.Position, 1600);
            tc.verifyEqual(tc.Stim.Log(end).kind, 'park');
        end

        function calibrationFarFromRecordIsAnError(tc)
            % Tube condition differs from the record: MaxPosition about 1150 steps off.
            dev = rrst.Device(rrst.MockPort('MaxPosition', 43850));
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            s = rrst.Stimulator(dev, rec, 'Unit', "percent", 'RestRange', [20 80]);
            tc.verifyError(@() s.calibrate(), 'rrst:calibrationMismatch');
        end

        function calibrationWithinToleranceIsAccepted(tc)
            dev = rrst.Device(rrst.MockPort('MaxPosition', 45076));
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            s = rrst.Stimulator(dev, rec, 'Unit', "percent", 'RestRange', [20 80]);
            s.calibrate();
            tc.verifyEqual(s.ZeroStep, 45076 - 25600);
            tc.verifyEqual(numel(s.Calibrations), 1);
        end

        function wrongDeviceRecordIsRejected(tc)
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            rec.deviceId = "FFFFFFFFFFFFFFFF";
            s = rrst.Stimulator(rrst.Device(rrst.MockPort()), rec, 'Unit', "percent", 'RestRange', [20 80]);
            tc.verifyError(@() s.calibrate(), 'rrst:wrongDevice');
        end

        function summaryKeepsEverythingNeededToAudit(tc)
            tc.Stim.calibrate();
            tc.Stim.present(10);
            sm = tc.Stim.summary();
            tc.verifyEqual(sm.deviceId, "0123456789ABCDEF");
            tc.verifyEqual(sm.unit, "percent");
            tc.verifyEqual(numel(sm.moves), 1);
            tc.verifyEqual(numel(sm.calibrations), 1);
            tc.verifyNotEmpty(sm.transcript);
        end

        function whileWaitingReachesEveryMove(tc)
            % present, null, rest and park pass 'WhileWaiting' to the device: the
            % task animates while the firmware moves (2026-10-30: 1.3-2.8 s per move).
            port = rrst.MockPort('MaxPosition', 45000, 'MoveDelay', 0.15);
            rec = rrst.loadDeviceRecord("0123456789ABCDEF", devicesDir());
            s = rrst.Stimulator(rrst.Device(port), rec, 'Unit', "percent", 'RestRange', [20 80]);
            s.calibrate();
            m = containers.Map({'n'}, {0});
            f = @() bump(m);
            s.present(50, 'WhileWaiting', f);
            n1 = m('n');
            tc.verifyGreaterThan(n1, 0, 'present');
            s.null('WhileWaiting', f);
            n2 = m('n');
            tc.verifyGreaterThan(n2, n1, 'null');
            [level, mv] = s.rest('WhileWaiting', f);
            n3 = m('n');
            tc.verifyGreaterThan(n3, n2, 'rest');
            tc.verifyTrue(mv.ok);
            tc.verifyGreaterThanOrEqual(level, 20);
            s.park('WhileWaiting', f);
            tc.verifyGreaterThan(m('n'), n3, 'park');
            tc.verifyEqual(string({s.Log.kind}), ["stim" "null" "rest" "park"]);
            tc.verifyEqual(port.Position, s.ParkStep);
        end

        function presentKeepsItsKindArgument(tc)
            tc.Stim.calibrate();
            tc.Stim.present(30, 'probe');
            m = containers.Map({'n'}, {0});
            tc.Stim.present(40, 'probe', 'WhileWaiting', @() bump(m));
            tc.verifyEqual(string({tc.Stim.Log.kind}), ["probe" "probe"]);
            tc.verifyEqual([tc.Stim.Log.level], [30 40]);
        end
    end
end

function d = devicesDir()
    d = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'devices');
end

function bump(m)
m('n') = m('n') + 1; %#ok<NASGU> a handle: the caller's map changes
end
