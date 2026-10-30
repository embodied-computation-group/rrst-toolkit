function [s, dur, cue] = kidsBeat(beat, p, ctx)
%KIDSBEAT Scene, length and cue sound of one moment of an RRST-Kids session (pure).
%   [s, dur, cue] = kidsBeat(beat, p, ctx)
%
%   beat  one of the names below
%   p     progress through the beat's animation, 0 to 1 (1: its last frame, which
%         kidsMain holds while it waits for Space)
%   ctx   stars, cupsDone, nCups (the progress before this beat's increment), txt
%         (kidsText), timing (cfg.timing), level (needed by "reveal" only)
%   s     kidsScene struct, every field set except the clock t (kidsMain adds it);
%         flavour = cupsDone + 1; sentences go in text (the experimenter's small line)
%   dur   s, the animation's length before cfg.debug.timeScale (0: a still)
%   cue   kidsSound cue to play when the beat starts ("" for none)
%
%   Beats (plan docs/kids_flow_feedback_and_ux_plan_2026-10-30.md, section 5.3):
%     calibrating  no straw, "Getting the straw ready..."
%     story1       3 s: "slurp" while the cup drains over 2 s, then "ahh" with bubbles
%     story2       0.8 s: "strain", the mouse pinching the straw; cue mouse
%     story3       1.5 s: the mouse runs off (mouseX 0.3 to 1), the monster "idle"
%     move         cfg.timing.moveMin: the mouse runs along the bottom (0.1 to 0.9),
%                  no straw; cue mouse. The same for catch and load trials.
%     ready        "ready": looking at the child, mouth open on the straw; cue ready
%     reveal       1.5 s, practice feedback: the mouse pinching (level > 0; cue mouse)
%                  or asleep (catch) in a spotlight, cup 0
%     star         cfg.timing.reward: the star flies from the belly to slot stars+1
%                  (flyStar = p); cue star. kidsMain counts the star afterwards.
%     cup          cfg.timing.dance, the tenth star: "celebrate"; the drunk cup tips
%                  into done slot cupsDone+1 over the first half, then a new cup in the
%                  next flavour and the celebrate wiggle; cue cup
%     nap          cfg.timing.pause: "sleep", no straw, the bar drains (restLeft 1-p)
%     stretch      0.6 s: "celebrate" (arms up), waking from the nap
%     pause        cup 0, "Pause"
%     sticker      3 s: "celebrate", "All done!"
%     thanks       3 s: "idle", the thank-you line (practice not passed)
if ~((isstring(beat) && isscalar(beat)) || ischar(beat))
    error('rrst:badBeat', 'beat must be a name.');
end
beat = string(beat);
p = min(max(p, 0), 1);
t = ctx.timing; txt = ctx.txt;
s = struct('belly', 0, 'cup', 1, 'straw', true, 'mouseX', NaN, 'bubbles', NaN, ...
    'wiggle', 0, 'stars', ctx.stars, 'cupsDone', ctx.cupsDone, 'nCups', ctx.nCups, ...
    'text', '', 'pose', "idle", 'mousePose', "", 'reveal', "", 'flyStar', NaN, ...
    'cupTip', NaN, 'restLeft', NaN, 'flavour', 1);
dur = 0; cue = "";
switch beat
    case "calibrating"
        s.straw = false; s.text = txt.calibrating;
    case "story1"
        dur = 3; drink = 2 / 3;                       % 2 s of 3
        s.text = txt.story1; s.mousePose = "hidden";
        if p < drink
            q = p / drink;
            s.pose = "slurp"; s.cup = 1 - q; s.belly = q;
        else
            q = (p - drink) / (1 - drink);
            s.pose = "ahh"; s.cup = 0; s.bubbles = max(q, 0.02); s.belly = 1 - q;
        end
    case "story2"
        dur = 0.8; cue = "mouse";
        s.pose = "strain"; s.mousePose = "pinch"; s.belly = 0.25 * p;
        s.text = txt.story2;
    case "story3"
        dur = 1.5;
        s.mousePose = "run"; s.mouseX = 0.3 + 0.7 * p;
        s.text = txt.story3;
    case "move"
        dur = t.moveMin; cue = "mouse";
        s.straw = false; s.mousePose = "run"; s.mouseX = 0.1 + 0.8 * p;
    case "ready"
        cue = "ready";
        s.pose = "ready"; s.text = txt.cue;
    case "reveal"
        if ~isfield(ctx, 'level') || ~(isnumeric(ctx.level) && isscalar(ctx.level) && isfinite(ctx.level))
            error('rrst:badBeat', 'The reveal needs the trial''s level (ctx.level).');
        end
        dur = 1.5; s.cup = 0;
        if ctx.level > 0
            s.reveal = "pinch"; cue = "mouse"; s.text = txt.yesFeedback;
        else
            s.reveal = "sleep"; s.text = txt.noFeedback;
        end
    case "star"
        dur = t.reward; cue = "star";
        s.cup = 0; s.pose = "ahh"; s.flyStar = p; s.text = txt.star;
    case "cup"
        dur = t.dance; cue = "cup";
        s.pose = "celebrate"; s.text = txt.cupDone;
        if p < 0.5
            s.cup = 0; s.cupTip = 2 * p;
        else
            q = (p - 0.5) / 0.5;
            s.cupsDone = ctx.cupsDone + 1;           % the tipped cup is in the done row
            s.cup = 1;                                % and a new milkshake is on the table
            s.wiggle = 40 * sin(q * 6 * pi);
        end
    case "nap"
        dur = t.pause;
        s.pose = "sleep"; s.straw = false; s.restLeft = 1 - p;
        s.text = sprintf(txt.rest, ceil((1 - p) * t.pause));
    case "stretch"
        dur = 0.6;
        s.pose = "celebrate"; s.straw = false;
    case "pause"
        s.cup = 0; s.text = txt.pause;
    case "sticker"
        dur = 3;
        s.cup = 0; s.pose = "celebrate"; s.text = txt.sticker;
    case "thanks"
        dur = 3;
        s.text = txt.thanks;
    otherwise
        error('rrst:badBeat', 'Unknown beat "%s".', beat);
end
s.flavour = s.cupsDone + 1;
end
