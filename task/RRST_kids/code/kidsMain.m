function result = kidsMain(cfg, stim, vars)
%KIDSMAIN Run one RRST-Kids session on an open device (called by runKidsRRST).
%   result = kidsMain(cfg, stim, vars)
%
%   Flow: calibrate (nobody on the tube) -> story -> tutorial -> practice with
%   feedback -> main yes/no trials with stars, cups and breaks -> sticker. Each trial: the
%   mouse scampers while the wedge moves (catch trials: level 0), the monster waits
%   ("Ready to slurp?") until the experimenter presses Space, then cfg.child.slurps
%   slurps at that level (kidsSlurpPhase: with the airflow sensor the monster drinks
%   when the child breathes, each counted slurp drains a third of the milkshake;
%   without it a timed animation; Space ends them early, x marks a bad breath), then
%   the experimenter clicks the child's answer.
%
%   Tutorial (cfg.tutorial, kidsTutorialPlan): free play at level 0 (kidsFreePlay:
%   the child slurps as often as they like, Space ends it after a slurp or when held
%   1 s), then the demos with no question (the mouse pinching the straw during the
%   slurps at cfg.tutorial.pinchLevel, then asleep at 0, each followed by its
%   reveal), then the answer cards for the experimenter to explain (Space). Its
%   trials are saved in result.practice with phase "tutorial" and answer "freeplay",
%   "demo_pinch" or "demo_sleep". With the tutorial off, cfg.practice.nFree free
%   slurp trials open each practice round instead (the old path).
%
%   Airflow: vars.flowSrc is the flow source opened by runKidsRRST (flowInlet, or
%   kidsSimFlow for mock and simulated runs); with cfg.flow.enabled it drives a
%   kidsFlow. Free play (or the free practice slurps) sets the child's reference
%   slurp (console line): every free slurp of type end or weak (kidsSetReference),
%   since before the reference exists a small child's slurps can all be weak; free
%   slurps and demo slurps are never marked weak on screen (kidsSlurpPhase, io.free).
%   Breath-driven trials whose phase Space ends with no slurp counted are repeated
%   later (answer "noslurp"). A lost stream is looked for again before each trial.
%   For a simulated flow (kidsSimFlow), cfg.child.slurps breaths (25 slm, 1.3 s,
%   2.5 s apart, the first 0.5 s after Space) are scheduled before each slurp phase,
%   and two before free play (a simulated child ends it after two).
%   Per trial: tr.slurps (every slurp the detector saw), tr.shortSlurps, tr.flowLost.
%   Standalone recording (cfg.recording.mode, kidsStandalone): runKidsRRST sets
%   src.record, and the result gets t0, flow (every sample pulled, [t flowSlm]) and
%   markers (rrstMarker('log'): every marker sent, LSL or not), all on GetSecs.
%
%   Sound: kidsSound plays the rain and the cues: ready (Ready to slurp?, end of a
%   rest), mouse (wedge moving, story beat 2, practice reveal of a pinch),
%   slurp/bubbles/tryagain (slurp phase), star, cup.
%
%   Screens: kidsBeat gives the scene, length and cue of every moment (story in three
%   beats, each held until Space; move; ready; practice reveal; star flight; cup tip
%   and celebrate; nap and stretch; sticker); kidsSlurpPhase the slurp phase's poses.
%   Every frame gets t = seconds since the session started (blink, Z's, waving) and
%   flavour = cupsDone + 1. The small bottom-left line is the experimenter's: first
%   kidsPrompt's line for the moment (what is happening, which key goes on; also
%   printed on the console, once per change), then the scene's own sentence. Each
%   practice answer and each round's outcome (passed, or why not) go to the console.
%   The tenth star's cup tip is held until Space (the sticker).
%
%   Experimenter: click the face the child chose, or Left/n = easy (no),
%   Right/y = squishy (yes); the chosen face lights up for 0.5 s, x = bad breath (trial repeated later), Space = pause (wedge to
%   0), Esc = abort (wedge parked open, data saved as Aborted_).
%
%   cfg.debug.simulateChild = [alpha beta gamma lambda] answers by itself (testing);
%   cfg.debug.timeScale shortens every duration.
%
%   LSL markers (rrstMarker; no-ops unless runKidsRRST opened the stream):
%   calibration_start/end, story, tutorial_start, freeplay_start/end,
%   demo_pinch_level_<x> and demo_sleep_level_0 (move confirmed, in place of the
%   trial's level marker), tutorial_end, practice_start (each round), main_start, and per
%   trial trial_<n>_level_<x> (move confirmed; catch trials level_0), trial_<n>_go
%   (Space), slurp_<k>_onset / slurp_<k>_end_<L>_<slm> / slurp_<k>_weak|overlong
%   (kidsSlurpPhase), question (screen onset), answer_yes|answer_no|bad_breath|no_answer|pause,
%   trial_<n>_correct|wrong (answered trials: "yes" on a load or "no" on a catch is
%   correct); rest_start/end; aborted (Esc or error) or done. n counts every trial
%   run, free play, demos, free slurps and repeats included, so each n is unique;
%   it is tr.n.

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
nMain = 0;                                   % main trials run so far (the prompt's "Trial n")
expLine = '';                                % the experimenter's line (kidsPrompt)
sceneMouse = "";                             % mouse pose forced on every scene (tutorial demos)

try
    scr = openScreen(cfg);
    progress = struct('stars', 0, 'cupsDone', 0, 'starsPerCup', 10, ...
        'nCups', ceil((cfg.child.numPsiTrials + cfg.child.numCatchTrials) / 10));

    say("calibrating");
    show(scr, kidsBeat("calibrating", 0, beatCtx(progress)), progress);
    rrstMarker('calibration_start');
    stim.calibrate();
    rrstMarker('calibration_end');
    stim.rest();
    snd = kidsSound(cfg.noise, cfg.sound);           % rain loop and cue sounds

    % Story: three beats, each held until Space (the experimenter narrates over them)
    beats = ["story1" "story2" "story3"];
    for iBeat = 1:numel(beats)
        beat = beats(iBeat);
        say("story", struct('beat', iBeat, 'nBeats', numel(beats)));
        [st, tBeat] = playBeat(beat, progress);
        if beat == "story1", rrstMarker('story', tBeat); end
        if st == "abort" || holdBeat(beat, progress), finish("aborted"); return; end
    end

    % Tutorial: free play, the demos (pinch, sleep), the answer cards
    if tutorial(progress), finish("aborted"); return; end

    % Practice
    passed = false;
    for iRound = 1:cfg.practice.maxRounds
        rrstMarker('practice_start');
        nFree = cfg.practice.nFree;
        nAsk = numel(cfg.practice.levels) - nFree;
        fprintf(['Practice round %d of %d: %d trials, the truth shown after each answer. ' ...
            'Pass: %d correct, and every trial at %s right.\n'], iRound, cfg.practice.maxRounds, ...
            nAsk, cfg.practice.passMin, strjoin(string(unique(cfg.practice.mustPass)), ', '));
        nCorrect = 0; mustOk = true; missed = strings(0, 1);
        freeSlurps = [];
        for i = 1:numel(cfg.practice.levels)
            level = cfg.practice.levels(i);
            free = i <= nFree;
            info = struct('isCatch', level == 0, 'proposed', NaN, 'limited', false, 'xIndex', NaN);
            if free
                pr = struct('phase', "free", 'k', i, 'n', nFree);
            else
                pr = struct('phase', "practice", 'k', i - nFree, 'n', nAsk);
            end
            [tr, status] = runTrial(level, info, ~free, progress, pr);
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
            verdict = ["wrong" "correct"];
            fprintf('Practice %d of %d: level %g, answered %s: %s.\n', pr.k, pr.n, level, ...
                answerWord(tr.response), verdict(correct + 1));
            if ismember(level, cfg.practice.mustPass) && ~correct
                mustOk = false;
                missed(end + 1) = sprintf('level %g wrong (practice %d)', level, pr.k); %#ok<AGROW>
            end
            % the truth, every time: the mouse pinching (load) or asleep (catch)
            say("reveal", struct('phase', "practice"));
            if playBeat("reveal", progress, level) == "abort", finish("aborted"); return; end
        end
        passed = nCorrect >= cfg.practice.passMin && mustOk;
        if passed
            fprintf('Practice round %d PASSED: %d of %d correct.\n', iRound, nCorrect, nAsk);
            break
        end
        why = missed;
        if nCorrect < cfg.practice.passMin
            why = [sprintf("only %d correct, %d needed", nCorrect, cfg.practice.passMin); why]; %#ok<AGROW>
        end
        fprintf(2, 'Practice round %d NOT PASSED: %d of %d correct; %s.%s\n', iRound, nCorrect, nAsk, ...
            strjoin(why, '; '), ifelse(iRound < cfg.practice.maxRounds, ' Practice runs again.', ''));
    end
    if ~passed
        say("thanks");
        playBeat("thanks", progress);
        finish("practiceFailed"); return
    end

    % Main trials
    say("mainStart");
    if readyScreen(progress, 'main_start'), finish("aborted"); return; end
    nAnswered = 0;
    while ~kidsShouldStop(kp, cfg)
        [level, info] = kidsNextLevel(kp, cfg);
        nMain = nMain + 1;
        [tr, status] = runTrial(level, info, true, progress, struct('phase', "main", 'n', nMain));
        switch status
            case "abort"
                finish("aborted"); return
            case "answered"
                tr.phase = "main";
                trials(end + 1) = tr; %#ok<AGROW>
                kp = kidsRecord(kp, level, tr.response, info);
                nAnswered = nAnswered + 1;
                % the star flies to its slot, then it counts; the tenth tips the cup
                say("reward");
                if playBeat("star", progress) == "abort", finish("aborted"); return; end
                progress.stars = progress.stars + 1;
                if progress.stars == progress.starsPerCup
                    % the cup tips and the monster dances; held until Space (sticker)
                    say("cup");
                    if playBeat("cup", progress) == "abort" || holdBeat("cup", progress)
                        finish("aborted"); return
                    end
                    progress.cupsDone = progress.cupsDone + 1;
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
    say("done");
    playBeat("sticker", progress);
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

    function [tr, status] = runTrial(level, info, ask, prog, pr)
        % pr: the prompt's trial info (kidsPrompt "ready" and "slurps": phase, k, n)
        kidsCheckLevel(level, cfg);
        nRun = nRun + 1;
        tr = struct('n', nRun, 'phase', "", 'level', level, ...
            'isCatch', info.isCatch, 'proposed', info.proposed, 'limited', info.limited, ...
            'answer', "", 'response', NaN, 'rt', NaN, 'moveT', NaN, 'slurpT', NaN, 'tStart', GetSecs - t0, ...
            'slurps', [], 'shortSlurps', false, 'flowLost', false);
        % Move: the mouse scampers while the wedge goes to the level (the same
        % picture for catch and load trials: kidsBeat "move" has no level)
        tMove = GetSecs;
        c = beatCtx(prog);
        say("move");
        [s, ~, cue] = kidsBeat("move", 0, c);
        show(scr, s, prog);
        playCue(cue);
        if level == 0, mv = stim.null(); else, mv = stim.present(level); end
        if isfield(pr, 'marker')                           % tutorial demo: demo_<name>_level_<x>
            rrstMarker(char(pr.marker));
        else
            rrstMarker(kidsMarkerLabel("level", tr.n, level));   % move confirmed (as the adult task)
        end
        tr.moveT = mv.elapsed;
        status = animate(cfg.timing.moveMin - (GetSecs - tMove), @(p) kidsBeat("move", p, c), prog);
        if status ~= "", return; end
        % A lost airflow stream: look for it again before the child is asked to slurp
        if ~isempty(fl) && fl.lost && ismethod(src, 'reconnect')
            if src.reconnect(0.5), fprintf('Airflow stream is back.\n'); end
        end
        % The experimenter starts the slurps when the child is ready (Space)
        if pr.phase == "demo"
            say("demo", pr);
            sceneMouse = pr.mousePose;              % the mouse pinching or asleep, until the reveal
        else
            say("ready", pr);
        end
        if readyScreen(prog), status = "abort"; return; end
        rrstMarker(kidsMarkerLabel("go", tr.n));
        pr.slurps = cfg.child.slurps;
        say("slurps", pr);
        % Slurps at this level (kidsSlurpPhase): breath-driven with the sensor, else timed
        if isa(src, 'kidsSimFlow')                     % simulated flow: the child breathes
            src.quiet();
            src.breathe(25, 1.3, cfg.child.slurps, 2.5, 0.5);
        end
        io = struct('draw', @(s) show(scr, s, prog), 'keys', @phaseKeys, 'now', @GetSecs, ...
            'marker', @(label, t) rrstMarker(label, t), 'sound', @playCue, ...
            'prompt', @(msg) fprintf('%s\n', msg), 'sim', ~isempty(sim), 'free', ~ask, ...
            'label', ifelse(pr.phase == "demo", 'Demo slurp', 'Free slurp'));
        [status, tr.slurps, sInfo] = kidsSlurpPhase(fl, cfg, io);
        sceneMouse = "";
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
        say("question");
        drawQuestion(); rrstMarker('question', Screen('Flip', scr.win));
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
                say("pause");
                show(scr, kidsBeat("pause", 0, beatCtx(prog)), prog);
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
            drawQuestion(answer, true); Screen('Flip', scr.win);
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
            drawQuestion(side); Screen('Flip', scr.win);
        end
        rt = GetSecs - tStart; tAnswer = tStart + rt;
        HideCursor(scr.screenID);
        if ismember(answer, ["yes" "no"])                 % show what was registered
            drawQuestion(answer, true); Screen('Flip', scr.win);
            WaitSecs(0.5);
        end
        waitRelease();
    end

    function [status, tFlip] = playBeat(name, prog, level)
        % One beat (kidsBeat) from its start: first frame, its cue, its animation.
        % status "abort" on Esc; tFlip: the first frame's flip time.
        if nargin < 3, level = NaN; end
        c = beatCtx(prog, level);
        [s, dur, cue] = kidsBeat(name, 0, c);
        tFlip = show(scr, s, prog);
        playCue(cue);
        status = animate(dur, @(p) kidsBeat(name, p, c), prog);
    end

    function aborted = holdBeat(name, prog, level)
        % Hold a beat's last frame (still animated by t) until Space; true on Esc.
        if nargin < 3, level = NaN; end
        c = beatCtx(prog, level);
        aborted = waitGo(@() show(scr, kidsBeat(name, 1, c), prog));
    end

    function aborted = readyScreen(prog, marker)
        % "Ready to slurp?" with the ready cue, until the experimenter's Space.
        c = beatCtx(prog);
        [s, ~, cue] = kidsBeat("ready", 0, c);
        tFlip = show(scr, s, prog);
        if nargin > 1, rrstMarker(marker, tFlip); end
        playCue(cue);
        aborted = holdBeat("ready", prog);
    end

    function c = beatCtx(prog, level)
        if nargin < 2, level = NaN; end
        c = struct('stars', prog.stars, 'cupsDone', prog.cupsDone, 'nCups', prog.nCups, ...
            'txt', txt, 'timing', cfg.timing, 'level', level);
    end

    function aborted = rest(prog)
        % A nap (the bar drains), a stretch, then the ready screen.
        rrstMarker('rest_start', GetSecs);
        say("rest", struct('restS', cfg.timing.pause));
        aborted = playBeat("nap", prog) == "abort" || playBeat("stretch", prog) == "abort";
        if aborted, return; end
        aborted = readyScreen(prog);
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

    function say(moment, info)
        % The experimenter's line for this moment (kidsPrompt): drawn first in the
        % small bottom-left line of every screen from now on, and printed once.
        if nargin < 2, info = struct(); end
        line = kidsPrompt(moment, info);
        if ~strcmp(line, expLine), fprintf('>> %s\n', line); end
        expLine = line;
    end

    function drawQuestion(varargin)
        % The answer screen (kidsQuestion) with the experimenter's line; no Flip.
        kidsQuestion(scr, txt, varargin{:});
        if isempty(expLine), return; end
        base = Screen('TextSize', scr.win);
        H = scr.winRect(4) - scr.winRect(2); W = scr.winRect(3) - scr.winRect(1);
        Screen('TextSize', scr.win, max(10, round(0.6 * base)));
        DrawFormattedText(scr.win, expLine, 0.02 * W, 0.975 * H - 0.7 * base, ...
            0.55 * scr.colours.text + 0.45 * [0.85 0.85 0.85]);
        Screen('TextSize', scr.win, base);
    end

    function playCue(name)
        if ~isempty(snd) && name ~= "", snd.play(name); end
    end

    function closeSound()
        if ~isempty(snd), snd.close(); end
        snd = [];
    end

    function setReference(s)
        % The child's reference slurp from every free slurp of type end or weak
        % (kidsSetReference; plan section 3.2). kidsFlow clamps it to [0.15, 2] L.
        if isempty(fl), return; end
        [msg, found] = kidsSetReference(fl, s);
        if found, fprintf('%s\n', msg); else, fprintf(2, '%s\n', msg); end
    end

    function aborted = tutorial(prog)
        % The intro tutorial (kidsTutorialPlan): free play, the demos, the bridge.
        % Its trials go to practice with phase "tutorial". true on Esc.
        aborted = false;
        tutPlan = kidsTutorialPlan(cfg);
        for iStep = 1:numel(tutPlan)
            step = tutPlan(iStep);
            switch step.kind
                case "freeplay"
                    aborted = freePlay(step, prog);
                case "demo"
                    dInfo = struct('isCatch', step.level == 0, 'proposed', NaN, 'limited', false, 'xIndex', NaN);
                    dPr = struct('phase', "demo", 'demo', step.name, 'marker', step.markersBefore, ...
                        'mousePose', step.mousePose);
                    [dTr, dStatus] = runTrial(step.level, dInfo, false, prog, dPr);
                    if dStatus == "abort", aborted = true; return; end
                    dTr.phase = "tutorial";
                    dTr.answer = "demo_" + step.name;
                    practice(end + 1) = dTr;
                    say("reveal", struct('phase', "demo"));
                    aborted = playBeat("reveal", prog, step.level) == "abort";
                case "bridge"
                    % The answer cards, no pointer: the experimenter explains them
                    say("bridge");
                    flipQuestion();
                    aborted = waitGo(@flipQuestion);
            end
            if aborted, return; end
            for mk = step.markersAfter, rrstMarker(char(mk)); end
        end
    end

    function aborted = freePlay(step, prog)
        % Tutorial free play (kidsFreePlay) at level 0, after the mouse has run.
        nRun = nRun + 1;
        fTr = struct('n', nRun, 'phase', "tutorial", 'level', 0, 'isCatch', true, ...
            'proposed', NaN, 'limited', false, 'answer', "freeplay", 'response', NaN, 'rt', NaN, ...
            'moveT', NaN, 'slurpT', NaN, 'tStart', GetSecs - t0, 'slurps', [], ...
            'shortSlurps', false, 'flowLost', false);
        tMove = GetSecs;
        c = beatCtx(prog);
        say("move");
        [s, ~, cue] = kidsBeat("move", 0, c);
        show(scr, s, prog);
        playCue(cue);
        mv = stim.null();
        fTr.moveT = mv.elapsed;
        for mk = step.markersBefore, rrstMarker(char(mk)); end
        aborted = animate(cfg.timing.moveMin - (GetSecs - tMove), @(p) kidsBeat("move", p, c), prog) == "abort";
        if aborted, return; end
        if ~isempty(fl) && fl.lost && ismethod(src, 'reconnect')
            if src.reconnect(0.5), fprintf('Airflow stream is back.\n'); end
        end
        say("freeplay");
        if isa(src, 'kidsSimFlow')                     % simulated flow: two free slurps
            src.quiet();
            src.breathe(25, 1.3, 2, 2.5, 0.5);
        end
        io = struct('draw', @(s) show(scr, s, prog), 'keys', @phaseKeys, 'now', @GetSecs, ...
            'marker', @(label, t) rrstMarker(label, t), 'sound', @playCue, ...
            'prompt', @(msg) fprintf('%s\n', msg), 'sim', ~isempty(sim));
        [fStatus, fTr.slurps, fInfo] = kidsFreePlay(fl, cfg, io);
        fTr.slurpT = fInfo.durationS;
        fTr.flowLost = ~isempty(fl) && fl.lost;
        if isempty(sim), waitRelease(); end
        aborted = fStatus == "abort";
        if ~aborted
            practice(end + 1) = fTr;
        end
    end

    function flipQuestion()
        drawQuestion();
        Screen('Flip', scr.win);
    end

    function tFlip = show(scrIn, s, prog)
        % Draw the scene and flip; tFlip is the flip's onset (GetSecs time). Fields
        % the scene does not set: progress from prog, flavour = cupsDone + 1, and the
        % clock t (seconds since the session started) for the blink, Z's and waving.
        if ~isfield(s, 'stars'), s.stars = prog.stars; end
        if ~isfield(s, 'cupsDone'), s.cupsDone = prog.cupsDone; end
        if ~isfield(s, 'nCups'), s.nCups = prog.nCups; end
        if ~isfield(s, 'flavour'), s.flavour = s.cupsDone + 1; end
        if ~isfield(s, 't'), s.t = GetSecs - t0; end
        s.text = withPrompt(s);
        if sceneMouse ~= "", s.mousePose = sceneMouse; end
        kidsScene(scrIn, s);
        tFlip = Screen('Flip', scrIn.win);
    end

    function t = withPrompt(s)
        % The experimenter's line first; the scene's own sentence (story, feedback)
        % on a second line of the same small field.
        t = expLine;
        if isfield(s, 'text') && ~isempty(s.text)
            if isempty(t), t = char(s.text); else, t = [t '\n' char(s.text)]; end
        end
    end

    function aborted = waitGo(redraw)
        % Experimenter presses Space to go on; Esc returns true (abort). redraw
        % (optional) draws and flips the held frame each time round (one per frame).
        aborted = false;
        if nargin < 1, redraw = []; end
        if ~isempty(sim), pauseFor(0.3); return; end
        waitRelease();
        while true
            [down, ~, code] = KbCheck;
            if down && any(code(keys.go)), break; end
            if down && any(code(keys.abort)), aborted = true; break; end
            GetMouse;                    % keeps the window responsive (KbCheck alone lets Windows grey it out)
            if isempty(redraw), WaitSecs(0.001); else, redraw(); end
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
        if kidsStandalone(cfg)
            % everything the task saw, on the GetSecs clock (t0: tStart = 0)
            r.t0 = t0;
            r.flow = recordedFlow();
            r.markers = rrstMarker('log');
        end
    end

    function x = recordedFlow()
        % Every flow sample pulled this session, the ones still waiting included.
        x = zeros(0, 2);
        if isempty(src) || ~isprop(src, 'record') || ~src.record, return; end
        try, src.pull(); catch, end          % a lost stream must not stop the save
        x = src.recorded();
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

function w = answerWord(response)
% The child's answer as the cards name it (console only).
if response == 1, w = 'squishy (yes)'; else, w = 'easy (no)'; end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
