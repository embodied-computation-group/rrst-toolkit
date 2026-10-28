classdef Device < handle
    %DEVICE Confirmed, logged control of an RRST Teensy 4.0 + TMC2209 device.
    %   dev = rrst.Device(port)
    %
    %   port is a serialport opened with rrst.openPort (real hardware) or an
    %   rrst.MockPort (tests). Every command waits for the firmware's "Valve>"
    %   prompt and checks the reply. Failures raise errors with these identifiers:
    %     rrst:notCalibrated      move requested before a successful calibrate()
    %     rrst:outOfRange         target is not an integer in [0, MaxPosition]
    %     rrst:calibrationFailed  'c' reply did not confirm both endstops
    %     rrst:enableFailed       'e' reply did not confirm
    %     rrst:moveFailed         firmware refused or aborted the move
    %     rrst:deviceFault        an unsolicited ERROR arrived before a command
    %     rrst:timeout            no complete reply within the timeout
    %   Every line sent and every reply received is kept in Transcript, so it can be
    %   saved with the session data.

    properties
        DefaultTimeout = 10        % s, for e/d/s
        CalibrationTimeout = 120   % s, two precise endstop seeks
        MoveTimeout = 30           % s
        PollInterval = 0.005       % s
    end

    properties (SetAccess = private)
        Port
        Transcript = struct('t', {}, 'direction', {}, 'text', {})
        MaxPosition = NaN
        FirstContact = NaN
        Calibrated = false
        Enabled = false
        LastCalibration = []
    end

    properties (Access = private)
        Clock
    end

    methods
        function obj = Device(port)
            obj.Port = port;
            obj.Clock = tic;
        end

        function st = status(obj)
            st = rrst.parseStatus(obj.command("s", obj.DefaultTimeout));
        end

        function cal = calibrate(obj, timeoutS)
            if nargin < 2, timeoutS = obj.CalibrationTimeout; end
            obj.Calibrated = false;
            obj.MaxPosition = NaN;
            obj.FirstContact = NaN;
            lines = obj.command("c", timeoutS);
            cal = rrst.parseCalibrationReply(lines);
            obj.LastCalibration = cal;
            if ~cal.ok
                msg = sprintf('Calibration failed: %s', cal.errorText);
                if any(contains(lines, "Serial connection lost"))
                    msg = [msg, ' The firmware reported the serial link as closed: the host may ' ...
                        'not be asserting DTR. Open the port with rrst.openPort, which calls setDTR.'];
                end
                error('rrst:calibrationFailed', '%s', msg);
            end
            obj.MaxPosition = cal.maxPosition;
            obj.FirstContact = cal.firstContact;
            obj.Calibrated = true;
        end

        function enable(obj)
            % 'c' energises the driver but does not set the firmware's enabled
            % flag, and driver-fault monitoring only runs while that flag is set.
            lines = obj.command("e", obj.DefaultTimeout);
            if ~any(startsWith(lines, "Stepper enabled"))
                error('rrst:enableFailed', 'Enable not confirmed. Reply: %s', strjoin(lines, ' | '));
            end
            obj.Enabled = true;
        end

        function disable(obj)
            % The firmware invalidates calibration on disable.
            obj.command("d", obj.DefaultTimeout);
            obj.Enabled = false;
            obj.Calibrated = false;
            obj.MaxPosition = NaN;
            obj.FirstContact = NaN;
        end

        function mv = moveTo(obj, steps, timeoutS)
            if nargin < 3, timeoutS = obj.MoveTimeout; end
            if ~obj.Calibrated
                error('rrst:notCalibrated', 'Calibrate the device before moving.');
            end
            if ~(isnumeric(steps) && isscalar(steps) && isfinite(steps) && steps == round(steps) ...
                    && steps >= 0 && steps <= obj.MaxPosition)
                error('rrst:outOfRange', 'Target must be an integer in [0, %d]; got %s.', ...
                    obj.MaxPosition, mat2str(steps));
            end
            t0 = tic;
            lines = obj.command(["a"; string(sprintf('%d', steps))], timeoutS);
            mv = rrst.parseMoveReply(lines);
            mv.requested = steps;
            mv.elapsed = toc(t0);
            if mv.ok && mv.target ~= steps
                mv.ok = false;
                mv.errorText = sprintf('Firmware confirmed target %g, but %d was requested.', mv.target, steps);
            end
            if ~mv.ok
                if contains(mv.errorText, "stepper disabled")
                    obj.Enabled = false;
                end
                error('rrst:moveFailed', 'Move to %d failed: %s', steps, mv.errorText);
            end
        end

        function lines = command(obj, cmds, timeoutS)
            %COMMAND Send one or more lines and return the parsed reply up to the prompt.
            obj.checkUnsolicited();
            for c = string(cmds(:))'
                writeline(obj.Port, c);
                obj.log("tx", c);
            end
            buf = '';
            t0 = tic;
            while true
                n = obj.Port.NumBytesAvailable;
                if n > 0
                    buf = [buf, read(obj.Port, n, 'char')]; %#ok<AGROW>
                    [lines, complete] = rrst.splitReply(buf);
                    if complete
                        obj.log("rx", buf);
                        return
                    end
                end
                if toc(t0) > timeoutS
                    obj.log("rx", buf);
                    error('rrst:timeout', 'No complete reply to "%s" within %g s. Partial reply: %s', ...
                        strjoin(string(cmds), '","'), timeoutS, strjoin(rrst.splitReply(buf), ' | '));
                end
                pause(obj.PollInterval);
            end
        end
    end

    methods (Access = private)
        function checkUnsolicited(obj)
            n = obj.Port.NumBytesAvailable;
            if n == 0
                return
            end
            text = read(obj.Port, n, 'char');
            obj.log("unsolicited", text);
            lines = rrst.splitReply(text);
            errs = lines(startsWith(lines, "ERROR", 'IgnoreCase', true));
            if ~isempty(errs)
                obj.Enabled = false;
                error('rrst:deviceFault', 'Device reported, unprompted: %s', strjoin(errs, ' | '));
            end
        end

        function log(obj, direction, text)
            obj.Transcript(end + 1) = struct('t', toc(obj.Clock), ...
                'direction', string(direction), 'text', string(text));
        end
    end
end
