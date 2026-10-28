function result = kidsMain(cfg, stim, vars)
%KIDSMAIN Run one RRST-Kids session on an open device (called by runKidsRRST).
%   result = kidsMain(cfg, stim, vars)
%
%   Flow: calibrate (nobody on the tube) -> story -> practice with feedback ->
%   main yes/no trials with stars, cups and breaks -> sticker. Each trial: the
%   mouse scampers while the wedge moves (catch trials: level 0), the straw drops
%   in, the belly grows (inhale) and shrinks with bubbles (exhale), then the
%   experimenter clicks the child's answer.
%
%   Experimenter keys: Left/n/left click = easy (no), Right/y/right click =
%   squishy (yes), x = bad breath (trial repeated later), Space = pause (wedge to
%   0), Esc = abort (wedge parked open, data saved as Aborted_).
%
%   cfg.debug.simulateChild = [alpha beta gamma lambda] answers by itself (testing);
%   cfg.debug.timeScale shortens every duration.

ts = cfg.debug.timeScale;
txt = kidsText(cfg.text.language);
result = struct('outcome', "", 'trials', [], 'practice', [], 'flags', [], 'kp', []);
trials = struct('n', {}, 'phase', {}, 'level', {}, 'isCatch', {}, 'proposed', {}, 'limited', {}, ...
    'answer', {}, 'response', {}, 'rt', {}, 'moveT', {}, 'tStart', {});
practice = trials;
kp = kidsProcedure(cfg, vars.seed);
noise = [];
KbName('UnifyKeyNames');
keys = struct('no', KbName({'LeftArrow', 'n'}), 'yes', KbName({'RightArrow', 'y'}), ...
    'bad', KbName('x'), 'pause', KbName('space'), 'abort', KbName('ESCAPE'), 'go', KbName('space'));
sim = cfg.debug.simulateChild;
rs = RandStream('mt19937ar', 'Seed', vars.seed);
t0 = GetSecs;

try
    scr = openScreen(cfg);
    progress = struct('stars', 0, 'cupsDone', 0, 'nCups', ceil((cfg.child.numPsiTrials + cfg.child.numCatchTrials) / 10));

    show(scr, struct('straw', false, 'text', txt.calibrating), progress);
    stim.calibrate();
    stim.rest();
    if cfg.noise.enabled
        noise = startMaskingNoise(cfg.noise);
    end

    % Story
    show(scr, struct('mouseX', 0.5, 'text', txt.story), progress);
    if waitGo(), finish("aborted"); return; end

    % Practice
    passed = false;
    for round = 1:cfg.practice.maxRounds
        nCorrect = 0; mustOk = true;
        for i = 1:numel(cfg.practice.levels)
            level = cfg.practice.levels(i);
            free = i <= cfg.practice.nFree;
            info = struct('isCatch', level == 0, 'proposed', NaN, 'limited', false, 'xIndex', NaN);
            [tr, status] = runTrial(level, info, ~free, progress);
            if status == "abort", finish("aborted"); return; end
            if free || status ~= "answered", continue; end
            tr.phase = "practice";
            practice(end + 1) = tr; %#ok<AGROW>
            correct = tr.response == (level > 0);
            nCorrect = nCorrect + correct;
            if ismember(level, cfg.practice.mustPass) && ~correct, mustOk = false; end
            if level > 0, fb = txt.yesFeedback; else, fb = txt.noFeedback; end   % the truth, every time
            show(scr, struct('cup', 0, 'text', fb), progress); pauseFor(1.5);
        end
        if nCorrect >= cfg.practice.passMin && mustOk
            passed = true; break
        end
    end
    if ~passed
        show(scr, struct('text', txt.thanks), progress); pauseFor(3);
        finish("practiceFailed"); return
    end

    % Main trials
    show(scr, struct('mouseX', 0.5, 'text', txt.ready), progress);
    if waitGo(), finish("aborted"); return; end
    nAnswered = 0;
    while ~kidsShouldStop(kp, cfg)
        [level, info] = kidsNextLevel(kp, cfg);
        [tr, status] = runTrial(level, info, true, progress);
        switch status
            case "abort"
                finish("aborted"); return
            case "answered"
                tr.phase = "main";
                trials(end + 1) = tr; %#ok<AGROW>
                kp = kidsRecord(kp, level, tr.response, info);
                nAnswered = nAnswered + 1;
                progress.stars = progress.stars + 1;
                reward(progress);
                if progress.stars == 10
                    progress.cupsDone = progress.cupsDone + 1;
                    dance(progress);
                    progress.stars = 0;
                end
                if mod(nAnswered, cfg.timing.pauseEvery) == 0 && ~kidsShouldStop(kp, cfg)
                    if rest(progress), finish("aborted"); return; end
                end
            otherwise   % no answer, bad breath or pause: repeat this trial type later
                tr.phase = "repeat";
                trials(end + 1) = tr; %#ok<AGROW>
                kp = kidsRequeue(kp);
        end
        stim.rest();
    end
    show(scr, struct('cup', 0, 'text', txt.sticker), progress); pauseFor(3);
    [~, why] = kidsShouldStop(kp, cfg);
    finish("complete:" + why);
