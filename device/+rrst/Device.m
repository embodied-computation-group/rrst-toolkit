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
    %     rrst:badSetting         applyMotion given an invalid speed/acceleration/mode
    %     rrst:settingFailed      firmware did not confirm a setting, or 's' disagrees
    %     rrst:moveFailed         firmware refused or aborted the move
    %     rrst:deviceFault        an unsolicited ERROR arrived before a command
    %     rrst:timeout            no complete reply within the timeout
    %   Every line sent and every reply received is kept in Transcript, so it can be
    %   saved with the session data.
    %
    %   Work while waiting: command and moveTo take 'WhileWaiting', fcn. fcn() is
    %   called on every poll iteration while the reply is incomplete (then the usual
    %   pause of PollInterval), e.g. to draw an animation frame while the wedge
    %   moves:
    %     mv = dev.moveTo(steps, 'WhileWaiting', @() drawNextFrame());
    %     mv = dev.moveTo(steps, timeoutS, 'WhileWaiting', fcn);
    %   It changes nothing else: the firmware's reply is still read and checked, and
    %   the timeout still applies. fcn takes no input, must return quickly (a frame,
    %   not a wait) and must not error: an error propagates and leaves the move's
    %   reply unread (the next command logs it as unsolicited). To stop on a key,
    %   let fcn note it and act after the move is confirmed.
    %     rrst:badArgument        WhileWaiting is not a function handle, or an unknown option

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
                % The firmware leaves the driver energised after a failed 'c'.
                try
                    obj.disable();
                catch
                end
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
            % Before Precise-Piston (Msnejbjerg/RRST 7dc58a0), 'c' energises the driver
            % but does not set the firmware's enabled flag, and driver-fault monitoring
            % only runs while that flag is set. Harmless on later firmware.
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

        function st = applyMotion(obj, motion, st)
            %APPLYMOTION Set speed, acceleration and chopper mode, and check them with 's'.
            %   motion has fields speed, acceleration (steps/s, steps/s^2, positive integers)
            %   and chopperMode ("SpreadCycle" or "StealthChop"). Only values that differ
            %   from the device's are sent ('f', 'g', 't'). Settings stay in RAM: 'v'
            %   (save to EEPROM) is never sent. Returns the status read afterwards.
            %   st (optional): a status just read, to save one 's'.
            names = ["speed" "acceleration" "chopperMode"];
            if ~isstruct(motion) || ~all(isfield(motion, names))
                error('rrst:badSetting', 'motion needs the fields speed, acceleration and chopperMode.');
            end
            for name = ["speed" "acceleration"]
                v = motion.(name);
                if ~(isnumeric(v) && isscalar(v) && isfinite(v) && v == round(v) && v > 0)
                    error('rrst:badSetting', '%s must be a positive integer; got %s.', name, mat2str(v));
                end
            end
            if ~any(string(motion.chopperMode) == ["SpreadCycle" "StealthChop"])
                error('rrst:badSetting', 'chopperMode must be "SpreadCycle" or "StealthChop"; got "%s".', ...
                    string(motion.chopperMode));
            end

            if nargin < 3
                st = obj.status();
            end
            changed = false;
            if st.speed ~= motion.speed
                obj.setValue("f", "Speed", motion.speed);
                changed = true;
            end
            if st.acceleration ~= motion.acceleration
                obj.setValue("g", "Acceleration", motion.acceleration);
                changed = true;
            end
            if st.chopperMode ~= string(motion.chopperMode)
                lines = obj.command("t", obj.DefaultTimeout);
                if any(contains(lines, "UART link is down"))
                    error('rrst:settingFailed', ['Chopper mode may not have reached the driver: ' ...
                        'the TMC2209 UART link is down. Reply: %s'], strjoin(lines, ' | '));
                end
                changed = true;
            end
            if changed
                st = obj.status();
            end
            if st.speed ~= motion.speed || st.acceleration ~= motion.acceleration || ...
                    st.chopperMode ~= string(motion.chopperMode)
                error('rrst:settingFailed', ...
                    'Device reports %g steps/s, %g steps/s^2, %s; requested %d, %d, %s.', ...
                    st.speed, st.acceleration, st.chopperMode, ...
                    motion.speed, motion.acceleration, string(motion.chopperMode));
            end
        end

        function mv = moveTo(obj, steps, varargin)
            %MOVETO Move to an absolute step and check the firmware's confirmation.
            %   mv = dev.moveTo(steps)
            %   mv = dev.moveTo(steps, timeoutS)
            %   mv = dev.moveTo(___, 'WhileWaiting', fcn)   fcn() on every poll
            [timeoutS, waitFcn] = obj.options(obj.MoveTimeout, varargin);
            if ~obj.Calibrated
                error('rrst:notCalibrated', 'Calibrate the device before moving.');
            end
            if ~(isnumeric(steps) && isscalar(steps) && isfinite(steps) && steps == round(steps) ...
                    && steps >= 0 && steps <= obj.MaxPosition)
                error('rrst:outOfRange', 'Target must be an integer in [0, %d]; got %s.', ...
                    obj.MaxPosition, mat2str(steps));
            end
            t0 = tic;
            lines = obj.command(["a"; string(sprintf('%d', steps))], timeoutS, 'WhileWaiting', waitFcn);
            mv = rrst.parseMoveReply(lines);
            mv.requested = steps;
            mv.elapsed = toc(t0);
            if mv.ok && mv.target ~= steps
                mv.ok = false;
                mv.errorText = sprintf('Firmware confirmed target %g, but %d was requested.', mv.target, steps);
            end
            if ~mv.ok
                msg = sprintf('Move to %d failed: %s', steps, mv.errorText);
                if contains(mv.errorText, "stepper disabled")
                    obj.Enabled = false;
                end
                if any(contains(lines, "Serial connection lost"))
                    % The firmware disables the driver and invalidates calibration.
                    obj.Enabled = false;
                    obj.Calibrated = false;
                    obj.MaxPosition = NaN;
                    obj.FirstContact = NaN;
                    msg = [msg, ' The firmware reported the serial link as closed (DTR not asserted?).'];
                end
                error('rrst:moveFailed', '%s', msg);
            end
        end

        function lines = command(obj, cmds, varargin)
            %COMMAND Send one or more lines and return the parsed reply up to the prompt.
            %   lines = dev.command(cmds)                    DefaultTimeout
            %   lines = dev.command(cmds, timeoutS)
            %   lines = dev.command(___, 'WhileWaiting', fcn)   fcn() on every poll
            [timeoutS, waitFcn] = obj.options(obj.DefaultTimeout, varargin);
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
                    if complete && isempty(lines)
                        % A bare prompt is never a reply (every command produces
                        % text): it is the extra prompt the firmware sends after a
                        % move, arriving late. Log it and keep reading.
                        obj.log("unsolicited", buf);
                        buf = '';
                    elseif complete
                        obj.log("rx", buf);
                        return
                    end
                end
                if toc(t0) > timeoutS
                    obj.log("rx", buf);
                    error('rrst:timeout', 'No complete reply to "%s" within %g s. Partial reply: %s', ...
                        strjoin(string(cmds), '","'), timeoutS, strjoin(rrst.splitReply(buf), ' | '));
                end
                if ~isempty(waitFcn)
                    waitFcn();
                end
                pause(obj.PollInterval);
            end
        end
    end

    methods (Access = private)
        function [timeoutS, waitFcn] = options(~, defaultTimeout, args)
            % Optional timeout (a number first), then name-value 'WhileWaiting', fcn.
            timeoutS = defaultTimeout;
            waitFcn = [];
            if ~isempty(args) && isnumeric(args{1})
                timeoutS = args{1};
                args = args(2:end);
            end
            if mod(numel(args), 2) ~= 0
                error('rrst:badArgument', 'Options come in name-value pairs (''WhileWaiting'', fcn).');
            end
            for k = 1:2:numel(args)
                name = args{k};
                if ~((ischar(name) && isrow(name)) || (isstring(name) && isscalar(name))) || ...
                        ~strcmpi(name, 'WhileWaiting')
                    error('rrst:badArgument', 'Unknown option; the only one is ''WhileWaiting''.');
                end
                f = args{k + 1};
                if ~(isempty(f) || isa(f, 'function_handle'))
                    error('rrst:badArgument', 'WhileWaiting must be a function handle (or empty).');
                end
                waitFcn = f;
            end
        end

        function setValue(obj, cmd, label, value)
            % 'f' and 'g' prompt for a value; the firmware confirms "<label> set to <value>".
            lines = obj.command([cmd; string(sprintf('%d', value))], obj.DefaultTimeout);
            if ~any(lines == sprintf('%s set to %d', label, value))
                error('rrst:settingFailed', '%s %d not confirmed. Reply: %s', ...
                    label, value, strjoin(lines, ' | '));
            end
        end

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
