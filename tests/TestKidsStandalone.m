classdef TestKidsStandalone < matlab.unittest.TestCase
    % RRST-Kids standalone recording (cfg.recording.mode = "standalone"): the task
    % runs without the Physio Recorder, starts flow_lsl.py itself when no "Flow"
    % stream is running, never waits for a recorder, and saves every flow sample and
    % marker it sees. No hardware, no Python is launched, no "RRST" stream is opened.
    % The flowInlet recording tests make their own uniquely named LSL outlet (as
    % TestFlowInlet) and are skipped where liblsl-Matlab is not installed.

    properties (Constant)
        LiblslDir = 'C:\toolbox\liblsl-Matlab'
        Fs = 1000
    end

    properties
        root
        lib
        name
        outlet
        seq = 0
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            tc.root = fileparts(fileparts(mfilename('fullpath')));
            p = [fullfile(tc.root, 'task', 'RRST_kids', {'config', 'code'}), ...
                {fullfile(tc.root, 'task', 'helpers'), ...                  % rrstMarker, flowInlet, flowStreamer
                fullfile(tc.root, 'task', 'RRST_2-0', 'code')}];           % uniqueFileName (kidsSave)
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
            tc.addTeardown(@() rrstMarker('close'));
        end
    end

    methods (TestMethodSetup)
        function freshMarkerLog(tc) %#ok<MANU>
            rrstMarker('close');
            rrstMarker('clearLog');
        end
    end

    methods (Test)
        % --- configuration ----------------------------------------------------
        function defaultIsPhysio(tc)
            cfg = kidsConfig();
            validateKidsConfig(cfg);
            tc.verifyEqual(cfg.recording.mode, "physio");
            tc.verifyFalse(kidsStandalone(cfg));
            tc.verifyTrue(kidsWaitsForRecorder(cfg), 'physio: a real session still waits');
        end

        function streamerDefaultsSitNextToTheToolkit(tc)
            cfg = kidsConfig();
            plux = fullfile(fileparts(tc.root), 'plux-lsl');
            tc.verifyEqual(string(cfg.flow.pluxDir), string(plux));
            tc.verifyEqual(string(cfg.flow.streamer), string(fullfile(plux, '.venv', 'Scripts', 'python.exe')));
            tc.verifyEqual(string(cfg.flow.streamerScript), string(fullfile(plux, 'flow_lsl.py')));
        end

        function standaloneIsValid(tc)
            cfg = kidsConfig();
            cfg.recording.mode = "standalone";
            validateKidsConfig(cfg);
            cfg.recording.mode = 'standalone';             % char is fine
            validateKidsConfig(cfg);
            tc.verifyTrue(kidsStandalone(cfg));
        end

        function unknownModeIsRejected(tc)
            for bad = {"Standalone", "lab", "", 3, ["physio" "standalone"], []}
                cfg = kidsConfig();
                cfg.recording.mode = bad{1};
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            end
        end

        function missingRecordingBlockIsRejected(tc)
            cfg = rmfield(kidsConfig(), 'recording');
            tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
        end

        function standaloneNeedsTheFlowSensor(tc)
            cfg = kidsConfig();
            cfg.recording.mode = "standalone";
            cfg.flow.enabled = false;
            cfg.flow.feedback = "none";
            try
                validateKidsConfig(cfg);
                tc.verifyFail('standalone without the flow sensor was accepted');
            catch err
                tc.verifyEqual(err.identifier, 'rrst:badConfig');
                tc.verifySubstring(err.message, 'flow.enabled');
            end
        end

        function standaloneStreamerPathsMustBeText(tc)
            for field = ["streamer" "streamerScript"]
                cfg = kidsConfig();
                cfg.recording.mode = "standalone";
                cfg.flow.(field) = 3;
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig');
            end
        end

        function physioDoesNotCheckTheStreamerFiles(tc)
            % The files are checked only when the task has to start the streamer.
            cfg = kidsConfig();
            cfg.flow.streamer = fullfile(tempdir, 'no', 'python.exe');
            validateKidsConfig(cfg);
            cfg.recording.mode = "standalone";
            validateKidsConfig(cfg);
        end

        function standaloneNeverWaitsForARecorder(tc)
            cfg = kidsConfig();                             % a real session, markers on
            cfg.recording.mode = "standalone";
            tc.verifyFalse(kidsWaitsForRecorder(cfg));
        end

        % --- marker log ------------------------------------------------------------
        function markerLogFillsWithoutAnOutlet(tc)
            % cfg.markers.lsl = false: nothing goes to LSL, every marker is still kept
            tc.useStubClock(100);
            cfg = kidsConfig();
            cfg.markers.lsl = false;
            cfg.markers.liblslDir = fullfile(tempdir, 'no_liblsl_here');
            closer = kidsOpenMarkers(cfg); %#ok<NASGU>
            rrstMarker('calibration_start');
            rrstMarker('question', 12.3);
            rrstMarker(kidsMarkerLabel("go", 4));
            tc.verifyFalse(rrstMarker('recorded'));
            log = rrstMarker('log');
            tc.verifyClass(log, 'table');
            tc.verifyEqual(log.Properties.VariableNames, {'t', 'label'});
            tc.verifyEqual(log.label, ["calibration_start"; "question"; "trial_4_go"]);
            tc.verifyEqual(log.t(2), 12.3);
            tc.verifyGreaterThan(log.t(1), 100, 'stamped with GetSecs when no time is given');
            tc.verifyGreaterThan(log.t(3), log.t(1));
        end

        function markerLogIsClearedAtTheStartOfASession(tc)
            tc.useStubClock(0);
            rrstMarker('left_over');
            cfg = kidsConfig();
            cfg.markers.lsl = false;
            closer = kidsOpenMarkers(cfg); %#ok<NASGU>
            tc.verifyEqual(height(rrstMarker('log')), 0);
            rrstMarker('done');
            tc.verifyEqual(rrstMarker('log').label, "done");
        end

        function emptyMarkerLogHasTheColumns(tc)
            log = rrstMarker('log');
            tc.verifyEqual(height(log), 0);
            tc.verifyEqual(log.Properties.VariableNames, {'t', 'label'});
        end

        function markerLogSurvivesClose(tc)
            % runKidsRRST closes the stream after kidsMain has saved: the log is read first,
            % but closing must not lose it either.
            tc.useStubClock(0);
            rrstMarker('aborted');
            rrstMarker('close');
            tc.verifyEqual(rrstMarker('log').label, "aborted");
        end

        % --- flowInlet recording -------------------------------------------------------
        function recordKeepsEveryPulledSampleInOrder(tc)
            src = tc.openWithOutlet();
            src.record = true;
            tc.push(linspace(0, 40, 200)');
            a = tc.pullAll(src, 200);
            tc.push(-linspace(1, 2, 150)');
            b = tc.pullAll(src, 150);
            r = src.recorded();
            tc.verifySize(r, [350 2]);
            tc.verifyEqual(r, [a; b]);
            tc.push(ones(30, 1));
            c = tc.pullAll(src, 30);
            tc.verifyEqual(src.recorded(), [a; b; c], 'recorded() grows with every pull');
        end

        function recordOffKeepsNothing(tc)
            src = tc.openWithOutlet();
            tc.verifyFalse(src.record);
            tc.push(zeros(100, 1));
            tc.pullAll(src, 100);
            tc.verifySize(src.recorded(), [0 2]);
        end

        function longBufferKeepsSamplesBetweenPulls(tc)
            % Standalone opens the inlet with a long buffer, so the time between slurp
            % phases (story, question, rests) is not dropped by the inlet.
            tc.makeOutlet();
            src = flowInlet(tc.LiblslDir, 5, Name=tc.name, BufferS=600);
            tc.addTeardown(@() delete(src));
            tc.waitForConsumer();
            src.record = true;
            tc.push(zeros(8000, 1));                     % 8 s, more than the default 5 s
            pause(1);                                    % all queued in the inlet before a pull
            tc.pullAll(src, 8000);
            tc.verifySize(src.recorded(), [8000 2]);
        end

        % --- simulated flow records too (mock and simulated-child runs) ----------------
        function simulatedFlowRecordsAndGrows(tc)
            src = kidsSimFlow();
            src.record = true;
            src.advance(1);
            a = src.pull();
            src.advance(700);                            % beyond the first allocation
            b = src.pull();
            tc.verifyEqual(src.recorded(), [a; b]);
            tc.verifySize(src.recorded(), [701000 2]);
        end

        function simulatedFlowRecordOffKeepsNothing(tc)
            src = kidsSimFlow();
            src.advance(1);
            src.pull();
            tc.verifySize(src.recorded(), [0 2]);
        end

        % --- flowStreamer (no Python is launched) -----------------------------------
        function streamerScriptStartsFlowLslHidden(tc)
            py = 'C:\Users\stim\Desktop\cannabodies\plux-lsl\.venv\Scripts\python.exe';
            sc = 'C:\Users\stim\Desktop\cannabodies\plux-lsl\flow_lsl.py';
            lg = 'C:\Temp\flow_lsl_x.log';
            ps = flowStreamer.startScript(py, sc, lg);
            tc.verifyEqual(ps, ['$p = Start-Process -FilePath ''' py ''' ' ...
                '-ArgumentList ''-u "' sc '"'' ' ...
                '-WorkingDirectory ''C:\Users\stim\Desktop\cannabodies\plux-lsl'' ' ...
                '-WindowStyle Hidden -PassThru ' ...
                '-RedirectStandardOutput ''C:\Temp\flow_lsl_x.log'' ' ...
                '-RedirectStandardError ''C:\Temp\flow_lsl_x.err.log''; $p.Id']);
            tc.verifyEmpty(strfind(ps, '--port'), 'the port is auto-detected');
        end

        function streamerScriptQuotesAwkwardPaths(tc)
            ps = flowStreamer.startScript('C:\Mi''s files\py.exe', 'C:\a b\flow_lsl.py', 'C:\l.log');
            tc.verifySubstring(ps, '-FilePath ''C:\Mi''''s files\py.exe''');
            tc.verifySubstring(ps, '-ArgumentList ''-u "C:\a b\flow_lsl.py"''');
            tc.verifySubstring(ps, '-WorkingDirectory ''C:\a b''');
        end

        function streamerCommandRunsTheScriptInPowerShell(tc)
            py = 'C:\p\python.exe'; sc = 'C:\p\flow_lsl.py'; lg = 'C:\l.log';
            cmd = flowStreamer.startCommand(py, sc, lg);
            prefix = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ';
            tc.assertTrue(startsWith(cmd, prefix), cmd);
            decoded = native2unicode(matlab.net.base64decode(cmd(numel(prefix) + 1:end)), 'UTF-16LE');
            tc.verifyEqual(decoded, flowStreamer.startScript(py, sc, lg));
        end

        function streamerStopKillsTheProcessTree(tc)
            tc.verifyEqual(flowStreamer.stopCommand(1234), 'taskkill /PID 1234 /T /F');
        end

        function streamerIsNotStartedByConstruction(tc)
            s = flowStreamer('C:\p\python.exe', 'C:\p\flow_lsl.py');
            tc.verifyFalse(s.started);
            tc.verifyEmpty(s.pid);
            s.stop();                                    % nothing to stop: no error
            tc.verifyFalse(s.started);
        end

        function missingPythonIsAClearError(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            sc = fullfile(d, 'flow_lsl.py');
            fclose(fopen(sc, 'w'));
            s = flowStreamer(fullfile(d, 'no_python.exe'), sc);
            try
                s.start();
                tc.verifyFail('started without python.exe');
            catch err
                tc.verifyEqual(err.identifier, 'rrst:noStreamer');
                tc.verifySubstring(err.message, 'no_python.exe');
                tc.verifySubstring(err.message, 'cfg.flow.streamer');
            end
            tc.verifyFalse(s.started);
        end

        function missingScriptIsAClearError(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            py = fullfile(d, 'python.exe');
            fclose(fopen(py, 'w'));
            s = flowStreamer(py, fullfile(d, 'flow_lsl.py'));
            try
                s.start();
                tc.verifyFail('started without flow_lsl.py');
            catch err
                tc.verifyEqual(err.identifier, 'rrst:noStreamer');
                tc.verifySubstring(err.message, 'flow_lsl.py');
                tc.verifySubstring(err.message, 'cfg.flow.streamerScript');
            end
        end

        % --- saving ---------------------------------------------------------------------
        function saveWritesFlowAndMarkers(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            [cfg, vars, stim, result] = tc.saveInputs(d);
            t = 5000 + (0:2999)' / 1000;
            result.flow = [t, 20 * sin(t)];
            result.markers = table([5000.1; 5001.25], ["calibration_start"; "done"], ...
                'VariableNames', {'t', 'label'});
            file = kidsSave(cfg, vars, stim, result);
            s = load(file);
            tc.verifyEqual(s.result.flow, result.flow);
            tc.verifyEqual(s.result.markers, result.markers);
            csv = strrep(file, '.mat', '_flow.csv');
            tc.assertTrue(isfile(csv), 'no _flow.csv next to the .mat');
            lines = readlines(csv, 'EmptyLineRule', 'skip');
            tc.verifyEqual(lines(1), "t,flow");
            f = readmatrix(csv);
            tc.verifySize(f, [3000 2]);
            tc.verifyEqual(f, result.flow, 'AbsTol', 1e-4);
        end

        function saveWithoutFlowWritesNoFlowFile(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            [cfg, vars, stim, result] = tc.saveInputs(d);
            file = kidsSave(cfg, vars, stim, result);
            tc.verifyFalse(isfile(strrep(file, '.mat', '_flow.csv')));
        end

        function emptyFlowStillWritesTheHeader(tc)
            d = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            [cfg, vars, stim, result] = tc.saveInputs(d);
            result.flow = zeros(0, 2);
            result.markers = rrstMarker('log');
            file = kidsSave(cfg, vars, stim, result);
            lines = readlines(strrep(file, '.mat', '_flow.csv'), 'EmptyLineRule', 'skip');
            tc.verifyEqual(lines, "t,flow");
        end
    end

    methods
        function useStubClock(tc, t)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(here, 'ptbstubs')));
            global PTBSTUB %#ok<GVMIS>
            PTBSTUB.t = t;
        end

        function [cfg, vars, stim, result] = saveInputs(~, d)
            cfg = kidsConfig(); cfg.output.dir = d; cfg.device.mock = false;
            cfg.debug.simulateChild = [];
            cfg.recording.mode = "standalone";
            vars = struct('subNo', 7);
            stim = struct('summary', @() struct('deviceId', "TEST"));   % stands in for rrst.Stimulator
            result = struct('outcome', "aborted", 'trials', [], 'practice', [], 'flags', [], 'kp', []);
        end

        % LSL helpers, as TestFlowInlet
        function makeOutlet(tc)
            tc.assumeTrue(isfolder(tc.LiblslDir), 'liblsl-Matlab is not installed.');
            addpath(tc.LiblslDir, fullfile(tc.LiblslDir, 'bin'));
            tc.lib = lsl_loadlib();
            tc.name = sprintf('FlowRecTest_%s', dec2hex(randi(2^31), 8));
            tc.seq = 0;
            info = lsl_streaminfo(tc.lib, tc.name, 'Airflow', 3, tc.Fs, 'cf_double64', tc.name);
            tc.outlet = lsl_outlet(info);
            tc.addTeardown(@() tc.dropOutlet());
        end

        function dropOutlet(tc)
            tc.outlet = [];
        end

        function src = openWithOutlet(tc)
            tc.makeOutlet();
            src = flowInlet(tc.LiblslDir, 5, Name=tc.name);
            tc.addTeardown(@() delete(src));
            tc.waitForConsumer();
        end

        function waitForConsumer(tc)
            t = tic;
            while ~tc.outlet.have_consumers() && toc(t) < 5
                pause(0.01);
            end
            tc.assertTrue(logical(tc.outlet.have_consumers()), 'the inlet never connected');
        end

        function push(tc, flow)
            n = numel(flow);
            seqs = tc.seq + (0:n - 1);
            tc.seq = tc.seq + n;
            ts = lsl_local_clock(tc.lib) - (n - 1:-1:0) / tc.Fs;
            tc.outlet.push_chunk([seqs; flow(:)'; 25 * ones(1, n)], ts);
        end

        function s = pullAll(~, src, n)
            s = zeros(0, 2);
            t = tic;
            while size(s, 1) < n && toc(t) < 5
                s = [s; src.pull()]; %#ok<AGROW>
                pause(0.01);
            end
        end
    end
end
