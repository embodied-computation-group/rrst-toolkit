function result = kidsMain(cfg, stim, vars)
%KIDSMAIN Run one RRST-Kids session on an open device (called by runKidsRRST).
%   result = kidsMain(cfg, stim, vars)
%
%   Flow: calibrate (nobody on the tube) -> story -> practice with feedback ->
%   main yes/no trials with stars, cups and breaks -> sticker. Each trial: the
%   mouse scampers while the wedge moves (catch trials: level 0), the monster waits
%   ("Ready to slurp?") until the experimenter presses Space, then cfg.child.slurps
%   slurps at that level (kidsSlurpPhase: with the airflow sensor the monster drinks
%   when the child breathes, each counted slurp drains a third of the milkshake;
%   without it a timed animation; Space ends them early, x marks a bad breath), then
%   the experimenter clicks the child's answer.
%
%   Airflow: vars.flowSrc is the flow source opened by runKidsRRST (flowInlet, or
%   kidsSimFlow for mock and simulated runs); with cfg.flow.enabled it drives a
%   kidsFlow. The free practice slurps set the child's reference slurp (console line):
%   every free slurp of type end or weak (kidsReferenceSlurps), since before the
%   reference exists a small child's slurps can all be weak; free slurps are never
%   marked weak on screen (kidsSlurpPhase, io.free).
%   Breath-driven trials whose phase Space ends with no slurp counted are repeated
%   later (answer "noslurp"). A lost stream is looked for again before each trial.
%   For a simulated flow (kidsSimFlow), cfg.child.slurps breaths (25 slm, 1.3 s,
%   2.5 s apart, the first 0.5 s after Space) are scheduled before each slurp phase.
%   Per trial: tr.slurps (every slurp the detector saw), tr.shortSlurps, tr.flowLost.
%
%   Sound: kidsSound plays the rain and the cues: ready (Ready to slurp?, end of a
%   rest), mouse (wedge moving), slurp/bubbles/tryagain (slurp phase), star, cup.
%
%   Experimenter: click the face the child chose, or Left/n = easy (no),
%   Right/y = squishy (yes); the chosen face lights up for 0.5 s, x = bad breath (trial repeated later), Space = pause (wedge to
%   0), Esc = abort (wedge parked open, data saved as Aborted_).
%
%   cfg.debug.simulateChild = [alpha beta gamma lambda] answers by itself (testing);
%   cfg.debug.timeScale shortens every duration.
%
%   LSL markers (rrstMarker; no-ops unless runKidsRRST opened the stream):
%   calibration_start/end, story, practice_start (each round), main_start, and per
%   trial trial_<n>_level_<x> (move confirmed; catch trials level_0), trial_<n>_go
%   (Space), slurp_<k>_onset / slurp_<k>_end_<L>_<slm> / slurp_<k>_weak|overlong
%   (kidsSlurpPhase), question (screen onset), answer_yes|answer_no|bad_breath|no_answer|pause,
%   trial_<n>_correct|wrong (answered trials: "yes" on a load or "no" on a catch is
%   correct); rest_start/end; aborted (Esc or error) or done. n counts every trial
%   run, free slurps and repeats included, so each n is unique; it is tr.n.

ts = cfg.debug.timeScale;
txt = kidsText(cfg.text.language);
result = struct('outcome', "", 'trials', [], 'practice', [], 'flags', [], 'kp', []);
trials = struct('n', {}, 'phase', {}, 'level', {}, 'isCatch', {}, 'proposed', {}, 'limited', {}, ...
    'answer', {}, 'response', {}, 'rt', {}, 'moveT', {}, 'slurpT', {}, 'tStart', {}, ...
    'slurps', {}, 'shortSlurps', {}, 'flowLost', {});
practice = trials;
kp = kidsProcedure(cfg, vars.seed);
src = [];
if isfield(vars, 'flowSrc')
    src = vars.flowSrc;
    vars = rmfield(vars, 'flowSrc');                  % a handle: not saved with the data
