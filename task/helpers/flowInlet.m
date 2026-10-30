classdef flowInlet < handle
%FLOWINLET Read the "Flow" airflow stream (plux-lsl/flow_lsl.py) over Lab Streaming Layer.
%   src = flowInlet(liblslDir, timeoutS)   find the "Flow" stream (waits up to
%                                          timeoutS, default 10) and connect to it
%   src = flowInlet(..., Name="FlowTest")  another stream name (tests)
%   s = src.pull()             N-by-2 [t flowSlm]: every sample since the last call,
%                              0-by-2 if none. t is on the GetSecs clock
%                              (src.clockBase "GetSecs"), or on the LSL clock when
%                              Psychtoolbox is not available (clockBase "lsl").
%   src.lost                   true once the stream is lost, or has sent nothing for
%                              src.staleAfter s (default 1) while pull is called
%   ok = src.reconnect(t)      look for the stream once more (t s, default 1);
%                              on success connect to it and clear lost
%   [ok, msg] = src.check(d)   read d s (default 1) and apply the quality rules of
%                              plux-lsl/flow_quality.py; msg names the fix
%   src.close()                release the inlet (also when src is deleted)
%
%   The stream has 3 channels [nSeq flow temp], flow in slm, positive = inhalation,
%   about 1000 Hz pushed in chunks every ~20 ms. Gaps in nSeq (samples lost at the
%   bridge) are counted in nGaps and nDropped. LSL times are moved onto GetSecs with
%   the offset between the two clocks measured at each pull, as rrstMarker does.
%   The inlet keeps 5 s of data, so a caller that pauses pulling loses nothing
%   younger than that.
%
%   Times are the streamer's: flow_lsl.py stamps the newest sample of each chunk
%   with the time it asked the bridge, and LSL spaces the earlier ones at the
%   nominal 1 ms while the bridge runs at about 1005 Hz. At a chunk boundary a time
%   can therefore step back by up to about 1 ms (seen live, 2026-10-30). Integrate
%   volume over samples (flow / 60 / sampleRate litres each), not over diff(t).

    properties
        staleAfter (1, 1) double {mustBePositive} = 1.0   % s without samples -> lost
    end

    properties (SetAccess = private)
        name string                 % stream name
        hostname string = ""        % computer the stream comes from
        clockBase string            % "GetSecs" or "lsl": the clock of pull's times
        nominalRate double          % Hz, as declared by the stream
        lost logical = false
        nSamples double = 0         % samples received since the inlet was opened
        nGaps double = 0            % jumps in nSeq
        nDropped double = 0         % samples missing in those jumps
    end

    properties (Access = private)
        lib
        inlet
        timeCorrection double = 0   % s, added to the stream's times (0 on the same PC)
        lastSeq double = NaN
        lastDataT double            % lsl_local_clock of the last pull that got data
    end

    properties (Constant)
        RangeSlm = [-10 240]        % SFM3019-240 measurement range
        MinBreathSlm = 3            % a deliberate inhalation peaks well above this
        BufferS = 5                 % inlet buffer
    end

    methods
        function src = flowInlet(liblslDir, timeoutS, opts)
            arguments
                liblslDir {mustBeTextScalar}
                timeoutS (1, 1) double {mustBeNonnegative} = 10
                opts.Name {mustBeTextScalar} = "Flow"
            end
            if ~isfolder(liblslDir)
                error('rrst:noLiblsl', ['liblsl-Matlab not found at %s. Install it there ' ...
                    '(github.com/labstreaminglayer/liblsl-Matlab releases), or set ' ...
                    'cfg.flow.enabled = false to run without breath feedback.'], liblslDir);
            end
            addpath(char(liblslDir), fullfile(char(liblslDir), 'bin'));
            src.lib = lsl_loadlib();
            src.name = string(opts.Name);
            try
                GetSecs;
                src.clockBase = "GetSecs";
            catch
                src.clockBase = "lsl";
            end
            info = src.resolve(timeoutS);
            if isempty(info)
                error('rrst:noFlowStream', ['No airflow stream ("%s" not found within %g s). ' ...
                    'Start the Physio Recorder with the RRST preset, or run flow_lsl.py, ' ...
                    'or set cfg.flow.enabled = false to run without breath feedback.'], ...
                    src.name, timeoutS);
            end
            src.connect(info);
        end

        function s = pull(src)
            s = zeros(0, 2);
            if isempty(src.inlet)
                return
            end
            try
                [x, t] = src.inlet.pull_chunk();
            catch err
                if strcmp(err.identifier, 'lsl:lost_error')
                    src.lost = true;
                    return
                end
                rethrow(err);
            end
            lslNow = lsl_local_clock(src.lib);
            if isempty(t)
                if lslNow - src.lastDataT > src.staleAfter
                    src.lost = true;
                end
                return
            end
            src.lastDataT = lslNow;
            t = t(:) + src.timeCorrection;
            if src.clockBase == "GetSecs"
                g = GetSecs;
                t = t - (lsl_local_clock(src.lib) - g);
            end
            seq = x(1, :)';
            d = diff([src.lastSeq; seq]);
            jump = d > 1;                           % d <= 0: the streamer restarted
            src.nGaps = src.nGaps + sum(jump);
            src.nDropped = src.nDropped + sum(d(jump) - 1);
            src.lastSeq = seq(end);
            src.nSamples = src.nSamples + numel(t);
            s = [t, x(2, :)'];
        end

        function ok = reconnect(src, timeoutS)
            if nargin < 2
                timeoutS = 1;
            end
            info = src.resolve(timeoutS);
            ok = false;
            if isempty(info)
                return
            end
            try
                src.connect(info);
                ok = true;
            catch err
                if ~strcmp(err.identifier, 'rrst:noFlowStream')
                    rethrow(err);
                end
            end
        end

        function [ok, msg] = check(src, durationS)
            if nargin < 2
                durationS = 1;
            end
            x = zeros(0, 1);
            t = tic;
            while toc(t) < durationS
                s = src.pull();
                x = [x; s(:, 2)]; %#ok<AGROW>
                pause(0.02);
            end
            s = src.pull();
            [ok, msg] = flowInlet.quality([x; s(:, 2)], durationS, src.nominalRate);
        end

        function close(src)
            src.inlet = [];
        end

        function delete(src)
            src.close();
        end
    end

    methods (Static)
        function [ok, msg] = quality(x, durationS, fs)
            %QUALITY Rules of plux-lsl/flow_quality.py for flow x (slm) read over durationS.
            x = x(isfinite(x));
            n = numel(x);
            ok = false;
            if n == 0
                msg = sprintf(['No airflow samples in %.1f s: the flow stream is not sending. ' ...
                    'Restart it (Physio Recorder RRST preset, or flow_lsl.py).'], durationS);
            elseif fs > 0 && n < 0.5 * fs * durationS
                msg = sprintf(['Airflow stream is stalling: %d samples in %.1f s, expected ' ...
                    'about %d. Restart the flow stream.'], n, durationS, round(fs * durationS));
            elseif max(x) == min(x)
                msg = "FROZEN - flow sensor not updating; restart the flow stream";
            elseif mean(x <= flowInlet.RangeSlm(1) + 0.1 | x >= flowInlet.RangeSlm(2) - 1) > 0.01
                msg = ['OUT OF RANGE - flow beyond the sensor''s limits; is the sensor ' ...
                    'mounted backwards? Its arrow must point toward the participant'];
            elseif mean(x < -5) > 0.01
                % About -2 slm for 1-2 s after every breath is the T-valve closing (bench
                % 2026-10-28); a reversed sensor shows whole breaths as large negative flow.
                msg = "REVERSE FLOW - sensor arrow should point toward the participant";
            elseif median(movmean(x, max(1, round(fs / 5)))) > flowInlet.MinBreathSlm
                msg = sprintf(['CONSTANT FLOW - air is moving all the time (%.1f slm); ' ...
                    'check the circuit for a leak or a draught at the inlet'], median(x));
            else
                ok = true;
                m = mean(x);
                if abs(m) < 0.05
                    m = 0;                          % no "-0.0"
                end
                msg = sprintf('Airflow sensor OK: %.1f slm at rest', m);
            end
            msg = string(msg);
        end
    end

    methods (Access = private)
        function info = resolve(src, timeoutS)
            % The stream named src.name, preferring one on this computer; [] if none.
            % liblsl 1.18 overruns a resolve timeout just below 0.5 s by about 5 s: on
            % the stim laptop (2026-10-30) 0.495 and 0.5 s took 5.5 s on nearly every
            % call, while 0.2 to 0.49 s and 0.505 to 3 s returned on time. 0.5 s is
            % also liblsl's default MulticastMinRTT, so the timeout probably races the
            % resolver's wave timer. Step clear of it.
            if timeoutS > 0.48 && timeoutS < 0.52
                timeoutS = 0.52;
            end
            infos = lsl_resolve_byprop(src.lib, 'name', char(src.name), 1, timeoutS);
            info = [];
            if isempty(infos)
                return
            end
            hosts = strings(1, numel(infos));
            for k = 1:numel(infos)
                try
                    hosts(k) = string(lsl_get_hostname(src.lib, infos{k}.InfoHandle));
                catch
                end
            end
            [~, me] = system('hostname');
            k = find(strcmpi(hosts, strtrim(me)), 1);
            if isempty(k)
                k = 1;
                if numel(infos) > 1
                    warning('rrst:severalFlowStreams', ['%d streams named "%s" on the ' ...
                        'network, none on this computer; using the one on %s.'], ...
                        numel(infos), src.name, hosts(1));
                end
            end
            info = infos{k};
            src.hostname = hosts(k);
        end

        function connect(src, info)
            src.inlet = [];
            src.nominalRate = info.nominal_srate();
            if info.channel_count() < 2
                error('rrst:badFlowStream', 'Stream "%s" has %d channel(s); expected [nSeq flow temp].', ...
                    src.name, info.channel_count());
            end
            in = lsl_inlet(info, flowInlet.BufferS);
            try
                in.open_stream(5);              % connect now, so no sample is missed
            catch
                error('rrst:noFlowStream', ['The airflow stream "%s" was found but did not ' ...
                    'connect within 5 s. Restart the flow stream (Physio Recorder RRST ' ...
                    'preset, or flow_lsl.py), or set cfg.flow.enabled = false to run ' ...
                    'without breath feedback.'], src.name);
            end
            try
                src.timeCorrection = in.time_correction(2);
            catch
                src.timeCorrection = 0;
            end
            src.inlet = in;
            src.lost = false;
            src.lastSeq = NaN;
            src.lastDataT = lsl_local_clock(src.lib);
        end
    end
end
