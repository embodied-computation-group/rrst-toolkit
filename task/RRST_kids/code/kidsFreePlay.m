function [status, slurps, info] = kidsFreePlay(fl, cfg, io)
%KIDSFREEPLAY Tutorial free play: the child slurps as often as they like.
%   [status, slurps, info] = kidsFreePlay(fl, cfg, io)
%
%   fl    kidsFlow on the session's flow source, or [] (no sensor)
%   cfg   kids configuration (child.slurps, timing.drain, flow.*, debug.timeScale)
%   io    the session's handles, as kidsSlurpPhase: draw, keys ("" | "skip" while
%         Space is down | "abort" | "bad"), now, marker, sound, prompt, sim
%
%   status   "done" (Space, or a simulated child's second slurp) | "abort" (Esc)
%   slurps   every slurp the detector saw (kidsFlow.stop); 0-by-1 without a sensor
%   info     nSlurps (slurps drunk on screen), durationS, refFound (the reference
%            was set from them)
%
%   The wedge is at 0 (kidsMain). The monster waits in its "ready" pose; each slurp
%   fills the belly ("slurp"), and every slurp of type end or weak is drunk: a third
%   (1 / cfg.child.slurps) of the milkshake drains with bubbles over
%   cfg.timing.drain s ("ahh"). When the glass is empty a new one stands there at
%   once. Never a try-again: before the reference exists a small child's slurps can
%   be "weak" against the default; an overlong one (leak or draught) deflates
%   quietly and the console names the cause. Markers and sounds as kidsSlurpPhase
%   (slurp_<k>_onset, slurp_<k>_end_<L>_<slm> or slurp_<k>_weak/overlong). No child
%   sentence: scene text and childText stay empty (kidsMain adds the experimenter's
%   line). With cfg.flow.feedback "none" the slurps are detected and recorded but
%   the screen does not move.
%
%   End: Space, once at least one slurp was drunk. Before that a Space press says so
%   on the console, and holding Space for 1 s ends free play anyway (escape hatch;
%   a lost stream lifts the rule). A simulated child (io.sim) ends it once two
%   slurps have drained; Space is ignored then. Without a sensor Space ends it at
%   once (a simulated child: at once).
%
%   At the end the reference slurp is set from every free slurp of type end or
%   weak (kidsSetReference), with its console line.
%   Plan: docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, sections 3.2 and 5.

ts = 1;
if isfield(cfg, 'debug') && isfield(cfg.debug, 'timeScale') && ~isempty(cfg.debug.timeScale)
    ts = cfg.debug.timeScale;
end
HOLD = 1;                                % s Space must be held to end with no slurp
SIM_SLURPS = 2;                          % a simulated child's free slurps
n = cfg.child.slurps;
tStart = io.now();
info = struct('nSlurps', 0, 'durationS', NaN, 'refFound', false);

if isempty(fl)
    slurps = noSlurps();
    status = "";
    while status == ""
        io.draw(scene(1));
        key = io.keys();
        if io.sim || key == "skip"
            status = "done";
        elseif key == "abort"
            status = "abort";
        end
    end
    info.durationS = io.now() - tStart;
    return
end

breath = cfg.flow.feedback == "breath";
frac = cfg.flow.bellyFraction;
drainDur = max(cfg.timing.drain, 0) * ts;
fl.start();
left = 1;                                % milkshake in the glass after the drains so far
k = 0;                                   % slurps seen (onsets)
c = 0;                                   % slurps drunk
drain = [];                              % t0, from (belly), cupFrom
deflate = [];                            % t0, from
holdT0 = NaN;                            % Space down since (no slurp yet)
told = false; prompted = false; lostTold = false;
status = "";
while status == ""
    for e = fl.update()'
        switch e.type
            case "onset"
                k = k + 1;
                io.sound("slurp");
                io.marker(kidsMarkerLabel("slurp", k, "onset"), e.t);
                deflate = [];
            case {"end", "weak"}
                c = c + 1;
                io.sound("bubbles");
                if e.type == "end"
                    io.marker(kidsMarkerLabel("slurp", k, "end", e.volumeL, e.peakSlm), e.t);
                else
                    io.marker(kidsMarkerLabel("slurp", k, "weak"), e.t);
                end
                if left <= 1e-9, left = 1; end            % a new slurp before the refill
                drain = struct('t0', io.now(), 'cupFrom', left, ...
                    'from', kidsBreathScale(e.volumeL, fl.refVolume, frac));
                left = max(left - 1 / n, 0);
                io.prompt(sprintf('Free slurp %d: %.2f L, peak %.0f slm%s.', k, e.volumeL, ...
                    e.peakSlm, ifelse(e.type == "weak", ' (small; sets the reference)', '')));
            case "overlong"
                io.marker(kidsMarkerLabel("slurp", k, "overlong"), e.t);
                deflate = struct('t0', io.now(), ...
                    'from', kidsBreathScale(e.volumeL, fl.refVolume, frac));
                io.prompt(sprintf(['Slurp %d lasted over %g s: not counted. Flow is not ' ...
                    'returning to zero: check the circuit for a leak or a draught at the ' ...
                    'inlet.'], k, cfg.flow.maxSlurpDur));
        end
    end
    if fl.lost && ~lostTold
        io.prompt('Airflow stream lost: Space ends free play.');
        lostTold = true;
    end
    if fl.timedOut && ~prompted
        io.prompt(sprintf(['No slurp seen for %g s: mouthpiece in? Space ends free play ' ...
            'after a slurp (hold it 1 s to go on without one).'], cfg.flow.slurpTimeout));
        prompted = true;
    elseif ~fl.timedOut
        prompted = false;
    end

    % Scene
    now = io.now();
    s = scene(left);
    if breath
        pDrain = NaN;
        if ~isempty(drain)
            pDrain = progress(now, drain.t0, drainDur);
            s.cup = max(drain.cupFrom - pDrain / n, 0);
            s.bubbles = pDrain;
            s.belly = drain.from * (1 - pDrain);
            s.pose = "ahh";
        end
        pDeflate = NaN;
        if ~isempty(deflate)
            pDeflate = progress(now, deflate.t0, drainDur);
            s.belly = deflate.from * (1 - pDeflate);
        end
        if fl.inSlurp
            s.belly = fl.belly;
            s.pose = "slurp";
        end
    end
    io.draw(s);
    if breath
        if pDrain >= 1
            drain = [];
            if left <= 1e-9, left = 1; end               % empty: a new milkshake
        end
        if pDeflate >= 1, deflate = []; end
    else
        drain = [];
        if left <= 1e-9, left = 1; end
    end

    % End
    if io.sim
        if c >= SIM_SLURPS && isempty(drain), status = "done"; end
        if io.keys() == "abort", status = "abort"; end
        continue
    end
    key = io.keys();
    if key == "abort"
        status = "abort";
    elseif key == "skip"
        if c >= 1 || fl.lost
            status = "done";
        else
            if isnan(holdT0), holdT0 = io.now(); end
            if ~told
                io.prompt('No slurp yet: let the child slurp first, or hold Space 1 s to go on without one.');
                told = true;
            end
            if io.now() - holdT0 >= HOLD, status = "done"; end
        end
    else
        holdT0 = NaN;
    end
end
slurps = fl.stop();
info.nSlurps = c;
[msg, info.refFound] = kidsSetReference(fl, slurps);
io.prompt(msg);
info.durationS = io.now() - tStart;
end

function s = scene(cup)
% The waiting frame: ready pose, no sentence.
s = struct('belly', 0, 'cup', cup, 'bubbles', NaN, 'text', '', 'childText', '', 'pose', "ready");
end

function p = progress(now, t0, dur)
p = min((now - t0) / max(dur, eps), 1);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end

function s = noSlurps()
% The record kidsFlow.stop() returns, with no slurps.
s = repmat(struct('onsetT', NaN, 'endT', NaN, 'durationS', NaN, 'peakSlm', NaN, ...
    'volumeL', NaN, 'counted', false, 'type', ""), 0, 1);
end