end
fl = [];
if cfg.flow.enabled
    if isempty(src)
        error('rrst:noFlowSource', ['cfg.flow.enabled is true but no airflow source was ' ...
            'passed (vars.flowSrc). Start the task with runKidsRRST.']);
    end
    fl = kidsFlow(src, cfg.flow);
end
snd = [];
KbName('UnifyKeyNames');
keys = struct('no', KbName({'LeftArrow', 'n'}), 'yes', KbName({'RightArrow', 'y'}), ...
    'bad', KbName('x'), 'pause', KbName('space'), 'abort', KbName('ESCAPE'), 'go', KbName('space'));
sim = cfg.debug.simulateChild;
rs = RandStream('mt19937ar', 'Seed', vars.seed);
t0 = GetSecs;
nRun = 0;                                    % trials run so far (marker and tr.n)

try
    scr = openScreen(cfg);
    progress = struct('stars', 0, 'cupsDone', 0, 'nCups', ceil((cfg.child.numPsiTrials + cfg.child.numCatchTrials) / 10));

    show(scr, struct('straw', false, 'text', txt.calibrating), progress);
    rrstMarker('calibration_start');
    stim.calibrate();
    rrstMarker('calibration_end');
    stim.rest();
    snd = kidsSound(cfg.noise, cfg.sound);           % rain loop and cue sounds

    % Story
    rrstMarker('story', show(scr, struct('mouseX', 0.9, 'text', txt.story), progress));
    if waitGo(), finish("aborted"); return; end

    % Practice
    passed = false;
    for round = 1:cfg.practice.maxRounds
        rrstMarker('practice_start');
        nCorrect = 0; mustOk = true;
        freeSlurps = [];
        for i = 1:numel(cfg.practice.levels)
            level = cfg.practice.levels(i);
            free = i <= cfg.practice.nFree;
            info = struct('isCatch', level == 0, 'proposed', NaN, 'limited', false, 'xIndex', NaN);
            [tr, status] = runTrial(level, info, ~free, progress);
            if status == "abort", finish("aborted"); return; end
            if free
                if status == "free", freeSlurps = [freeSlurps; tr.slurps(:)]; end %#ok<AGROW>
                if i == cfg.practice.nFree, setReference(freeSlurps); end
                continue
            end
            if status ~= "answered", continue; end
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
    rrstMarker('main_start', show(scr, struct('mouseX', 0.9, 'text', txt.ready), progress));
    playCue("ready");
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
                if reward(progress) == "abort", finish("aborted"); return; end
                if progress.stars == 10
                    progress.cupsDone = progress.cupsDone + 1;
                    if dance(progress) == "abort", finish("aborted"); return; end
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
    try, rrstMarker('aborted'); catch, end
    try, stim.park(); catch, end
    closeSound();
    sca; ShowCursor; Priority(0);
    result = pack("error");
    result.error = getReport(err, 'extended', 'hyperlinks', 'off');
    kidsSave(cfg, vars, stim, result);
    rethrow(err);