catch err
    try, stim.park(); catch, end
    stopMaskingNoise(noise); noise = [];
    sca; ShowCursor; Priority(0);
    result = pack("error");
    result.error = getReport(err, 'extended', 'hyperlinks', 'off');
    kidsSave(cfg, vars, stim, result);
    rethrow(err);
end

    % --- nested helpers (share the session state) -------------------------

    function [tr, status] = runTrial(level, info, ask, prog)
        kidsCheckLevel(level, cfg);
        tr = struct('n', numel(trials) + numel(practice) + 1, 'phase', "", 'level', level, ...
            'isCatch', info.isCatch, 'proposed', info.proposed, 'limited', info.limited, ...
            'answer', "", 'response', NaN, 'rt', NaN, 'moveT', NaN, 'tStart', GetSecs - t0);
        % Move: the mouse scampers while the wedge goes to the level
        tMove = GetSecs;
        show(scr, struct('mouseX', 0.1, 'straw', false), prog);
        if level == 0, mv = stim.null(); else, mv = stim.present(level); end
        tr.moveT = mv.elapsed;
        status = animate(cfg.timing.moveMin - (GetSecs - tMove), @(p) struct('mouseX', 0.1 + 0.8 * p, 'straw', false), prog);
        if status ~= "", return; end
        % Cue, inhale, exhale
        status = animate(cfg.timing.cue, @(p) struct('text', txt.cue), prog);
        if status ~= "", return; end
        status = animate(cfg.timing.inhale, @(p) struct('belly', p, 'cup', 1 - p, 'text', txt.inhale), prog);
        if status ~= "", return; end
        status = animate(cfg.timing.exhale, @(p) struct('belly', 1 - p, 'cup', 0, 'bubbles', p, 'text', txt.exhale), prog);
        if status ~= "", return; end
        if ~ask
            status = "free"; return
        end
        % Question: the experimenter clicks the child's answer
        kidsQuestion(scr, txt); Screen('Flip', scr.win);
        [answer, rt] = getAnswer(level);
        tr.answer = answer; tr.rt = rt;
        switch answer
            case "yes", tr.response = 1; status = "answered";
            case "no",  tr.response = 0; status = "answered";
            case "abort", status = "abort";
            case "pause"
                stim.null();
                show(scr, struct('cup', 0, 'text', txt.pause), prog);
                if waitGo(), status = "abort"; else, status = "repeat"; end
            otherwise, status = "repeat";            % "bad" or "none"
        end
    end

    function status = animate(dur, sceneAt, prog)
        % Frame loop for dur seconds; returns "abort" if Esc is pressed.
        status = "";
        dur = max(dur, 0) * ts;
        tStart = GetSecs;
        while true
            p = min((GetSecs - tStart) / max(dur, eps), 1);
            show(scr, sceneAt(p), prog);
            [down, ~, code] = KbCheck;
            if down && any(code(keys.abort)), status = "abort"; return; end
            if p >= 1, return; end
        end
    end

    function [answer, rt] = getAnswer(level)
        tStart = GetSecs;
        if ~isempty(sim)
            pauseFor(0.4);
            if rand(rs) < PAL_Weibull(sim, level), answer = "yes"; else, answer = "no"; end
            rt = GetSecs - tStart; return
        end
        waitRelease();
        answer = "none";
        while GetSecs - tStart < cfg.timing.response * ts
            [down, ~, code] = KbCheck;
            [~, ~, buttons] = GetMouse;
            if down && any(code(keys.abort)), answer = "abort";
            elseif (down && any(code(keys.yes))) || (numel(buttons) >= 3 && buttons(3)), answer = "yes";
            elseif (down && any(code(keys.no))) || buttons(1), answer = "no";
            elseif down && any(code(keys.bad)), answer = "bad";
            elseif down && any(code(keys.pause)), answer = "pause";
            end
            if answer ~= "none", break; end
        end
        rt = GetSecs - tStart;
        waitRelease();
    end

    function reward(prog)
        animate(cfg.timing.reward, @(p) struct('cup', 0, 'wiggle', 15 * sin(p * 4 * pi), 'text', txt.star), prog);
    end

    function dance(prog)
        animate(cfg.timing.dance, @(p) struct('cup', 0, 'wiggle', 40 * sin(p * 8 * pi), 'belly', 0.5 + 0.5 * sin(p * 6 * pi), 'text', txt.cupDone), prog);
    end

    function aborted = rest(prog)
        tStart = GetSecs;
        while GetSecs - tStart < cfg.timing.pause * ts
            show(scr, struct('cup', 1, 'straw', false, 'text', sprintf(txt.rest, ceil(cfg.timing.pause * ts - (GetSecs - tStart)))), prog);
        end
        show(scr, struct('mouseX', 0.5, 'text', txt.ready), prog);
        aborted = waitGo();
    end

    function show(scrIn, s, prog)
        s.stars = prog.stars; s.cupsDone = prog.cupsDone; s.nCups = prog.nCups;
        kidsScene(scrIn, s);
        Screen('Flip', scrIn.win);
    end

    function aborted = waitGo()
        % Experimenter presses Space to go on; Esc returns true (abort).
        aborted = false;
        if ~isempty(sim), pauseFor(0.3); return; end
        waitRelease();
        while true
            [down, ~, code] = KbCheck;
            if down && any(code(keys.go)), break; end
            if down && any(code(keys.abort)), aborted = true; break; end
        end
        waitRelease();
    end

    function waitRelease()
        while KbCheck, end
        [~, ~, b] = GetMouse;
        while any(b), [~, ~, b] = GetMouse; end
    end

    function pauseFor(s)
        WaitSecs(s * ts);
    end

    function r = pack(outcome)
        r = struct('outcome', string(outcome), 'trials', trials, 'practice', practice, ...
            'flags', [], 'kp', kp, 'duration', GetSecs - t0);
        if ~isempty(kp.history), r.flags = kidsFlags(kp, cfg); end
    end

    function finish(outcome)
        stim.park();
        stopMaskingNoise(noise); noise = [];
        sca; ShowCursor; Priority(0);
        result = pack(outcome);
        kidsSave(cfg, vars, stim, result);
    end
