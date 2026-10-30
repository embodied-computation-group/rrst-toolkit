classdef flowStreamer < handle
%FLOWSTREAMER Start plux-lsl/flow_lsl.py (the SFM3019 "Flow" LSL stream) from MATLAB, hidden.
%   s = flowStreamer(python, script)   python: plux-lsl\.venv\Scripts\python.exe,
%                                      script: plux-lsl\flow_lsl.py. Nothing starts yet.
%   s = flowStreamer(..., LogFile=f)   the streamer's output goes to f (and its errors
%                                      to f with .err before the extension); default
%                                      tempdir\flow_lsl_<date>_<time>.log
%   s.start()        launch it in the background with no window (Windows PowerShell
%                    Start-Process -WindowStyle Hidden -PassThru, through system), in
%                    the script's folder so its lsl_quiet import works; the SensorBridge
%                    port is auto-detected. Sets s.pid and s.started. Errors
%                    rrst:noStreamer (a file is missing) or rrst:streamerFailed.
%   s.stop()         end it and its child processes (taskkill /PID <pid> /T /F); only
%                    if this object started it. Also when s is deleted.
%   txt = s.lastLog(n)   the last n lines (default 5) of its output and errors: why a
%                    stream never appeared ("SensorBridge not found", "COM10 is in use").
%
%   cmd = flowStreamer.startCommand(python, script, logFile)   the system() line
%   ps  = flowStreamer.startScript(python, script, logFile)    the PowerShell inside it
%   cmd = flowStreamer.stopCommand(pid)
%
%   The venv's python.exe is a launcher that runs the real interpreter as its child,
%   hence /T. A streamer that was already running (started by hand or by the Physio
%   Recorder) is not this object's: use flowStreamer only when no "Flow" stream is
%   found (runKidsRRST, standalone recording), so it never stops someone else's.

    properties (SetAccess = private)
        python string
        script string
        logFile string
        pid double = []              % process ID of the launched python.exe
        started logical = false      % true from start() until stop()
    end

    methods
        function s = flowStreamer(python, script, opts)
            arguments
                python {mustBeTextScalar}
                script {mustBeTextScalar}
                opts.LogFile {mustBeTextScalar} = fullfile(tempdir, ...
                    "flow_lsl_" + string(datestr(now, 'yyyymmdd_HHMMSS')) + ".log") %#ok<TNOW1,DATST>
            end
            s.python = string(python);
            s.script = string(script);
            s.logFile = string(opts.LogFile);
        end

        function start(s)
            if s.started
                return
            end
            if ~ispc
                error('rrst:streamerFailed', ['Starting flow_lsl.py from MATLAB works on Windows ' ...
                    'only. Start it by hand (plux-lsl README).']);
            end
            if ~isfile(s.python)
                error('rrst:noStreamer', ['Python for the airflow streamer not found: %s\n' ...
                    'Set up plux-lsl next to this toolkit (its .venv, see its README), or set ' ...
                    'cfg.flow.streamer to that python.exe.'], s.python);
            end
            if ~isfile(s.script)
                error('rrst:noStreamer', ['The airflow streamer flow_lsl.py was not found: %s\n' ...
                    'Set up plux-lsl next to this toolkit, or set cfg.flow.streamerScript ' ...
                    'to its flow_lsl.py.'], s.script);
            end
            [status, out] = system(flowStreamer.startCommand(s.python, s.script, s.logFile));
            % The PID is the one line of digits: system() also returns PowerShell's
            % stderr, which can hold CLIXML progress records ("Preparing modules for
            % first use") on the first run after a login.
            tok = regexp(out, '^\s*(\d+)\s*$', 'tokens', 'once', 'lineanchors');
            if status ~= 0 || isempty(tok)
                error('rrst:streamerFailed', 'Could not start flow_lsl.py:\n%s', strtrim(out));
            end
            s.pid = str2double(tok{1});
            s.started = true;
            fprintf('Started the airflow streamer flow_lsl.py (hidden, PID %d). Log: %s\n', ...
                s.pid, s.logFile);
        end

        function stop(s)
            if ~s.started
                return
            end
            [status, out] = system(flowStreamer.stopCommand(s.pid));
            s.started = false;
            if status == 0
                fprintf('Stopped the airflow streamer (PID %d).\n', s.pid);
            else                                    % already gone (it exits on its own on errors)
                fprintf('Airflow streamer (PID %d) had already stopped: %s\n', s.pid, strtrim(out));
            end
        end

        function txt = lastLog(s, n)
            if nargin < 2
                n = 5;
            end
            lines = strings(0, 1);
            for f = [s.logFile, flowStreamer.errFile(s.logFile)]
                if isfile(f)
                    lines = [lines; readlines(f, 'EmptyLineRule', 'skip')]; %#ok<AGROW>
                end
            end
            lines = strtrim(lines);
            lines = lines(lines ~= "");
            txt = strjoin(lines(max(1, end - n + 1):end), newline);
        end

        function delete(s)
            s.stop();
        end
    end

    methods (Static)
        function ps = startScript(python, script, logFile)
            q = @(x) ['''' strrep(char(x), '''', '''''') ''''];   % PowerShell single quotes
            ps = ['$p = Start-Process -FilePath ' q(python) ...
                ' -ArgumentList ' q(['-u "' char(script) '"']) ...
                ' -WorkingDirectory ' q(fileparts(char(script))) ...
                ' -WindowStyle Hidden -PassThru' ...
                ' -RedirectStandardOutput ' q(logFile) ...
                ' -RedirectStandardError ' q(flowStreamer.errFile(logFile)) '; $p.Id'];
        end

        function cmd = startCommand(python, script, logFile)
            % -EncodedCommand (base64 of UTF-16LE) keeps cmd.exe's quoting out of the way.
            ps = flowStreamer.startScript(python, script, logFile);
            cmd = ['powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass ' ...
                '-EncodedCommand ' matlab.net.base64encode(unicode2native(ps, 'UTF-16LE'))];
        end

        function cmd = stopCommand(pid)
            cmd = sprintf('taskkill /PID %d /T /F', pid);
        end
    end

    methods (Static, Access = private)
        function f = errFile(logFile)
            [d, n, e] = fileparts(char(logFile));
            f = string(fullfile(d, [n '.err' e]));
        end
    end
end
