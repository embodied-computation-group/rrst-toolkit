classdef kidsFlow < handle
    %KIDSFLOW Live breath detector for the RRST-Kids slurp phase.
    %   f = kidsFlow(src, p)   src: flow source with s = src.pull() ([t flowSlm], N-by-2,
    %                          new samples only) and src.lost (flowInlet, kidsSimFlow),
    %                          or [] for none. p: the cfg.flow struct.
    %
    %   f.start()              begin a slurp phase: counts and slurps cleared, samples
    %                          already waiting are used to warm the filter only. A breath
    %                          still in progress at start() is ignored: detection waits
    %                          until flow has been below onsetSlm for offsetHold.
    %   ev = f.update()        pull, low-pass, detect; events since the last call, a
    %                          column struct array with type ("onset" | "end" | "weak" |
    %                          "overlong"), t (sample time of the onset, or of the
    %                          end: first sample below threshold, or the moment the
    %                          slurp became overlong), volumeL, peakSlm, durationS (NaN
    %                          for "onset"). Before start() or after stop(): no events.
    %   [minL, fullL] = f.setReference(volumesL)   reference volume = median of the
    %                          finite positive volumes, clamped to [0.15, 2] L (kept as it
    %                          is if there are none); returns the counting threshold and
    %                          the full-belly volume.
    %   slurps = f.stop()      end the phase. A slurp in progress is recorded uncounted,
    %                          with type "interrupted".
    %
    %   Detection (plan docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, sections 1-3):
    %   a causal first-order low-pass at p.smoothHz; onset when the filtered flow stays
    %   above p.onsetSlm for p.onsetHold s, end when it stays below for p.offsetHold s.
    %   Volume (L) integrates the positive filtered flow from the first sample above
    %   threshold to the confirmed end (slm / 60 * dt): the T-valve backflow never
    %   subtracts and, being negative, never triggers. A slurp counts ("end") when its
    %   volume is at least max(p.minVolumeFrac * refVolume, p.minVolumeL), otherwise
    %   "weak"; one lasting more than p.maxSlurpDur is "overlong", not counted, and the
    %   detector then waits for flow to return below threshold.

    properties (SetAccess = private)
        belly = 0                    % 0..1, current slurp's volume via kidsBreathScale
        inSlurp = false
        counted = 0                  % counted slurps since start()
        slurps                       % every slurp since start()
        refVolume                    % L
        lastSampleT = NaN            % time of the last sample pulled
        timedOut = false             % no onset for slurpTimeout s since start or last end
        started = false
    end

    properties (Dependent)
        lost                         % the source reports a lost stream (true without one)
    end

    properties (Access = private)
        src
        p
        state = "off"                % off | idle | candidate | slurp | waitQuiet
        y = NaN                      % filtered flow, slm
        prevT = NaN
        candT = NaN                  % first sample above threshold
        belowSince = NaN             % first sample below threshold (slurp or waitQuiet)
        onsetT = NaN
        vol = 0
        peak = 0
        refT = NaN                   % timeout reference: start or the last end
    end

    properties (Constant, Access = private)
        MAX_DT = 0.05                % s; a longer gap is integrated as this
        REF_RANGE = [0.15 2]         % L, clamp for the reference volume
    end

    methods
        function f = kidsFlow(src, p)
            kidsFlow.validate(p);
            f.src = src;
            f.p = p;
            f.refVolume = p.refVolumeDefault;
            f.slurps = kidsFlow.noSlurps();
        end

        function v = get.lost(f)
            v = isempty(f.src) || logical(f.src.lost);
        end

        function start(f)
            f.state = "off";
            f.consume();                              % warm the filter, no detection
            f.counted = 0;
            f.slurps = kidsFlow.noSlurps();
            f.belly = 0;
            f.inSlurp = false;
            f.timedOut = false;
            f.started = true;
            f.refT = f.lastSampleT;
            f.belowSince = NaN;
            if ~isnan(f.y) && f.y > f.p.onsetSlm
                f.state = "waitQuiet";
            else
                f.state = "idle";
            end
        end

        function ev = update(f)
            ev = f.consume();
            if f.started && ~f.inSlurp && ~isnan(f.refT)
                f.timedOut = f.lastSampleT - f.refT >= f.p.slurpTimeout;
            else
                f.timedOut = false;
            end
        end

        function [minL, fullL] = setReference(f, volumesL)
            v = volumesL(isfinite(volumesL) & volumesL > 0);
            if ~isempty(v)
                f.refVolume = min(max(median(v), f.REF_RANGE(1)), f.REF_RANGE(2));
            end
            minL = f.minVolume();
            fullL = f.p.bellyFraction * f.refVolume;
        end

        function s = stop(f)
            if f.inSlurp
                f.record("interrupted", f.lastSampleT, false);
            end
            f.inSlurp = false;
            f.belly = 0;
            f.started = false;
            f.timedOut = false;
            f.state = "off";
            s = f.slurps;
        end
    end

    methods (Access = private)
        function m = minVolume(f)
            m = max(f.p.minVolumeFrac * f.refVolume, f.p.minVolumeL);
        end

        function ev = consume(f)
            % Pull everything new, filter it and run the detector sample by sample.
            ev = kidsFlow.noEvents();
            if isempty(f.src)
                return
            end
            s = f.src.pull();
            if isempty(s)
                return
            end
            p = f.p;
            y = f.y;
            prevT = f.prevT;
            on = p.onsetSlm;
            for i = 1:size(s, 1)
                ti = s(i, 1);
                if isnan(prevT)
                    dt = 0;
                    y = s(i, 2);
                else
                    dt = min(max(ti - prevT, 0), f.MAX_DT);
                    y = y + (1 - exp(-2 * pi * p.smoothHz * dt)) * (s(i, 2) - y);
                end
                prevT = ti;
                if f.state == "off"
                    continue
                end
                if isnan(f.refT)
                    f.refT = ti;
                end
                above = y > on;
                switch f.state
                    case "idle"
                        if above
                            f.state = "candidate";
                            f.candT = ti;
                            f.vol = y * dt / 60;
                            f.peak = y;
                        end
                    case "candidate"
                        if ~above
                            f.state = "idle";
                        else
                            f.vol = f.vol + y * dt / 60;
                            f.peak = max(f.peak, y);
                            if ti - f.candT >= p.onsetHold
                                f.state = "slurp";
                                f.inSlurp = true;
                                f.onsetT = f.candT;
                                f.belowSince = NaN;
                                f.timedOut = false;
                                f.belly = kidsBreathScale(f.vol, f.refVolume, p.bellyFraction);
                                ev(end+1, 1) = kidsFlow.event("onset", f.onsetT); %#ok<AGROW>
                            end
                        end
                    case "slurp"
                        f.vol = f.vol + max(y, 0) * dt / 60;
                        f.peak = max(f.peak, y);
                        if above
                            f.belowSince = NaN;
                        elseif isnan(f.belowSince)
                            f.belowSince = ti;
                        end
                        if ~above && ti - f.belowSince >= p.offsetHold
                            ok = f.vol >= f.minVolume();
                            ev(end+1, 1) = f.record(ifelse(ok, "end", "weak"), f.belowSince, ok); %#ok<AGROW>
                            f.state = "idle";
                        elseif ti - f.onsetT > p.maxSlurpDur
                            ev(end+1, 1) = f.record("overlong", ti, false); %#ok<AGROW>
                            f.state = "waitQuiet";
                            f.belowSince = NaN;
                        else
                            f.belly = kidsBreathScale(f.vol, f.refVolume, p.bellyFraction);
                        end
                    case "waitQuiet"
                        if above
                            f.belowSince = NaN;
                        elseif isnan(f.belowSince)
                            f.belowSince = ti;
                        elseif ti - f.belowSince >= p.offsetHold
                            f.state = "idle";
                        end
                end
            end
            f.y = y;
            f.prevT = prevT;
            f.lastSampleT = prevT;
        end

        function e = record(f, type, tEnd, ok)
            dur = tEnd - f.onsetT;
            f.slurps(end+1, 1) = struct('onsetT', f.onsetT, 'endT', tEnd, 'durationS', dur, ...
                'peakSlm', f.peak, 'volumeL', f.vol, 'counted', ok, 'type', type);
            f.counted = f.counted + ok;
            f.inSlurp = false;
            f.belly = 0;
            f.refT = tEnd;
            e = kidsFlow.event(type, tEnd, f.vol, f.peak, dur);
        end
    end

    methods (Static, Access = private)
        function validate(p)
            bad = @(msg, varargin) error('rrst:badConfig', ['Flow configuration: ' msg], varargin{:});
            if ~isstruct(p)
                bad('cfg.flow must be a struct.');
            end
            positive = {'onsetSlm', 'onsetHold', 'offsetHold', 'minVolumeL', ...
                'refVolumeDefault', 'slurpTimeout', 'maxSlurpDur', 'smoothHz'};
            fractions = {'minVolumeFrac', 'bellyFraction'};
            num = @(v) isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v);
            for k = 1:numel(positive)
                n = positive{k};
                if ~isfield(p, n)
                    bad('flow.%s is missing.', n);
                end
                if ~(num(p.(n)) && p.(n) > 0)
                    bad('flow.%s must be a positive number.', n);
                end
            end
            for k = 1:numel(fractions)
                n = fractions{k};
                if ~isfield(p, n)
                    bad('flow.%s is missing.', n);
                end
                if ~(num(p.(n)) && p.(n) > 0 && p.(n) <= 1)
                    bad('flow.%s must be a fraction in (0, 1].', n);
                end
            end
        end

        function e = event(type, t, vol, peak, dur)
            if nargin < 3
                vol = NaN; peak = NaN; dur = NaN;
            end
            e = struct('type', type, 't', t, 'volumeL', vol, 'peakSlm', peak, 'durationS', dur);
        end

        function e = noEvents()
            e = repmat(kidsFlow.event("", NaN), 0, 1);
        end

        function s = noSlurps()
            s = repmat(struct('onsetT', NaN, 'endT', NaN, 'durationS', NaN, 'peakSlm', NaN, ...
                'volumeL', NaN, 'counted', false, 'type', ""), 0, 1);
        end
    end
end

function v = ifelse(c, a, b)
if c
    v = a;
else
    v = b;
end
end