end

    % --- nested helpers (share the session state) -------------------------

    function [tr, status] = runTrial(level, info, ask, prog)
        kidsCheckLevel(level, cfg);
        nRun = nRun + 1;
        tr = struct('n', nRun, 'phase', "", 'level', level, ...
            'isCatch', info.isCatch, 'proposed', info.proposed, 'limited', info.limited, ...
            'answer', "", 'response', NaN, 'rt', NaN, 'moveT', NaN, 'slurpT', NaN, 'tStart', GetSecs - t0, ...
            'slurps', [], 'shortSlurps', false, 'flowLost', false);
        % Move: the mouse scampers while the wedge goes to the level
        tMove = GetSecs;
        show(scr, struct('mouseX', 0.1, 'straw', false), prog);
        playCue("mouse");
        if level == 0, mv = stim.null(); else, mv = stim.present(level); end
        rrstMarker(kidsMarkerLabel("level", tr.n, level));   % move confirmed (as the adult task)
        tr.moveT = mv.elapsed;
        status = animate(cfg.timing.moveMin - (GetSecs - tMove), @(p) struct('mouseX', 0.1 + 0.8 * p, 'straw', false), prog);
        if status ~= "", return; end
        % A lost airflow stream: look for it again before the child is asked to slurp
        if ~isempty(fl) && fl.lost && ismethod(src, 'reconnect')
            if src.reconnect(0.5), fprintf('Airflow stream is back.\n'); end
        end
        % The experimenter starts the slurps when the child is ready (Space)
        show(scr, struct('text', txt.cue), prog);
        playCue("ready");
        if waitGo(), status = "abort"; return; end
        rrstMarker(kidsMarkerLabel("go", tr.n));
        % Slurps at this level (kidsSlurpPhase): breath-driven with the sensor, else timed
        if isa(src, 'kidsSimFlow')                     % simulated flow: the child breathes
            src.quiet();
            src.breathe(25, 1.3, cfg.child.slurps, 2.5, 0.5);
        end
        io = struct('draw', @(s) show(scr, s, prog), 'keys', @phaseKeys, 'now', @GetSecs, ...
            'marker', @(label, t) rrstMarker(label, t), 'sound', @playCue, ...
            'prompt', @(msg) fprintf('%s\n', msg), 'sim', ~isempty(sim), 'free', ~ask);
        [status, tr.slurps, sInfo] = kidsSlurpPhase(fl, cfg, io);
        tr.slurpT = sInfo.durationS;
        tr.shortSlurps = sInfo.shortSlurps;
        tr.flowLost = sInfo.flowLost;
        if isempty(sim) && status ~= "done", waitRelease(); end
        switch status
            case "abort"
                return
            case "bad"                                  % x: repeat this trial type later
                tr.answer = "bad";
                rrstMarker(kidsMarkerLabel("answer", "bad"));
                status = "repeat";
                return
            case "skip"
                breathDriven = ~isempty(fl) && cfg.flow.feedback == "breath" && ~sInfo.flowLost;
                if breathDriven && sInfo.counted == 0 && ask
                    fprintf('No slurp counted: this trial is repeated later.\n');
                    tr.answer = "noslurp";
                    status = "repeat";
                    return
                end
        end
        status = "";
        if ~ask
            status = "free"; return
        end
        % Question: the experimenter clicks the child's answer
        kidsQuestion(scr, txt); rrstMarker('question', Screen('Flip', scr.win));
        [answer, rt, tAnswer] = getAnswer(level);
        tr.answer = answer; tr.rt = rt;
        label = kidsMarkerLabel("answer", answer);
        if ~isempty(label), rrstMarker(label, tAnswer); end
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
        if status == "answered"
            rrstMarker(kidsMarkerLabel("outcome", tr.n, level, tr.response), tAnswer);
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

    function [answer, rt, tAnswer] = getAnswer(level)
        % tAnswer: GetSecs time the answer was registered (for its marker)
        tStart = GetSecs;
        if ~isempty(sim)
            pauseFor(0.4);
            if rand(rs) < PAL_Weibull(sim, level), answer = "yes"; else, answer = "no"; end
            kidsQuestion(scr, txt, answer, true); Screen('Flip', scr.win);
            rt = GetSecs - tStart; tAnswer = tStart + rt; return
        end
        waitRelease();
        ShowCursor('Hand', scr.screenID);
        answer = "none";
        while GetSecs - tStart < cfg.timing.response * ts
            [down, ~, code] = KbCheck;
            [mx, ~, buttons] = GetMouse(scr.win);
            side = kidsClickAnswer(mx, scr.winRect(3));
            if down && any(code(keys.abort)), answer = "abort";
            elseif down && any(code(keys.yes)), answer = "yes";
            elseif down && any(code(keys.no)), answer = "no";
            elseif any(buttons), answer = side;         % "none" in the middle strip: keep waiting
            elseif down && any(code(keys.bad)), answer = "bad";
            elseif down && any(code(keys.pause)), answer = "pause";
            end
            if answer ~= "none", break; end
            kidsQuestion(scr, txt, side); Screen('Flip', scr.win);
        end
        rt = GetSecs - tStart; tAnswer = tStart + rt;
        HideCursor(scr.screenID);
        if ismember(answer, ["yes" "no"])                 % show what was registered
            kidsQuestion(scr, txt, answer, true); Screen('Flip', scr.win);
            WaitSecs(0.5);
        end
        waitRelease();
    end

    function status = reward(prog)
        playCue("star");
        status = animate(cfg.timing.reward, @(p) struct('cup', 0, 'wiggle', 15 * sin(p * 4 * pi), 'text', txt.star), prog);
    end

    function status = dance(prog)
        playCue("cup");
        status = animate(cfg.timing.dance, @(p) struct('cup', 0, 'wiggle', 40 * sin(p * 8 * pi), 'belly', 0.5 + 0.5 * sin(p * 6 * pi), 'text', txt.cupDone), prog);
    end

    function aborted = rest(prog)
        tStart = GetSecs;
        rrstMarker('rest_start', tStart);
        while GetSecs - tStart < cfg.timing.pause * ts
            show(scr, struct('cup', 1, 'straw', false, 'text', sprintf(txt.rest, ceil(cfg.timing.pause * ts - (GetSecs - tStart)))), prog);
            [down, ~, code] = KbCheck;
            if down && any(code(keys.abort)), aborted = true; return; end
        end
        show(scr, struct('mouseX', 0.9, 'text', txt.ready), prog);
        playCue("ready");
        aborted = waitGo();
        if ~aborted, rrstMarker('rest_end'); end    % experimenter's Space: trials resume
    end

    function k = phaseKeys()
        % Keys during the slurp phase: Esc abort, x bad breath, Space skip.
        k = "";
        [down, ~, code] = KbCheck;
        if ~down, return; end
        if any(code(keys.abort)), k = "abort";
        elseif any(code(keys.bad)), k = "bad";
        elseif any(code(keys.go)), k = "skip";
        end
    end

    function playCue(name)
        if ~isempty(snd), snd.play(name); end
    end

    function closeSound()
        if ~isempty(snd), snd.close(); end
        snd = [];
    end

    function setReference(s)
        % The child's reference slurp from every free slurp of type end or weak
        % (kidsReferenceSlurps; plan section 3.2). kidsFlow clamps it to [0.15, 2] L.
        if isempty(fl), return; end
        s = kidsReferenceSlurps(s);
        if isempty(s)
            [minL, fullL] = fl.setReference([]);
            fprintf(2, ['No free slurp detected: the reference stays at %.2f L. Belly full at ' ...
                '%.2f L; a slurp counts above %.2f L. Check the mouthpiece.\n'], fl.refVolume, fullL, minL);
        else
            [minL, fullL] = fl.setReference([s.volumeL]);
            fprintf(['Reference slurp %.2f L (median of %d free slurps: %.2f L), peak %.0f slm. ' ...
                'Belly full at %.2f L; a slurp counts above %.2f L.\n'], ...
                fl.refVolume, numel(s), median([s.volumeL]), median([s.peakSlm]), fullL, minL);
        end
    end

    function tFlip = show(scrIn, s, prog)
        % Draw the scene and flip; tFlip is the flip's onset (GetSecs time).
        s.stars = prog.stars; s.cupsDone = prog.cupsDone; s.nCups = prog.nCups;
        kidsScene(scrIn, s);
        tFlip = Screen('Flip', scrIn.win);
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
            GetMouse;                    % keeps the window responsive (KbCheck alone lets Windows grey it out)
            WaitSecs(0.001);
        end
        waitRelease();
    end

    function waitRelease()
        while KbCheck, GetMouse; end
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
        if outcome == "aborted", rrstMarker('aborted'); else, rrstMarker('done'); end
        stim.park();
        closeSound();
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
    'cardEasy', [1 0.96 0.88], 'cardSquishy', [0.94 0.88 1]);
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
