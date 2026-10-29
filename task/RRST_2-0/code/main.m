function main(vars, scr, cfg, stim)
%function main(vars, scr, cfg, stim)
%
% Project: Respiratory Resistance Sensitivity Task (RRST), version 2.0.
%
% Main experimental script. Called by runRRST.m. Ported from RRS_3-0/code/main.m
% (Niia Nikolova); screens, timing and Palamedes procedures are unchanged except:
%   - every move goes through stim (rrst.Stimulator) and is confirmed by the
%     firmware before the ISI countdown starts; move durations are saved
%   - stimulus levels are used exactly as the staircase proposes them (RRS_3-0
%     rounded them to whole numbers)
%   - the wedge rests at a random level in cfg.stim.restRange between trials
%     (RRS_3-0's ITI position resolved to full obstruction in mm mode)
%   - abort, error and end park the wedge open instead of recalibrating, which
%     closed it fully
%   - masking noise is generated in code (cfg.noise), not read from a wav file
%   - fixed: experimentEnd argument order, isfield('vars', ...), metacog check on
%     a single Psi staircase
%
% Input:
%   vars        struct with session fields (set by runRRST.m and loadParams.m)
%   scr         struct with screen / display settings
%   cfg         configuration (config/pilotConfig.m)
%   stim        rrst.Stimulator connected to the device (or the simulated device)

%% ============================ SET-UP ================================

% Display configuration
[scr] = displayConfig(scr);

% Keyboard & keys configuration
[keys] = keyConfig();

% Reseed the random-number generator
SetupRand;

% Load the parameters
loadParams;

% Results structure
DummyDouble = ones(vars.NTrialsTotal,1).*NaN;
Results = struct('trialN',{DummyDouble},'Stim',{DummyDouble},'SignalInterval',{DummyDouble},...
    'Resp',{DummyDouble},'RespLR',{DummyDouble},'ConfResp', {DummyDouble},...
    'RT',{DummyDouble}, 'ConfRT', {DummyDouble}, 'ConfOn', {DummyDouble},...
    'ConfOff', {DummyDouble}, 'MetacogTrials', {DummyDouble},...
    'trialSuccess', {DummyDouble}, 'SubID', {DummyDouble}, ...
    'StimSteps', {DummyDouble}, 'StimMoveT', {DummyDouble}, 'NullMoveT', {DummyDouble}, ...
    'RestLevel', {DummyDouble}, 'RestMoveT', {DummyDouble}, 'Calibrations', {0});

noiseHandle = [];
thisTrialStaircase = 1;

%% Prepare to start
AssertOpenGL;

try
    %% Open screen window
    if cfg.smallWindow
        [scr.win, scr.winRect] = PsychImaging('OpenWindow', scr.screenID, scr.BackgroundGray, [0,0,3840/3,2160/3]);
    else
        [scr.win, scr.winRect] = PsychImaging('OpenWindow', scr.screenID, scr.BackgroundGray);
    end

    % Set text size, dependent on screen resolution
    if any(logical(scr.winRect(:)>3000))       % 4K resolution
        scr.TextSize = 45;
    else
        scr.TextSize = 28;
    end
    Screen('TextSize', scr.win, scr.TextSize);
    Screen('TextFont', scr.win, 'Arial');
    Screen('Textfont', scr.win, '-:lang=da');   % allow danish characters

    % Colour range 0.0 - 1.0
    Screen('ColorRange', scr.win, 1);
    White   = WhiteIndex(scr.screenID);
    Gray    = GrayIndex(scr.screenID);
    scr.BackgroundGray  = Gray + 0.037;
    scr.TextColour      = White;
    firstColor          = [0.14, 0.82, 0.67, 1];       	% dark teal

    % Get frame rate
    scr.hz  = Screen('NominalFrameRate', scr.win);
    disp(['Frame rate: ', num2str(scr.hz)])

    % Set priority for script execution to realtime priority:
    scr.priorityLevel = MaxPriority(scr.win);
    Priority(scr.priorityLevel);

    % Determine stim size in pixels
    scr.dist        = scr.ViewDist;
    scr.width       = scr.MonitorWidth;
    scr.height      = scr.winRect(4);
    scr.rad         = 240;                        	% radius of circle to display for breath
    scr.x_middle    = scr.winRect(3) / 2;
    scr.y_middle    = scr.winRect(4) / 2;

    % Dummy calls to prevent delays
    vars.ValidTrial = zeros(1,2);
    vars.RunSuccessfull = 0;
    vars.Aborted    = 0;
    vars.Error      = 0;
    vars.abortFlag  = 0;
    metacogTrialsCreated = 0;
    probeNb         = 1;

    Resp            = nan;
    vars.RespLR     = nan;
    vars.ConfResp   = nan;

    GetSecs;
    WaitSecs(0.500);
    [~, ~, keys.KeyCode] = KbCheck;

    %% Calibrate while showing the welcome screen (about 25 s, wedge closes fully)
    Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
    DrawFormattedText(scr.win, strrep(vars.InstructionCalib, 'You can continue in \n \n', ''), ...
        'center', 'center', scr.TextColour);
    Screen('Flip', scr.win);
    stim.calibrate();
    Results.Calibrations = 1;

    %% Show task instructions
    showInstruction(scr, keys, vars.InstructionTask);

    % Move device to a rest position
    [Results.RestLevel(1), mv] = stim.rest();
    Results.RestMoveT(1) = mv.elapsed;

    % Start noise playback
    if vars.playNoiseSound
        noiseHandle = startMaskingNoise(cfg.noise);
    end


    %% ============================ TUTORIAL ================================

    if vars.runTutorial
        disp('Running through tutorial...');
        rrstMarker('tutorial_start');
        respiroceptionTutorial(scr, keys, vars, stim, cfg);
        stim.rest();    % Esc ends the tutorial early, possibly with the wedge loaded
        rrstMarker('tutorial_end');
    end


    %% ========================== MAIN EXPERIMENT ===========================

    % The experiment will begin now
    Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
    DrawFormattedText(scr.win, [vars.InstructionStart], 'center', 'center', scr.TextColour);
    [~, ~] = Screen('Flip', scr.win);
    WaitSecs(0.2);

    % Wait for space
    while keys.KeyCode(keys.Space) == 0
        [~, ~, keys.KeyCode] = KbCheck;
        GetMouse;                           % keeps the window responsive (KbCheck alone lets Windows grey it out)
        WaitSecs(0.001);
    end
    Results.SessionStartT = GetSecs;            % Session start timestamp
    rrstMarker('session_start', Results.SessionStartT);


    %% Get Ready screen
    Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
    DrawFormattedText(scr.win, vars.InstructionGetReady, 'center', 'center', scr.TextColour);
    [~, ~] = Screen('Flip', scr.win);
    WaitSecs(3);                % pause before experiment start
    thisTrial = 1;              % trial counter
    thisMetacogTrial = 1;
    go2MetacogTrials = 0;
    endOfExpt = 0;


    %% Run through trials
    while endOfExpt ~= 1                % General stop flag for the loop

        % Present the two stim alternatives
        for thisAlt = 1:2

            %% Choose this interval's level
            if vars.wheresTheSignal(thisTrial) == thisAlt	% If this is the signal alternative
                vars.stimIsHere = 1;            % used for plux synch in the ring helpers

                if ~go2MetacogTrials
                    % Which staircase is the stim coming from. The level is used
                    % exactly as proposed (RRS_3-0 rounded it).
                    thisTrialStaircase  = vars.whichStair(thisTrial);
                    thisTrialStim       = stair(thisTrialStaircase).PM.xCurrent;
                elseif isfield(vars, 'MetacogTrialsList')
                    disp(['Metacog trial # ', num2str(thisMetacogTrial)]);
                    thisTrialStim   = vars.MetacogTrialsList(thisMetacogTrial);
                else
                    endOfExpt = 1;
                    break
                end

                disp(['Trial # ', num2str(thisTrial), ', staircase ', num2str(thisTrialStaircase), ...
                    '. Level: ', num2str(thisTrialStim), ' ', char(cfg.stim.unit)]);
                disp(['Load is in breath ', num2str(vars.wheresTheSignal(thisTrial))]);
            else
                vars.stimIsHere = 0;
            end

            %% Show the countdown screen, then move and wait for confirmation
            if thisAlt==2
                instructionPrepare2Breathe = vars.InstructionISI;
            else
                instructionPrepare2Breathe = vars.InstructionPrepareFirstTrial;
            end
            counterText = strcat(instructionPrepare2Breathe, num2str(vars.ISI), ' sec.');
            Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
            Screen('FrameOval', scr.win, firstColor, [scr.x_middle-scr.rad scr.y_middle-scr.rad scr.x_middle+scr.rad scr.y_middle+scr.rad], 3, 3);
            DrawFormattedText(scr.win, counterText, 'center', 3*scr.height/4, scr.TextColour);
            Screen('Flip', scr.win);

            if vars.stimIsHere
                mv = stim.present(thisTrialStim);
                Results.StimSteps(thisTrial) = stim.Log(end).steps;
                Results.StimMoveT(thisTrial) = mv.elapsed;
            else
                mv = stim.null();
                Results.NullMoveT(thisTrial) = mv.elapsed;
            end

            % Count down the ISI from the confirmed move
            ISIstart = GetSecs;
            rrstMarker(sprintf('trial_%d_interval%d_ready', thisTrial, thisAlt), ISIstart);
            if vars.stimIsHere   % level in the recording itself, so figures need no task file
                rrstMarker(sprintf('trial_%d_level_%g', thisTrial, thisTrialStim), ISIstart);
            end
            while (GetSecs - ISIstart) <= vars.ISI
                tRemaining = round(vars.ISI - (GetSecs - ISIstart));
                counterText = strcat(instructionPrepare2Breathe, num2str(tRemaining), ' sec.');
                Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
                Screen('FrameOval', scr.win, firstColor, [scr.x_middle-scr.rad scr.y_middle-scr.rad scr.x_middle+scr.rad scr.y_middle+scr.rad], 3, 3);
                DrawFormattedText(scr.win, counterText, 'center', 3*scr.height/4, scr.TextColour);
                [~, ~] = Screen('Flip', scr.win);

                % KbCheck for Esc key
                if keys.KeyCode(keys.Escape)==1
                    abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
                    return
                end
                [~, ~, keys.KeyCode] = KbCheck;
                GetMouse;                           % keeps the window responsive (KbCheck alone lets Windows grey it out)
                WaitSecs(0.001);
            end


            %% Text: 'Inhale....'
            if thisAlt == 1
                vars.InstructionInhale = vars.InstructionInhale1;
                vars.switchColour = 0;
            elseif thisAlt == 2
                vars.InstructionInhale = vars.InstructionInhale2;
                vars.switchColour = 1;
            end

            % Show expanding circle
            [scr, vars] = showExpandingRingGenerated(scr, vars);
            loadNames = ["null" "load"];
            rrstMarker(sprintf('trial_%d_interval%d_onset_%s', thisTrial, thisAlt, ...
                loadNames(vars.stimIsHere + 1)), vars.StimOn);
            if vars.abortFlag   % Esc during the breath
                abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
                return
            end

        end% 2 Intervals

        if endOfExpt
            break
        end


        %% Show response prompt screen
        WaitSecs(0.4);
        Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
        DrawFormattedText(scr.win, [vars.InstructionQ], 'center', 3*scr.height/4, scr.TextColour);
        [~, vars.StartRT] = Screen('Flip', scr.win);

        % Fetch the participant's response, via keyboard or mouse
        [vars] = getResponse(keys, scr, vars);
        if vars.ValidTrial(1)
            rrstMarker(sprintf('trial_%d_response', thisTrial), vars.EndRT);
        else
            rrstMarker(sprintf('trial_%d_noresponse', thisTrial));
        end

        % Get response time
        RT = (vars.EndRT - vars.StartRT);

        % Get accuracy: correct if the response names the breath with the load
        if vars.RespLR == 0 || vars.RespLR == 1
            Resp = double((vars.RespLR + 1) == vars.wheresTheSignal(thisTrial));
            outcome = ["wrong" "correct"];
            rrstMarker(sprintf('trial_%d_%s', thisTrial, outcome(Resp + 1)), vars.EndRT);
        else
            Resp = NaN;
        end

        % if Esc was pressed
        if vars.abortFlag == 1
            abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
            return
        end


        % Update staircase, if valid response & we're in the main staircase
        if vars.ValidTrial(1) && (go2MetacogTrials ==0)
            switch cfg.procedure
                case "psi"
                    stair.PM = PAL_AMPM_updatePM(stair.PM, Resp);
                case "quest"
                    stair(thisTrialStaircase).PM = PAL_AMRF_updateRF(stair(thisTrialStaircase).PM, ...
                        thisTrialStim, Resp);
            end
        end

        % Update Results mat
        Results.trialN(thisTrial)       = thisTrial;
        Results.Stim(thisTrial)         = thisTrialStim;
        Results.SignalInterval(thisTrial) = vars.wheresTheSignal(thisTrial);
        Results.SubID(thisTrial)        = vars.subNo;
        Results.Resp(thisTrial)         = Resp;             % Correct?
        Results.RespLR(thisTrial)       = vars.RespLR;     	% 0 left (1st breath), 1 right (2nd breath)
        Results.RT(thisTrial)           = RT;
        Results.MetacogTrials(thisTrial)= go2MetacogTrials * thisMetacogTrial;

        if ~isnan(Resp)
            if Resp
                disp('Correct response');
            else
                disp('Incorrect response');
            end
        end

        % Time to stop the staircase(s)?
        allStopped = all(arrayfun(@(s) s.PM.stop == 1, stair));
        if allStopped && vars.NMetacogTrials ~= 0
            if go2MetacogTrials
                thisMetacogTrial = thisMetacogTrial + 1;
            end
            go2MetacogTrials = 1;
            if metacogTrialsCreated == 0
                % Staircase finished: threshold-based, jittered stimuli for metacog trials
                vars.MetacogTrialsList = getPMFbasedTrials(vars, stair);
                metacogTrialsCreated = 1;
            end
        end


        %% Confidence rating
        if vars.ConfRating

            % Fetch the participant's confidence rating
            [vars] = getConfidence(keys, scr, vars);

            Results.ConfOn(thisTrial)   = vars.ConfOnset - Results.SessionStartT;
            Results.ConfOff(thisTrial)  = vars.ConfOffset - Results.SessionStartT;
            if vars.ValidTrial(2)
                rrstMarker(sprintf('trial_%d_confidence', thisTrial), vars.ConfOffset);
            end

            if vars.abortFlag       % Esc was pressed
                Results.ConfResp(thisTrial) = NaN;
                abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
                return
            end

            % If this trial was successfull, move on...
            if(vars.ValidTrial(2)), WaitSecs(0.2); end

            % Write trial result to file
            Results.ConfResp(thisTrial) = vars.ConfResp;
            Results.ConfRT(thisTrial) = vars.ConfRatingRT;

            % Was this a successfull trial? (response and confidence rating valid)
            Results.trialSuccess(thisTrial) = logical(sum(vars.ValidTrial) == 2);

        else % no Confidence rating

            Results.trialSuccess(thisTrial) = logical(sum(vars.ValidTrial) == 1);

        end


        %% ITI: move to a rest position, then wait out the rest of the ITI
        Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
        [~, StartITI] = Screen('Flip', scr.win);
        rrstMarker(sprintf('trial_%d_iti', thisTrial), StartITI);
        [Results.RestLevel(thisTrial), mv] = stim.rest();
        Results.RestMoveT(thisTrial) = mv.elapsed;

        while (GetSecs - StartITI) <= vars.ITI(thisTrial)
            if keys.KeyCode(keys.Escape)==1
                abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
                return
            end
            [~, ~, keys.KeyCode] = KbCheck;
            GetMouse;                           % keeps the window responsive (KbCheck alone lets Windows grey it out)
            WaitSecs(0.001);
        end

        % Time to stop?
        if (thisTrial == vars.NTrialsTotal)
            endOfExpt = 1;
        end

        % if this was a valid trial, advance one. Else, repeat it.
        advanced = vars.ValidTrial(1);
        if advanced
            thisTrial = thisTrial + 1;
        else
            disp('Invalid response. Repeating trial.');
        end

        % Reset ValidTrial, Resp
        vars.ValidTrial	= zeros(1,2);
        Resp            = NaN;
        vars.RespLR     = NaN;
        vars.ConfResp   = NaN;



        %% Break every vars.PauseFreq trials (not after the last trial, and only
        % once: a repeated invalid trial does not trigger the same break again)
        if advanced && ~endOfExpt && ~rem((thisTrial-1), vars.PauseFreq) && ((thisTrial-1) ~= vars.NTrialsTotal)

            if vars.probeTaskSatisfaction
                [position, ~, RT, answer] = slideScale(scr.win, ...
                    vars.Questions{1,2}, ...
                    scr.winRect, ...
                    vars.Questions{1,3}, ...
                    'scalalength', 0.6,...
                    'linelength', 20,...
                    'width', 10,...
                    'device', 'mouse', ...
                    'stepsize', 4, ...
                    'startposition', 'shuffle', ...
                    'range', 2, ...
                    'aborttime', vars.eqT,...
                    'slidercolor', [0.14 0.42 0.38],...
                    'scalacolor', [1 1 1]);

                if answer == -1     % Esc on the rating
                    abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
                    return
                end

                % Update results
                Results.ExpRateTask(1, probeNb) = position;
                Results.ExpRateTask(2, probeNb) = RT;
                Results.ExpRateTask(3, probeNb) = answer;
                Results.ExpRateTask(4, probeNb) = probeNb;

                disp([vars.Questions{1}, ', rating: ', num2str(position)]);
                WaitSecs(0.2);

                probeNb = probeNb + 1;
            end

            disp(['You have completed ', num2str(thisTrial-1), ' out of ', num2str(vars.NTrialsTotal), ' trials.']);

            % Break screen; recalibrate during the break (about 25 s), then rest
            [~, startPause] = Screen('Flip', scr.win);
            rrstMarker('break_start', startPause);
            counterText = strcat(vars.InstructionPause, num2str(ceil(vars.pauseT/60)), ' min.');
            Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
            DrawFormattedText(scr.win, counterText, 'center', 'center', scr.TextColour);
            Screen('Flip', scr.win);
            if cfg.device.recalibrateAtBreaks
                stim.calibrate();
                Results.Calibrations = Results.Calibrations + 1;
            end
            stim.rest();

            while (GetSecs - startPause) <= vars.pauseT
                % Update counter
                tRemaining = ceil((vars.pauseT - (GetSecs - startPause))/60);
                counterText = strcat(vars.InstructionPause, num2str(tRemaining), ' min.');
                Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
                DrawFormattedText(scr.win, counterText, 'center', 'center', scr.TextColour);
                [~, ~] = Screen('Flip', scr.win);

                % KbCheck for Esc key
                if keys.KeyCode(keys.Escape)==1
                    abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg);
                    return
                end
                [~, ~, keys.KeyCode] = KbCheck;
                GetMouse;                           % keeps the window responsive (KbCheck alone lets Windows grey it out)
                WaitSecs(0.001);
            end

            % 'You can continue now'
            Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
            DrawFormattedText(scr.win, vars.InstructionPauseStart, 'center', 'center', scr.TextColour);
            [~, ~] = Screen('Flip', scr.win);

            [~, ~, keys.KeyCode] = KbCheck;
            while keys.KeyCode(keys.Space) == 0
                [~, ~, keys.KeyCode] = KbCheck;
                GetMouse;                           % keeps the window responsive (KbCheck alone lets Windows grey it out)
                WaitSecs(0.001);
            end
            rrstMarker('break_end');

        end

    end%thisTrial

    % Wedge open before the end-of-session questions
    stim.park();
    stopMaskingNoise(noiseHandle);
    noiseHandle = [];


    %% Probe task satisfaction at end of session
    if vars.probeTaskSatisfaction
        [position, ~, RT, answer] = slideScale(scr.win, ...
            vars.Questions{1,2}, ...
            scr.winRect, ...
            vars.Questions{1,3}, ...
            'scalalength', 0.6,...
            'linelength', 20,...
            'width', 10,...
            'device', 'mouse', ...
            'stepsize', 4, ...
            'startposition', 'shuffle', ...
            'range', 2, ...
            'aborttime', vars.eqT,...
            'slidercolor', [0.14 0.42 0.38],...
            'scalacolor', [1 1 1]);

        Results.ExpRateTask(1, probeNb) = position;
        Results.ExpRateTask(2, probeNb) = RT;
        Results.ExpRateTask(3, probeNb) = answer;
        Results.ExpRateTask(4, probeNb) = probeNb;

        disp([vars.Questions{1}, ', rating: ', num2str(position)]);
        WaitSecs(0.2);
    end


    %% Experience ratings
    if vars.collectExperienceRatings
        showInstruction(scr, keys, vars.InstructionEQ);

        for EQcounter = 1:vars.nQuestions
            thisQ = vars.randQOrder(EQcounter);               % Random order of questions

            [position, ~, RT, answer] = slideScale(scr.win, ...
                vars.Questions{thisQ,2}, ...
                scr.winRect, ...
                vars.Questions{thisQ,3}, ...
                'scalalength', 0.6,...
                'linelength', 20,...
                'width', 10,...
                'device', 'mouse', ...
                'stepsize', 4, ...
                'startposition', 'shuffle', ...
                'range', 2, ...
                'aborttime', vars.eqT,...
                'slidercolor', [0.14 0.42 0.38],...
                'scalacolor', [1 1 1]);

            Results.ExpRareEnd(1, thisQ) = position;
            Results.ExpRareEnd(2, thisQ) = RT;
            Results.ExpRareEnd(3, thisQ) = answer;
            Results.ExpRareEnd(4, thisQ) = thisQ;

            disp([vars.Questions{thisQ}, ', rating: ', num2str(position)]);
            WaitSecs(0.2);
        end
    end


    vars.RunSuccessfull = 1;
    vars.device = stim.summary();
    vars.cfg = cfg;
    endSession(vars, scr, keys, Results, stair, "complete");

    if cfg.procedure == "psi"
        disp(['Threshold estimate: ', num2str(stair.PM.threshold(end)), ' ', char(cfg.stim.unit)]);
        disp(['Slope estimate: ', num2str(10.^stair.PM.slope(end))]);   % PM.slope is log10 beta
    end

catch err   % Error. Park the wedge if the device still answers, save, rethrow.
    try
        stim.park();
    catch parkErr
        disp(['Could not park the wedge: ', parkErr.message]);
    end
    stopMaskingNoise(noiseHandle);
    vars.Error = 1;
    vars.errorReport = getReport(err, 'extended', 'hyperlinks', 'off');
    vars.device = stim.summary();
    vars.cfg = cfg;
    endSession(vars, scr, keys, Results, stair, "error");
    rethrow(err);
end

end

function abortSession(stim, noiseHandle, vars, scr, keys, Results, stair, cfg)
% Esc: park the wedge open, save everything, mark the run as aborted.
stim.park();
stopMaskingNoise(noiseHandle);
vars.RunSuccessfull = 0;
vars.Aborted = 1;
vars.device = stim.summary();
vars.cfg = cfg;
endSession(vars, scr, keys, Results, stair, "aborted");
end
