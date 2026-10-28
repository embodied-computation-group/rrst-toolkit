classdef MockPort < handle
    %MOCKPORT Simulated RRST firmware behind a serialport-like interface.
    %   port = rrst.MockPort('MaxPosition', 45123, ...)
    %
    %   Implements the parts of MATLAB's serialport that rrst.Device uses:
    %   writeline, read(port, n, 'char'), NumBytesAvailable, flush, setDTR,
    %   configureTerminator. Each reply is written byte for byte from the format
    %   strings in RRST_Teensy_4_version_TMC2209.ino (Msnejbjerg/RRST c298eed),
    %   including its mixed CRLF/LF line endings and the trailing "Valve>" prompt.
    %   Replies are available as soon as the command is written: there is no motion
    %   time.
    %
    %   Fault injection (set the Fault property):
    %     "calibrateMinMissing"  'c' fails: min endstop not found
    %     "moveWarning"          'a' succeeds after one auto-corrected endstop hit
    %     "moveSafetyDisable"    'a' fails: three unexpected hits, driver disabled
    %     "silent"               no reply to anything (tests timeouts)
    %   DtrAsserted = false simulates a host that never asserts DTR. On real
    %   firmware, CheckSerialConnection() then aborts the endstop seek. The reply
    %   text for that case is inferred from the source, not captured from hardware.

    properties
        MaxPosition = 45000
        SavedMaxPosition = -1          % -1: nothing saved in EEPROM yet
        Position = 20000
        Calibrated = false
        Enabled = false                % firmware StepperStatus flag
        DtrAsserted = true
        RetractSteps = 24000
        RetractMm = 15
        Speed = 16000
        Acceleration = 10000
        DeviceId = "0123456789ABCDEF"
        SoftwareVersion = "Patient-Regulator (Oct  7 2026 08:45:06)"
        Fault = ""
        Timeout = 10
    end

    properties (SetAccess = private)
        Written = strings(0, 1)        % every line written by the host, in order
    end

    properties (Dependent)
        NumBytesAvailable
    end

    properties (Access = private)
        OutBuffer = ''
        AwaitingMoveTarget = false
    end

    properties (Constant, Access = private)
        PROMPT = sprintf('\r\nValve>')
    end

    methods
        function obj = MockPort(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k + 1};
            end
        end

        function n = get.NumBytesAvailable(obj)
            n = numel(obj.OutBuffer);
        end

        function writeline(obj, txt)
            txt = string(txt);
            obj.Written(end + 1, 1) = txt;
            if obj.Fault == "silent"
                return
            end
            if obj.AwaitingMoveTarget
                obj.AwaitingMoveTarget = false;
                obj.finishMove(str2double(txt));
                return
            end
            switch char(txt)
                case 'c', obj.calibrate();
                case 'e', obj.enable();
                case 'd', obj.disable();
                case 's', obj.status();
                case 'a'
                    obj.emit(sprintf('\nEnter absolute target position (steps):\r\n'));
                    obj.AwaitingMoveTarget = true;
            end
        end

        function data = read(obj, n, ~)
            n = min(n, numel(obj.OutBuffer));
            data = obj.OutBuffer(1:n);
            obj.OutBuffer = obj.OutBuffer(n + 1:end);
        end

        function flush(obj, varargin)
            obj.OutBuffer = '';
        end

        function setDTR(obj, tf)
            obj.DtrAsserted = logical(tf);
        end

        function configureTerminator(~, varargin)
        end

        function queueUnsolicited(obj, text)
            % Output the firmware sends on its own, e.g. a driver-fault message.
            obj.emit(text);
        end
    end

    methods (Access = private)
        function emit(obj, text)
            obj.OutBuffer = [obj.OutBuffer, char(text)];
        end

        function calibrate(obj)
            obj.Calibrated = false;
            out = sprintf('\nStarting calibration...\r\n');
            if ~obj.DtrAsserted
                out = [out, sprintf(['\nSerial connection lost - stepper disabled. Reconnect and use ''e'' ' ...
                    'to re-enable (recalibrate ''c'' before moving).\r\n']), ...
                    sprintf('ERROR: Min endstop not found - calibration aborted.\r\n')];
                obj.Enabled = false;
            elseif obj.Fault == "calibrateMinMissing"
                out = [out, sprintf('ERROR: Min endstop not found - calibration aborted.\r\n')];
            else
                out = [out, sprintf('Min Endstop found. Position set to 0.\r\n'), ...
                    sprintf('Max Endstop found. Max Position: %d', obj.MaxPosition)];
                if obj.SavedMaxPosition >= 0
                    out = [out, sprintf(' (previous saved: %d, diff: %+d)', ...
                        obj.SavedMaxPosition, obj.MaxPosition - obj.SavedMaxPosition)];
                else
                    out = [out, ' (no previous saved value to compare)'];
                end
                out = [out, sprintf('\r\n'), ...
                    sprintf('First-contact position (retract %.3f mm): %d\n', ...
                        obj.RetractMm, obj.MaxPosition - obj.RetractSteps), ...
                    sprintf('\r\n')];
                obj.SavedMaxPosition = obj.MaxPosition;
                obj.Position = obj.MaxPosition;
                obj.Calibrated = true;
            end
            obj.emit([out, obj.PROMPT]);
        end

        function enable(obj)
            obj.Enabled = true;
            obj.emit([sprintf('\nStepper enabled in normal mode\n\r\n'), obj.PROMPT]);
        end

        function disable(obj)
            obj.Enabled = false;
            obj.Calibrated = false;
            obj.emit([sprintf(['\nStepper disabled. Position tracking is no longer trustworthy - ' ...
                'recalibrate (''c'') before moving.\n\r\n']), obj.PROMPT]);
        end

        function finishMove(obj, target)
            warnLine = sprintf(['WARNING: Unexpected MAX endstop hit! Position auto-corrected ' ...
                'to %d.\n'], obj.MaxPosition);
            resume = sprintf('Resuming toward original target...\r\n');
            if ~obj.Calibrated
                out = sprintf('Error: Must calibrate (''c'') before moving.\r\n');
            elseif ~(target >= 0 && target <= obj.MaxPosition)
                out = sprintf('Error: Target out of calibrated bounds!\r\n');
            else
                out = sprintf('Moving to absolute position: %d\n', target);
                if ~obj.DtrAsserted
                    % MoveAbsWithEndstopGuard returns early when CheckSerialConnection fails.
                    out = [out, sprintf(['\nSerial connection lost - stepper disabled. Reconnect and use ''e'' ' ...
                        'to re-enable (recalibrate ''c'' before moving).\r\n'])];
                    obj.Enabled = false;
                    obj.Calibrated = false;
                    obj.emit([out, obj.PROMPT]);
                    return
                end
                switch obj.Fault
                    case "moveWarning"
                        out = [out, warnLine, resume, sprintf('Move complete.\r\n')];
                        obj.Position = target;
                    case "moveSafetyDisable"
                        out = [out, warnLine, resume, warnLine, resume, warnLine, ...
                            sprintf(['ERROR: Repeated unexpected endstop hits - stepper disabled. ' ...
                                'Investigate before re-enabling (e).\r\n'])];
                        obj.Enabled = false;
                    otherwise
                        out = [out, sprintf('Move complete.\r\n')];
                        obj.Position = target;
                end
            end
            obj.emit([out, obj.PROMPT]);
        end

        function status(obj)
            yn = {'NO', 'YES'};
            out = [sprintf('\n--- SYSTEM STATUS ---\r\n'), ...
                sprintf('Software Version: %s\n', obj.SoftwareVersion), ...
                sprintf('Device ID:        %s\n', obj.DeviceId), ...
                sprintf('Stepper Enabled:  %s\n', yn{obj.Enabled + 1}), ...
                sprintf('Current Position: %d steps\n', obj.Position)];
            if obj.Calibrated
                out = [out, sprintf('Max Range Limit:  %d steps\n', obj.MaxPosition)];
            else
                out = [out, sprintf('Max Range Limit:  %d steps (stale - not calibrated)\n', obj.MaxPosition)];
            end
            out = [out, sprintf('Calibrated:       %s\n', yn{obj.Calibrated + 1}), ...
                sprintf('Retract Distance: %d steps (%.3f mm)\n', obj.RetractSteps, obj.RetractMm)];
            if obj.Calibrated
                out = [out, sprintf('First-Contact:    %d steps\n', obj.MaxPosition - obj.RetractSteps)];
            else
                out = [out, sprintf('First-Contact:    unavailable (not calibrated)\r\n')];
            end
            out = [out, sprintf('Current Speed:    %d steps/s\n', obj.Speed), ...
                sprintf('Acceleration:     %d steps/s%s\n', obj.Acceleration, char(178)), ...
                sprintf('---\r\n\r\n')];
            obj.emit([out, obj.PROMPT]);
        end
    end
end
