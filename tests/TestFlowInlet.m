classdef TestFlowInlet < matlab.unittest.TestCase
    % flowInlet, the shared reader of the "Flow" airflow stream. Each test makes its
    % own LSL outlet with a unique name and pushes synthetic samples, so the tests
    % need no sensor and do not see a real "Flow" stream that may be running.
    % Skipped where liblsl-Matlab is not installed.

    properties (Constant)
        LiblslDir = 'C:\toolbox\liblsl-Matlab'
        Fs = 1000
    end

    properties
        lib
        name
        outlet
        seq = 0
    end

    methods (TestClassSetup)
        function addPaths(tc)
            tc.assumeTrue(isfolder(tc.LiblslDir), 'liblsl-Matlab is not installed.');
            root = fileparts(fileparts(mfilename('fullpath')));
            helpers = fullfile(root, 'task', 'helpers');
            addpath(helpers);
            tc.addTeardown(@() rmpath(helpers));
            % liblsl stays on the path, as flowInlet leaves it: the library handle is
            % freed when its last copy goes, which can be after the class teardown.
            addpath(tc.LiblslDir, fullfile(tc.LiblslDir, 'bin'));
            tc.lib = lsl_loadlib();
        end
    end

    methods (TestMethodSetup)
        function uniqueName(tc)
            tc.name = sprintf('FlowTest_%s', dec2hex(randi(2^31), 8));
            tc.seq = 0;
            tc.addTeardown(@() tc.dropOutlet());
        end
    end

    methods (Test)
        % --- opening ----------------------------------------------------------
        function noStreamIsAnErrorWithinTheTimeout(tc)
            % liblsl 1.18's resolve overran a timeout of 0.495 to 0.5 s by about 5 s on
            % the stim laptop (2026-10-30, every call; 0.49 and 0.505 s were on time):
            % the timeouts next to 0.5 s are the ones that must be checked.
            for timeoutS = [0.2 0.495 0.5]
                t = tic;
                try
                    flowInlet(tc.LiblslDir, timeoutS, Name=tc.name);
                    tc.verifyFail(sprintf('no error without a stream (timeout %g s)', timeoutS));
                catch err
                    tc.verifyEqual(err.identifier, 'rrst:noFlowStream');
                    tc.verifySubstring(err.message, 'No airflow stream');
                end
                tc.verifyLessThan(toc(t), timeoutS + 1, sprintf('timeout %g s', timeoutS));
            end
        end

        function noStreamMessageNamesTheFix(tc)
            try
                flowInlet(tc.LiblslDir, 0.2, Name=tc.name);
                tc.verifyFail('no error without a stream');
            catch err
                tc.verifySubstring(err.message, 'No airflow stream');
                tc.verifySubstring(err.message, 'flow_lsl.py');
                tc.verifySubstring(err.message, 'cfg.flow.enabled = false');
            end
        end

        function missingLiblslIsAnError(tc)
            tc.verifyError(@() flowInlet('C:\no\such\liblsl', 0.2), 'rrst:noLiblsl');
        end

        % --- pull ---------------------------------------------------------------
        function pullReturnsTimeAndFlow(tc)
            src = tc.openWithOutlet();
            src.staleAfter = 30;                 % the first verify of a session can take ~1 s
            flow = linspace(0, 40, 200)';
            tc.push(flow);
            s = tc.pullAll(src, 200);
            if src.clockBase == "GetSecs"
                now = GetSecs;
            else
                now = lsl_local_clock(tc.lib);
            end
            tc.verifySize(s, [200 2]);
            tc.verifyEqual(s(:, 2), flow);
            tc.verifyTrue(all(diff(s(:, 1)) > 0), 'timestamps must increase');
            tc.verifyTrue(ismember(src.clockBase, ["GetSecs" "lsl"]));
            tc.verifyLessThan(abs(s(end, 1) - now), 0.5, 'timestamps are on the wrong clock');
            tc.verifySize(src.pull(), [0 2]);
            tc.verifyFalse(src.lost);
        end

        function pullCountsSamplesAndGaps(tc)
            src = tc.openWithOutlet();
            tc.push(zeros(100, 1));
            tc.seq = tc.seq + 5;                 % five samples lost at the bridge
            tc.push(zeros(100, 1));
            tc.pullAll(src, 200);
            tc.verifyEqual(src.nSamples, 200);
            tc.verifyEqual(src.nGaps, 1);
            tc.verifyEqual(src.nDropped, 5);
        end

        % --- loss and reconnection ----------------------------------------------
        function silentStreamIsLostAfterStaleAfter(tc)
            src = tc.openWithOutlet();
            src.staleAfter = 0.3;
            tc.push(zeros(50, 1));
            tc.pullAll(src, 50);
            tc.verifyFalse(src.lost);
            tc.dropOutlet();
            t = tic;
            while toc(t) < 0.6
                src.pull();
                pause(0.02);
            end
            tc.verifyTrue(src.lost);
        end

        function reconnectFindsTheStreamAgain(tc)
            src = tc.openWithOutlet();
            src.staleAfter = 0.2;
            tc.dropOutlet();
            t = tic;
            while toc(t) < 0.4
                src.pull();
                pause(0.02);
            end
            tc.verifyTrue(src.lost);
            tc.verifyFalse(src.reconnect(0.3));
            tc.verifyTrue(src.lost);
            tc.makeOutlet();
            tc.verifyTrue(src.reconnect(3));
            tc.verifyFalse(src.lost);
            tc.waitForConsumer();
            tc.push(ones(20, 1));
            tc.verifySize(tc.pullAll(src, 20), [20 2]);
        end

        function reconnectReturnsWithinItsTimeout(tc)
            % kidsMain looks for a lost stream with reconnect(0.5) before every trial.
            src = tc.openWithOutlet();
            tc.dropOutlet();
            for timeoutS = [0.495 0.5]
                t = tic;
                tc.verifyFalse(src.reconnect(timeoutS));
                tc.verifyLessThan(toc(t), timeoutS + 1, sprintf('timeout %g s', timeoutS));
            end
        end

        function closeReleasesTheInlet(tc)
            src = tc.openWithOutlet();
            src.close();
            tc.verifySize(src.pull(), [0 2]);
            t = tic;
            while tc.outlet.have_consumers() && toc(t) < 3
                pause(0.05);
            end
            tc.verifyFalse(logical(tc.outlet.have_consumers()));
        end

        % --- quality check (rules of plux-lsl/flow_quality.py) -----------------
        function checkAtRestIsOk(tc)
            src = tc.openWithOutlet();
            tc.push(0.05 * randn(2000, 1));
            [ok, msg] = src.check(0.3);
            tc.verifyTrue(ok, msg);
            tc.verifyTrue(startsWith(msg, "Airflow sensor OK: "), msg);
            tc.verifySubstring(char(msg), 'slm at rest');
        end

        function checkFrozenSensor(tc)
            src = tc.openWithOutlet();
            tc.push(0.12 * ones(2000, 1));
            [ok, msg] = src.check(0.3);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'FROZEN');
        end

        function checkReversedSensor(tc)
            src = tc.openWithOutlet();
            x = 0.05 * randn(2000, 1);
            x(501:1500) = -8 + 0.1 * randn(1000, 1);   % whole breaths read negative
            tc.push(x);
            [ok, msg] = src.check(0.3);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'REVERSE FLOW');
        end

        function backflowAfterABreathIsNotReverse(tc)
            src = tc.openWithOutlet();
            x = 0.05 * randn(2000, 1);
            x(201:700) = 30 * sin(pi * (1:500)' / 500);  % one inhalation
            x(701:1700) = -1.5 + 0.1 * randn(1000, 1);    % T-valve backflow, -1.5 slm
            tc.push(x);
            [ok, msg] = src.check(0.3);
            tc.verifyTrue(ok, msg);
        end

        function checkOutOfRange(tc)
            src = tc.openWithOutlet();
            tc.push(239.5 + 0.1 * rand(2000, 1));
            [ok, msg] = src.check(0.3);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'OUT OF RANGE');
        end

        function checkConstantFlow(tc)
            src = tc.openWithOutlet();
            tc.push(10 + 0.2 * randn(2000, 1));
            [ok, msg] = src.check(0.3);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'CONSTANT FLOW');
        end

        function checkWithoutSamples(tc)
            src = tc.openWithOutlet();
            [ok, msg] = src.check(0.3);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'No airflow samples');
        end
    end

    methods
        function makeOutlet(tc)
            info = lsl_streaminfo(tc.lib, tc.name, 'Airflow', 3, tc.Fs, 'cf_double64', tc.name);
            tc.outlet = lsl_outlet(info);
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
            % (lsl_outlet.wait_for_consumers calls its mex with the wrong arguments)
            t = tic;
            while ~tc.outlet.have_consumers() && toc(t) < 5
                pause(0.01);
            end
            tc.assertTrue(logical(tc.outlet.have_consumers()), 'the inlet never connected');
        end

        function push(tc, flow)
            % Push flow (slm) as [nSeq flow temp] at Fs, the newest sample stamped now.
            n = numel(flow);
            seqs = tc.seq + (0:n - 1);
            tc.seq = tc.seq + n;
            ts = lsl_local_clock(tc.lib) - (n - 1:-1:0) / tc.Fs;
            tc.outlet.push_chunk([seqs; flow(:)'; 25 * ones(1, n)], ts);
        end

        function s = pullAll(~, src, n)
            % Pull until n samples have arrived (LSL delivers asynchronously).
            s = zeros(0, 2);
            t = tic;
            while size(s, 1) < n && toc(t) < 3
                s = [s; src.pull()]; %#ok<AGROW>
                pause(0.01);
            end
        end
    end
end