end

function scr = openScreen(cfg)
scr.screenID = max(Screen('Screens'));
scr.colours = struct('background', [0.55 0.82 0.95], 'monster', [150 80 200] / 255, ...
    'monsterDark', [110 55 160] / 255, 'belly', [200 160 235] / 255, 'mouth', [0.25 0.05 0.2], ...
    'shake', [1 0.6 0.75], 'straw', [1 0.95 0.5], 'bubble', [1 1 1], 'mouse', [0.6 0.6 0.62], ...
    'mouseEar', [1 0.7 0.75], 'star', [1 0.82 0.1], 'slot', [1 1 1], 'text', [0.1 0.1 0.25], ...
    'easy', [0.3 0.75 0.4], 'squishy', [0.9 0.35 0.35]);
PsychImaging('PrepareConfiguration');
if cfg.smallWindow
    r = Screen('Rect', scr.screenID);
    [scr.win, scr.winRect] = PsychImaging('OpenWindow', scr.screenID, scr.colours.background, [0 0 r(3) r(4)] / 3);
else
    [scr.win, scr.winRect] = PsychImaging('OpenWindow', scr.screenID, scr.colours.background);
end
Screen('ColorRange', scr.win, 1);
Screen('BlendFunction', scr.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
Screen('TextFont', scr.win, 'Arial');
Screen('TextSize', scr.win, round(cfg.visual.textSize * scr.winRect(4) / 1440));
Priority(MaxPriority(scr.win));
end
