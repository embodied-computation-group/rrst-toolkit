classdef kidsSimFlow < handle
    %KIDSSIMFLOW Synthetic inhalation flow with the same pull()/lost contract as flowInlet.
    %   src = kidsSimFlow()                         clock driven by advance(), starts at 0
    %   src = kidsSimFlow('Noise', 0.3, 'Seed', 1)  gaussian noise (slm SD), reproducible
    %   src = kidsSimFlow('Clock', @GetSecs)        pull() first advances to the clock's time
    %   src = kidsSimFlow('Jitter', 0.8e-3)         each reported time moved by up to
    %                                               +-0.8 ms (uniform), like live LSL times
    %
    %   s = src.pull() returns the samples generated since the last call as an N-by-2
    %   double [tSeconds flowSlm] (0-by-2 if none), at src.rate (1000 Hz). Times
    %   strictly increase unless 'Jitter' is set: then the rows stay in sample order
    %   and the flow is that of the true times, but a reported time can step back
    %   (flowInlet help: live times do, at chunk boundaries). The jitter has its own
    %   random stream, so the noise is the same with and without it.
    %   src.lost is a settable logical, to simulate a lost stream.
    %
    %   src.advance(dt)              move the clock on by dt s, generating those samples
    %   src.breathe(peak, dur)       one inhalation starting now: half-sine flow of the
    %                                given peak (slm) and duration (s), then the T-valve
    %                                backflow (backflowSlm for backflowDur s)
    %   src.breathe(peak, dur, n, interval)   n such breaths, onsets interval s apart
    %   src.quiet()                  cancel every scheduled breath: flow is 0 (plus
    %                                noise and extra) from now on
    %   src.extra = @(t) ...         optional extra flow (slm) at sample times t, e.g. a
    %                                wobble or a leak
    %
    %   For tests (advance by hand) and for a simulated child (cfg.debug.simulateChild)
    %   running the breath-driven trial without a sensor ('Clock', @GetSecs).

    properties
        lost = false
        noiseSlm = 0                 % gaussian noise SD, slm
        backflowSlm = -2             % T-valve backflow after each breath (handbook/shared/airflow-sensor.md)
        backflowDur = 1.5            % s
        extra = []                   % [] or function handle t -> slm
    end

    properties (SetAccess = private)
        rate = 1000                  % Hz
        jitter = 0                   % s, maximum time error of a reported sample
        t = 0                        % current clock time, s
    end

    properties (Access = private)
        t0 = 0
        nextK = 1                    % index of the next sample, at time t0 + k/rate
        buf = zeros(0, 2)
        breaths = zeros(0, 3)        % [onset dur peak]
        rng
        jitterRng
        clock = []
    end

    methods
        function src = kidsSimFlow(varargin)
            ip = inputParser;
            ip.addParameter('Rate', 1000, @(x) isscalar(x) && x > 0);
            ip.addParameter('Noise', 0, @(x) isscalar(x) && x >= 0);
            ip.addParameter('Seed', 0, @isscalar);
            ip.addParameter('Clock', [], @(x) isempty(x) || isa(x, 'function_handle'));
            ip.addParameter('T0', 0, @isscalar);
            ip.addParameter('Jitter', 0, @(x) isscalar(x) && x >= 0);
            ip.parse(varargin{:});
            o = ip.Results;
            src.rate = o.Rate;
            src.noiseSlm = o.Noise;
            src.jitter = o.Jitter;
            src.rng = RandStream('mt19937ar', 'Seed', o.Seed);
            src.jitterRng = RandStream('mt19937ar', 'Seed', o.Seed + 1);
            src.clock = o.Clock;
            if isempty(src.clock)
                src.t0 = o.T0;
            else
                src.t0 = src.clock();
            end
            src.t = src.t0;
        end

        function advance(src, dt)
            if ~(isscalar(dt) && dt >= 0)
                error('rrst:outOfRange', 'advance(dt) needs dt >= 0; got %s.', mat2str(dt));
            end
            src.t = src.t + dt;
            kEnd = floor((src.t - src.t0) * src.rate + 1e-6);
            if kEnd < src.nextK
                return
            end
            k = (src.nextK:kEnd)';
            ts = src.t0 + k / src.rate;
            reported = ts;
            if src.jitter > 0
                reported = ts + src.jitter * (2 * rand(src.jitterRng, size(ts)) - 1);
            end
            src.buf = [src.buf; reported, src.flowAt(ts)];
            src.nextK = kEnd + 1;
        end

        function s = pull(src)
            if ~isempty(src.clock)
                src.advance(max(src.clock() - src.t, 0));
            end
            s = src.buf;
            src.buf = zeros(0, 2);
        end

        function breathe(src, peakSlm, durS, n, intervalS)
            if nargin < 4, n = 1; end
            if nargin < 5, intervalS = 0; end
            if ~(isscalar(peakSlm) && peakSlm > 0 && isscalar(durS) && durS > 0 && ...
                    isscalar(n) && n >= 1 && isscalar(intervalS) && intervalS >= 0)
                error('rrst:outOfRange', 'breathe needs a positive peak, duration and count.');
            end
            onsets = src.t + (0:n-1)' * intervalS;
            src.breaths = [src.breaths; onsets, repmat([durS peakSlm], n, 1)];
        end

        function quiet(src)
            src.breaths = zeros(0, 3);
        end
    end

    methods (Access = private)
        function f = flowAt(src, ts)
            f = zeros(size(ts));
            for b = 1:size(src.breaths, 1)
                on = src.breaths(b, 1);
                dur = src.breaths(b, 2);
                in = ts >= on & ts <= on + dur;
                f(in) = f(in) + src.breaths(b, 3) * sin(pi * (ts(in) - on) / dur);
                back = ts > on + dur & ts <= on + dur + src.backflowDur;
                f(back) = f(back) + src.backflowSlm;
            end
            if ~isempty(src.extra)
                f = f + src.extra(ts);
            end
            if src.noiseSlm > 0
                f = f + src.noiseSlm * randn(src.rng, size(ts));
            end
        end
    end
end
