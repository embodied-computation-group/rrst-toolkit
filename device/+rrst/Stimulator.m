classdef Stimulator < handle
    %STIMULATOR Stimulus levels -> confirmed device moves, for the task.
    %   stim = rrst.Stimulator(dev, record, 'Unit', "percent", 'RestRange', [20 80])
    %   stim.calibrate();          % motion settings, 'c' + 'e', checked against the record
    %   stim.present(level);       % move to a stimulus level
    %   stim.null();               % level 0: wedge just touching the tube
    %   level = stim.rest();       % random level in RestRange (between trials)
    %   stim.park();               % wedge well open, at ParkStep
    %
    %   Levels are in Unit: "percent" (0-100 between the record's anchors) or "mm"
    %   (wedge travel past the zero anchor, StepsPerMm steps per mm). A level outside
    %   [0, ScaleMax] is an error, never clipped. Every move waits for the firmware's
    %   confirmation (rrst.Device.moveTo) and is logged with its duration.
    %
    %   Animating while the wedge moves: present, null, rest and park take
    %   'WhileWaiting', fcn, passed to rrst.Device.moveTo: fcn() runs on every poll
    %   iteration until the firmware confirms the move (draw a frame, note a key).
    %     stim.present(level, 'WhileWaiting', @() frame());
    %     stim.null('WhileWaiting', @() frame());
    %   The confirmation is still checked as without it; see rrst.Device.
    %
    %   'Motion', struct('speed', s, 'acceleration', a, 'chopperMode', m) makes every
    %   calibrate() set and check these first (rrst.Device.applyMotion), so a session
    %   never runs on whatever tuning the device loaded from EEPROM. Empty (default):
    %   the device's settings are left alone and only logged.
    %
    %   Errors: rrst:levelOutOfRange (configured levels outside the scale),
    %   rrst:calibrationMismatch (MaxPosition far from the record: tube in/out?),
    %   rrst:wrongDevice (record belongs to another device), plus rrst.Device errors.

    properties (SetAccess = private)
        Device
        Record
        Unit
        RestRange
        StepsPerMm = 1600              % TR8x2 leadscrew, 1.8 deg motor, 16 microsteps
        ParkStep = 1600                % 1 mm from the min endstop: wedge well open
        CalibrationTolerance = 300     % steps; the tube in/out difference is about 1150
        ScaleMax
        Motion = []
        DeviceStatus = []              % 's' read at the last calibration, after Motion
        ZeroStep = NaN
        FullStep = NaN
        Calibrations = struct('t', {}, 'maxPosition', {}, 'zeroStep', {}, 'fullStep', {})
        Log = struct('t', {}, 'kind', {}, 'level', {}, 'steps', {}, 'elapsed', {})
    end

    properties (Access = private)
        Clock
        Rng
    end

    methods
        function obj = Stimulator(device, record, varargin)
            p = inputParser;
            p.addParameter('Unit', "percent", @(u) any(string(u) == ["percent" "mm"]));
            p.addParameter('RestRange', [20 80], @(r) isnumeric(r) && numel(r) == 2 && r(1) <= r(2));
            p.addParameter('ParkStep', 1600);
            p.addParameter('CalibrationTolerance', 300);
            p.addParameter('StepsPerMm', 1600);
            p.addParameter('Seed', 'shuffle');
            p.addParameter('Motion', []);
            p.parse(varargin{:});
            obj.Device = device;
            obj.Record = record;
            obj.Unit = string(p.Results.Unit);
            obj.ParkStep = p.Results.ParkStep;
            obj.CalibrationTolerance = p.Results.CalibrationTolerance;
            obj.StepsPerMm = p.Results.StepsPerMm;
            obj.Motion = p.Results.Motion;
            a = record.anchors;
            if obj.Unit == "percent"
                obj.ScaleMax = 100;
            else
                obj.ScaleMax = (a.zeroOffset - a.fullOffset) / obj.StepsPerMm;
            end
            obj.RestRange = p.Results.RestRange(:)';
            obj.validateLevels(obj.RestRange);
            obj.Clock = tic;
            obj.Rng = RandStream('mt19937ar', 'Seed', p.Results.Seed);
        end

        function validateLevels(obj, levels)
            %VALIDATELEVELS Error unless every level is inside [0, ScaleMax].
            bad = levels(~(levels >= 0 & levels <= obj.ScaleMax));
            if ~isempty(bad)
                error('rrst:levelOutOfRange', ...
                    ['Levels outside this device''s scale [0, %g] %s: %s. ' ...
                     'Change the configuration; levels are never clipped.'], ...
                    obj.ScaleMax, obj.Unit, mat2str(bad(:)', 4));
            end
        end

        function cal = calibrate(obj)
            %CALIBRATE Motion settings, 'c' then 'e'; checks device ID and MaxPosition against the record.
            st = obj.Device.status();
            if st.deviceId ~= obj.Record.deviceId
                error('rrst:wrongDevice', 'Connected device is %s, but the record is for %s.', ...
                    st.deviceId, obj.Record.deviceId);
            end
            if ~isempty(obj.Motion)
                st = obj.Device.applyMotion(obj.Motion, st);
            end
            obj.DeviceStatus = rmfield(st, 'fields');
            obj.ZeroStep = NaN;
            obj.FullStep = NaN;
            cal = obj.Device.calibrate();
            obj.Device.enable();
            a = obj.Record.anchors;
            d = cal.maxPosition - a.maxPositionAtMeasurement;
            if abs(d) > obj.CalibrationTolerance
                error('rrst:calibrationMismatch', ...
                    ['MaxPosition %d is %+d steps from the %d measured with the anchors ' ...
                     '(tolerance %d). Calibrate in the same condition as the record ' ...
                     '(%s) and check the tube is seated.'], ...
                    cal.maxPosition, d, a.maxPositionAtMeasurement, obj.CalibrationTolerance, ...
                    a.calibrationCondition);
            end
            [obj.ZeroStep, obj.FullStep] = rrst.anchorsFromCalibration( ...
                cal.maxPosition, a.zeroOffset, a.fullOffset);
            obj.Calibrations(end + 1) = struct('t', toc(obj.Clock), ...
                'maxPosition', cal.maxPosition, 'zeroStep', obj.ZeroStep, 'fullStep', obj.FullStep);
        end

        function steps = levelToSteps(obj, level)
            if isnan(obj.ZeroStep)
                error('rrst:notCalibrated', 'Calibrate before converting levels to steps.');
            end
            steps = rrst.obstructionToSteps(level, obj.ScaleMax, obj.ZeroStep, obj.FullStep);
        end

        function mv = present(obj, level, varargin)
            %PRESENT Move to a stimulus level.
            %   mv = stim.present(level)
            %   mv = stim.present(level, kind)              kind for the log (default 'stim')
            %   mv = stim.present(___, 'WhileWaiting', fcn)   fcn() while the wedge moves
            kind = 'stim';
            if mod(numel(varargin), 2) == 1
                kind = varargin{1};
                varargin = varargin(2:end);
            end
            steps = obj.levelToSteps(level);
            mv = obj.Device.moveTo(steps, varargin{:});
            obj.addLog(kind, level, steps, mv.elapsed);
        end

        function mv = null(obj, varargin)
            %NULL Level 0 (wedge just touching the tube); takes 'WhileWaiting', fcn.
            mv = obj.present(0, 'null', varargin{:});
        end

        function [level, mv] = rest(obj, varargin)
            %REST A random level in RestRange; takes 'WhileWaiting', fcn.
            r = obj.RestRange;
            level = r(1) + (r(2) - r(1)) * rand(obj.Rng);
            mv = obj.present(level, 'rest', varargin{:});
        end

        function mv = park(obj, varargin)
            %PARK Wedge well open, at ParkStep; takes 'WhileWaiting', fcn.
            mv = obj.Device.moveTo(obj.ParkStep, varargin{:});
            obj.addLog('park', NaN, obj.ParkStep, mv.elapsed);
        end

        function s = summary(obj)
            %SUMMARY Everything needed to audit the session, for saving with the data.
            s = struct('deviceId', obj.Record.deviceId, 'record', obj.Record, ...
                'unit', obj.Unit, 'scaleMax', obj.ScaleMax, 'restRange', obj.RestRange, ...
                'parkStep', obj.ParkStep, 'motion', obj.Motion, ...
                'deviceStatus', obj.DeviceStatus, 'calibrations', obj.Calibrations, ...
                'moves', obj.Log, 'transcript', obj.Device.Transcript);
        end
    end

    methods (Access = private)
        function addLog(obj, kind, level, steps, elapsed)
            obj.Log(end + 1) = struct('t', toc(obj.Clock), 'kind', kind, 'level', level, ...
                'steps', steps, 'elapsed', elapsed);
        end
    end
end
