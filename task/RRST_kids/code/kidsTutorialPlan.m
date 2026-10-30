function plan = kidsTutorialPlan(cfg)
%KIDSTUTORIALPLAN The steps of the RRST-Kids intro tutorial, in order (pure).
%   plan = kidsTutorialPlan(cfg)   struct array, one element per step; 0-by-1 when
%                                  cfg.tutorial.enabled is false
%
%   The tutorial runs between the story and the practice (kidsMain):
%     freeplay  the wedge at 0, breath feedback on, no question: the child slurps as
%               often as they like (kidsFreePlay) and every slurp sets the reference
%     demo      one per cfg.tutorial.demoOrder: "pinch" at cfg.tutorial.pinchLevel
%               with the mouse pinching the straw during the slurps, "sleep" at 0
%               with the mouse asleep; cfg.child.slurps slurps (kidsSlurpPhase),
%               then the reveal. No question.
%     bridge    the two answer cards (kidsQuestion, no pointer) while the
%               experimenter explains them; Space goes on to the practice
%
%   Fields per step:
%     kind           "freeplay" | "demo" | "bridge"
%     name           "freeplay" | "pinch" | "sleep" | "bridge"
%     level          wedge level (NaN for the bridge: the wedge does not move)
%     mousePose      the mouse during the ready screen and the slurps ("" none)
%     reveal         the reveal after the slurps ("" none)
%     prompt         kidsPrompt moment for the step
%     markersBefore  LSL markers once the wedge is at the level (string row)
%     markersAfter   LSL markers when the step ends (string row)
%   Markers: tutorial_start, freeplay_start, freeplay_end, demo_<name>_level_<x>
%   (%g, as trial_<n>_level_<x>), tutorial_end.

plan = repmat(step("", "", NaN, "", "", "", strings(1, 0), strings(1, 0)), 0, 1);
t = cfg.tutorial;
if ~t.enabled
    return
end
plan(end + 1, 1) = step("freeplay", "freeplay", 0, "", "", "freeplay", ...
    ["tutorial_start" "freeplay_start"], "freeplay_end");
for name = reshape(string(t.demoOrder), 1, [])
    switch name
        case "pinch", level = t.pinchLevel;
        case "sleep", level = 0;
        otherwise
            error('rrst:badConfig', 'Unknown tutorial demo "%s".', name);
    end
    plan(end + 1, 1) = step("demo", name, level, name, name, "demo", ...
        string(sprintf('demo_%s_level_%g', name, level)), strings(1, 0)); %#ok<AGROW>
end
plan(end + 1, 1) = step("bridge", "bridge", NaN, "", "", "bridge", strings(1, 0), "tutorial_end");
end

function s = step(kind, name, level, mousePose, reveal, prompt, before, after)
s = struct('kind', string(kind), 'name', string(name), 'level', level, ...
    'mousePose', string(mousePose), 'reveal', string(reveal), 'prompt', string(prompt), ...
    'markersBefore', before, 'markersAfter', after);
end
