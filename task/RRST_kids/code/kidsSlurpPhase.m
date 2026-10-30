function [status, slurps, info] = kidsSlurpPhase(fl, cfg, io)
%KIDSSLURPPHASE One trial's slurps: the monster drinks when the child breathes.
%   [status, slurps, info] = kidsSlurpPhase(fl, cfg, io)
%
%   fl    kidsFlow on the session's flow source, or [] (no sensor: timed animation)
%   cfg   kids configuration (child.slurps, timing.inhale/exhale, flow.*, text.language,
%         debug.timeScale if present)
%   io    the session's handles:
%         io.draw(scene)      draw the scene and flip; returns the flip time
%         io.keys()           "" | "skip" (Space) | "abort" (Esc) | "bad" (x)
%         io.now()            current time (GetSecs)
%         io.marker(label, t) LSL marker stamped at t
%         io.sound(name)      cue sound (kidsSound names)
%         io.prompt(msg)      one console line for the experimenter
%         io.sim              true for a simulated child: Space never ends the phase
%         io.free             (optional, default false) free slurps: the tutorial
%                             before practice, see below
%
%   status   "done"   cfg.child.slurps slurps counted (or animated)
%            "skip"   Space ended the phase early (info.shortSlurps says if short)
%            "bad"    x: the experimenter marks a bad breath (trial repeated later)
%            "abort"  Esc
%   slurps   every slurp the detector saw (kidsFlow.stop), counted or not; a 0-by-1
%            struct with the same fields when there is no flow
%   info     shortSlurps (fewer than cfg.child.slurps counted or animated),
%            flowLost (the stream was lost during the phase), counted (slurps counted
%            from the breath; free slurps: drunk on screen), durationS (phase length, s)
%
%   Breath-driven (cfg.flow.feedback "breath" and a flow): the belly follows the
%   current slurp's volume (kidsFlow.belly, saturating); a counted slurp drains a
%   third of the milkshake with bubbles over cfg.timing.exhale s; a weak or overlong
%   one deflates the belly and nothing drains. Per slurp k (counted or not, so k
%   indexes slurps): sound "slurp" and marker slurp_<k>_onset at the onset; sound
%   "bubbles" and marker slurp_<k>_end_<volumeL>_<peakSlm> for a counted end;
%   sound "tryagain" and marker slurp_<k>_weak or slurp_<k>_overlong otherwise, with
%   a console line. Markers carry the sample time of the event. With no onset for
%   cfg.flow.slurpTimeout s the experimenter is prompted once per quiet spell.
%   If the stream is lost the phase warns once and finishes the remaining slurps with
%   the timed animation (status "done", info.flowLost).
%
%   Free slurps (io.free): the reference does not exist yet, so a small child's slurps
%   can be "weak" against the 0.6 L default. Nothing is marked weak on screen: a weak
%   slurp is drunk like a counted one (drain, bubbles, sound "bubbles"); an overlong
%   one deflates with no try-again pose or sound (the console still names the leak).
%   The records and markers keep the detector's type; kidsMain sets the reference
%   from them (kidsReferenceSlurps).
%
%   Poses (kidsScene): "slurp" while the child inhales, "ahh" while the milkshake
%   drains with bubbles, "tryagain" while a weak or overlong slurp's belly deflates
%   (never for free slurps), "idle" while waiting. Timed: "slurp" during each inhale,
%   "ahh" during each exhale.
%
%   Timed (fl = [] or cfg.flow.feedback "none"): the animation of the timed task, per
%   slurp the belly grows over cfg.timing.inhale s while a third drains, then shrinks
%   with bubbles over cfg.timing.exhale s. With feedback "none" and a flow the
%   detector runs in the background for the record only: no markers, no sounds.
%   Plan: docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, section 3.3.

ts = 1;
if isfield(cfg, 'debug') && isfield(cfg.debug, 'timeScale') && ~isempty(cfg.debug.timeScale)
    ts = cfg.debug.timeScale;
end
txt = kidsText(cfg.text.language);
n = cfg.child.slurps;
tStart = io.now();
info = struct('shortSlurps', false, 'flowLost', false, 'counted', 0, 'durationS', NaN);
breath = ~isempty(fl) && cfg.flow.feedback == "breath";
free = isfield(io, 'free') && logical(io.free);

if isempty(fl)
    [status, done] = timed(1, false);
    slurps = noSlurps();
elseif ~breath
    fl.start();
    [status, done] = timed(1, true);
    slurps = fl.stop();
    info.flowLost = logical(fl.lost);
else
    [status, done] = breathDriven();
end
info.shortSlurps = done < n;
info.durationS = io.now() - tStart;

    % --- breath-driven --------------------------------------------------------------
    function [status, done] = breathDriven()
        fl.start();
        frac = cfg.flow.bellyFraction;
        exDur = max(cfg.timing.exhale, 0) * ts;
        c = 0;                           % counted
        k = 0;                           % slurps seen (onsets)
        drain = [];                      % struct t0, c, from: a counted slurp draining
        deflate = [];                    % struct t0, from: a weak slurp's belly going down
        prompted = false;
        status = "";
        while true
            ev = fl.update();
            for e = ev'
                switch e.type
                    case "onset"
                        k = k + 1;
                        io.sound("slurp");
                        io.marker(kidsMarkerLabel("slurp", k, "onset"), e.t);
                        deflate = [];
                    case "end"
                        c = c + 1;
                        io.sound("bubbles");
                        io.marker(kidsMarkerLabel("slurp", k, "end", e.volumeL, e.peakSlm), e.t);
                        drain = struct('t0', io.now(), 'c', c, ...
                            'from', kidsBreathScale(e.volumeL, fl.refVolume, frac));
                        if free
                            io.prompt(sprintf('Free slurp %d: %.2f L, peak %.0f slm (%d of %d).', ...
                                k, e.volumeL, e.peakSlm, c, n));
                        else
                            io.prompt(sprintf('Slurp %d counted: %.2f L, peak %.0f slm (%d of %d).', ...
                                k, e.volumeL, e.peakSlm, c, n));
                        end
                    case "weak"
                        io.marker(kidsMarkerLabel("slurp", k, "weak"), e.t);
                        from = kidsBreathScale(e.volumeL, fl.refVolume, frac);
                        if free                     % the tutorial: drunk like a counted one
                            c = c + 1;
                            io.sound("bubbles");
                            drain = struct('t0', io.now(), 'c', c, 'from', from);
                            io.prompt(sprintf(['Free slurp %d: %.2f L, peak %.0f slm (%d of %d; ' ...
                                'small, sets the reference).'], k, e.volumeL, e.peakSlm, c, n));
                        else
                            io.sound("tryagain");
                            deflate = struct('t0', io.now(), 'from', from, 'pose', "tryagain");
                            minL = max(cfg.flow.minVolumeFrac * fl.refVolume, cfg.flow.minVolumeL);
                            io.prompt(sprintf(['Slurp %d too weak (%.2f L; a slurp counts from ' ...
                                '%.2f L): not counted, try again.'], k, e.volumeL, minL));
                        end
                    case "overlong"
                        io.marker(kidsMarkerLabel("slurp", k, "overlong"), e.t);
                        deflate = struct('t0', io.now(), ...
                            'from', kidsBreathScale(e.volumeL, fl.refVolume, frac), ...
                            'pose', ifelse(free, "idle", "tryagain"));
                        if ~free
                            io.sound("tryagain");
                        end
                        io.prompt(sprintf(['Slurp %d lasted over %g s: not counted. Flow ' ...
                            'is not returning to zero: check the circuit for a leak or ' ...
                            'a draught at the inlet.'], k, cfg.flow.maxSlurpDur));
                end
            end
            if fl.lost
                io.prompt(['Airflow stream lost: this trial finishes with the timed ' ...
                    'animation (flowLost). The task looks for the stream again before ' ...
                    'the next trial.']);
                info.flowLost = true;
                slurpsSoFar = c;
                [status, done] = timed(c + 1, false);
                done = slurpsSoFar + done;
                slurps = fl.stop();
                info.counted = slurpsSoFar;
                return
            end
            if fl.timedOut && ~prompted
                io.prompt(sprintf(['No slurp seen for %g s: mouthpiece in? ' ...
                    'Space = go on, x = repeat, Esc = abort'], cfg.flow.slurpTimeout));
                prompted = true;
            elseif ~fl.timedOut
                prompted = false;
            end

            % Scene
            now = io.now();
            s = struct('belly', 0, 'cup', 1 - c / n, 'bubbles', NaN, 'text', txt.inhale, 'pose', "idle");
            pDrain = NaN;
            if ~isempty(drain)
                pDrain = progress(now, drain.t0, exDur);
                s.cup = 1 - (drain.c - 1 + pDrain) / n;
                s.bubbles = pDrain;
                s.belly = drain.from * (1 - pDrain);
                s.text = txt.exhale;
                s.pose = "ahh";
            end
            pDeflate = NaN;
            if ~isempty(deflate)
                pDeflate = progress(now, deflate.t0, exDur);
                s.belly = deflate.from * (1 - pDeflate);
                if isempty(drain), s.pose = deflate.pose; end
            end
            if fl.inSlurp
                s.belly = fl.belly;
                s.text = txt.inhale;
                s.pose = "slurp";
            end
            io.draw(s);
            if pDrain >= 1, drain = []; end
            if pDeflate >= 1, deflate = []; end
            if c >= n && isempty(drain)
                status = "done";
                break
            end
            key = io.keys();
            if key == "abort" || key == "bad" || (key == "skip" && ~io.sim)
                status = key;
                break
            end
        end
        done = c;
        info.counted = c;
        slurps = fl.stop();
    end

    % --- timed -------------------------------------------------------------------------
    function [status, done] = timed(first, detect)
        % Today's animation for slurps first..n. done: slurps animated to the end.
        status = "done";
        done = first - 1;
        for j = first:n
            left = 1 - (j - 1) / n;           % milkshake left before this slurp
            st = animate(cfg.timing.inhale, @(p) struct('belly', p, 'cup', left - p / n, 'text', txt.inhale, 'pose', "slurp"));
            if st == ""
                st = animate(cfg.timing.exhale, @(p) struct('belly', 1 - p, 'cup', left - 1 / n, 'bubbles', p, 'text', txt.exhale, 'pose', "ahh"));
            end
            if st ~= ""
                status = st;
                break
            end
            done = j;
        end
        done = done - (first - 1);

        function st = animate(dur, sceneAt)
            st = "";
            dur = max(dur, 0) * ts;
            t0 = io.now();
            while true
                p = progress(io.now(), t0, dur);
                io.draw(sceneAt(p));
                if detect
                    fl.update();
                end
                key = io.keys();
                if key == "abort" || key == "bad" || (key == "skip" && ~io.sim)
                    st = key;
                    return
                end
                if p >= 1, return; end
            end
        end
    end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end

function p = progress(now, t0, dur)
p = min((now - t0) / max(dur, eps), 1);
end

function s = noSlurps()
% The record kidsFlow.stop() returns, with no slurps.
s = repmat(struct('onsetT', NaN, 'endT', NaN, 'durationS', NaN, 'peakSlm', NaN, ...
    'volumeL', NaN, 'counted', false, 'type', ""), 0, 1);
end
