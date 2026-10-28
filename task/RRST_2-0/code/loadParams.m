%% Define parameters (RRST 2.0)
%
% Script called by main.m. Copies the configuration (cfg, see config/pilotConfig.m)
% into the vars / stair fields that the RRS_3-0 helpers expect, and sets up the
% Palamedes procedure. The instruction texts below the timing section are unchanged
% from RRS_3-0/code/loadParams.m.

%% Key flags
vars.runTutorial    = cfg.runTutorial;
vars.ConfRating     = cfg.confidence;
vars.InputDevice    = cfg.inputDevice;
vars.playNoiseSound = cfg.noise.enabled;
switch lower(vars.languageIn)
    case 'e', vars.language = 1;
    case 'd', vars.language = 2;
    otherwise, error('rrst:badConfig', 'Language must be e (English) or d (Danish).');
end
vars.probeTaskSatisfaction    = cfg.probeTaskSatisfaction;
vars.collectExperienceRatings = cfg.collectExperienceRatings;
vars.pluxSynch      = 0;
vars.RRSTdevice     = 1;        % always: a mock session uses a simulated device
vars.Procedure      = cfg.procedure;
vars.DataFileName   = sprintf('%s_%s_%s', vars.DataFileName, cfg.procedure, datestr(now, 'yyyy-mm-dd_HHMM'));

%% Procedure
vars.NMetacogTrials = cfg.metacogTrials;      % extra near-threshold trials after the staircase
if vars.NMetacogTrials ~= 0
    vars.MC.threshLevel = 0.75;
    vars.MC.jitter      = 0.05;
end

switch cfg.procedure
    case "psi"      % Palamedes Psi method, single staircase
        vars.Nstaircases    = 1;
        vars.NumTrials      = cfg.psi.numTrials;
        stair.grain             = cfg.psi.grain;
        stair.PF                = str2func(cfg.psi.PF);
        stair.stimRange         = cfg.psi.stimRange;
        stair.priorAlphaRange   = cfg.psi.priorAlphaRange;
        stair.priorBetaRange    = cfg.psi.priorBetaRange;     % log10 beta
        stair.priorGammaRange   = cfg.psi.priorGammaRange;
        stair.priorLambdaRange  = cfg.psi.priorLambdaRange;
        stair.PM = PAL_AMPM_setupPM('priorAlphaRange', stair.priorAlphaRange, ...
            'priorBetaRange', stair.priorBetaRange, ...
            'priorGammaRange', stair.priorGammaRange, ...
            'priorLambdaRange', stair.priorLambdaRange, ...
            'numtrials', vars.NumTrials, ...
            'PF', stair.PF, ...
            'stimRange', stair.stimRange);

    case "quest"    % Palamedes running fit (QUEST-like), interleaved staircases
        vars.Nstaircases    = cfg.quest.numStaircases;
        vars.NumTrials      = cfg.quest.numTrials;     % per staircase
        for thisStair = 1:vars.Nstaircases
            stair(thisStair).alphas = cfg.quest.alphas;
            stair(thisStair).PFfit  = str2func(cfg.quest.PF);
            % Default (uniform) prior over alphas, as RRS_3-0
            stair(thisStair).PM = PAL_AMRF_setupRF('priorAlphaRange', stair(thisStair).alphas, ...
                'stopcriterion', 'trials', 'stoprule', vars.NumTrials, ...
                'beta', cfg.quest.beta, 'lambda', cfg.quest.lambda, ...
                'PF', stair(thisStair).PFfit, 'meanmode', 'mean', ...
                'xMax', cfg.quest.xMax, 'xMin', cfg.quest.xMin);
        end
end
vars.NTrialsTotal = (vars.NumTrials * vars.Nstaircases) + vars.NMetacogTrials;

%% Task timing (s)
vars.fixedTiming    = cfg.timing.fixedTiming;
vars.PrepareT       = cfg.timing.prepare;
vars.inhaleT        = cfg.timing.inhale;
vars.breathPauseT   = cfg.timing.breathPause;
vars.RespT          = cfg.timing.response;
vars.ConfT          = cfg.timing.confidence;
vars.ISI            = cfg.timing.isi;             % counted down AFTER the move is confirmed
vars.ITI_min        = cfg.timing.itiMin;
vars.ITI_max        = cfg.timing.itiMax;
vars.ITI            = randInRange(vars.ITI_min, vars.ITI_max, [vars.NTrialsTotal, 1]);

% 2IFC: stimulus in the first or second breath, equally often (validateConfig
% guarantees an even total)
vars.wheresTheSignal = [ones(vars.NTrialsTotal/2, 1); ones(vars.NTrialsTotal/2, 1) .* 2];
vars.wheresTheSignal = vars.wheresTheSignal(randperm(vars.NTrialsTotal));

% Which staircase each trial draws from (balanced; metacog trials use staircase 1)
whichStair = repelem((1:vars.Nstaircases)', vars.NumTrials);
whichStair = whichStair(randperm(numel(whichStair)));
vars.whichStair = [whichStair; ones(vars.NMetacogTrials, 1)];

% Breaks
vars.pauseT     = cfg.timing.pause;
vars.PauseFreq  = cfg.timing.pauseEvery;
vars.nBreaks    = floor(vars.NTrialsTotal / vars.PauseFreq);
vars.eqT        = cfg.timing.experienceQuestion;

%% Plux synch variables
% Colours: White, Black
scr.pluxWhite     = [1 1 1];
scr.pluxBlack     = [0, 0, 0];

% Duration
scr.pluxDur         = [2; 25];% [2;4]       % 2 frames - stim, 4 frames - response

% Size
% rows: x y width height
% provide size in cm and convert to pix
pluxRectTemp        = [0; 0; 0.5; 0.5];
multFactorW         = scr.resolution.width ./ scr.MonitorWidth;
multFactorH         = scr.resolution.height ./ scr.MonitorHeight;
scr.pluxRect(3)     = pluxRectTemp(3) .* multFactorW;
scr.pluxRect(4)     = pluxRectTemp(4) .* multFactorH;
scr.pluxRect = CenterRectOnPoint(scr.pluxRect,scr.pluxRect(3),scr.resolution.height - scr.pluxRect(4));


%% Instructions

% Main task instructions / Welcome
%% English
if vars.language == 1
    switch vars.ConfRating
        case 1
            
            if vars.runTutorial == 0
                vars.InstructionTask = 'WELCOME TO THE BREATH SENSITIVITY TASK! \n \n \n \n \n \n On each trial, you will take two breaths (inhalations).  \n \n Breathe shallowly and pace your inhalations with the expanding circle. \n \n \n \n Then, decide which of the two breaths was more difficult. \n \n First breath - Left mouse button             or            Second breath - Right mouse button \n \n \n \n Then, rate how confident you are in your choice using the slider. \n \n Press ''SPACE'' to start...';
            else
                vars.InstructionTask = 'WELCOME TO THE BREATH SENSITIVITY TASK! \n \n \n \n Press ''SPACE'' to continue to the tutorial. ';
            end
            
            vars.InstructionConf = 'How confident are you in your choice?';
            vars.ConfEndPoins    = {'Guess', 'Certain'};
        case 0
            if vars.runTutorial == 0
                vars.InstructionTask = 'WELCOME TO THE BREATH SENSITIVITY TASK! \n \n \n \n \n \n On each trial, you will take two breaths (inhalations).  \n \n Breathe shallowly and pace your inhalations with the expanding circle. \n \n \n \n Then, decide which of the two breaths was more difficult. \n \n First breath - Left mouse button             or            Second breath - Right mouse button \n \n \n \n Press ''SPACE'' to start...';
            else
                vars.InstructionTask = 'WELCOME TO THE BREATH SENSITIVITY TASK! \n \n \n \n Press ''SPACE'' to continue to the tutorial. ';
            end
            vars.InstructionConf = 'How confident are you in your choice?';
            vars.ConfEndPoins    = {'Guess', 'Certain'};
    end
    
    % Experiment text
    vars.InstructionCalib   = 'WELCOME TO THE BREATH SENSITIVITY TASK! \n \n \n \n \n \ Please wait while the apparatus calibrates.\n \n You can continue in \n \n';
    vars.InstructionStart       = 'The experiment will start now. Press ''SPACE'' to start.';
    vars.InstructionPrepare     = 'Breathe naturally...  \n \n Get ready to inhale in \n \n';
    vars.InstructionGetReady     = 'Get ready';
    vars.InstructionPrepareFirstTrial     = 'Get ready to inhale in \n \n';
    vars.InstructionInhale1     = 'Take the first inhale...';
    vars.InstructionInhale2     = 'Take the second inhale...';
    vars.InstructionISI         = 'Exhale... \n \n Get ready to inhale in \n \n';
    vars.InstructionQ           = 'Which breath was harder? \n \n First breath (L)     or     Second breath (R)';
    vars.InstructionPause       = 'Take a short break. Please stand up and move around. \n \n Remember to take sharp and shallow breaths during the task. \n \n \n \n You can continue in \n \n';
    vars.InstructionPauseStart  = 'You can continue now. \n \n When you are ready to continue, press ''SPACE''... ';
    vars.InstructionEnd         = 'You have completed the session. Thank you!';
    
    
    % Experience ratings
    vars.InstructionEQ      = 'Please answer a few quick questions about how you felt during the Breath Sensitivity Task. \n \n Press ''SPACE'' to continue...';
    vars.QuestionsAsthma    = 'Do you have asthma or another respiratory condition? \n \n No (L)     or     Yes (R)';
    
    % 1 Label, 2 Question, 3 Scale
    vars.Questions{1,1} = 'TaskGeneral';
    vars.Questions{1,2} = 'I find the task';
    vars.Questions{1,3} = {'Not unpleasant', 'Very unpleasant'};
    
    vars.Questions{2,1} = 'Dizzy';
    vars.Questions{2,2} = 'I feel dizzy / lightheaded.';
    vars.Questions{2,3} = {'Not at all', 'Completely'};
    
    vars.Questions{3,1} = 'Breathless';
    vars.Questions{3,2} = 'I feel breathless / have trouble breathing.';
    vars.Questions{3,3} = {'Not at all', 'Completely'};
    
    vars.Questions{4,1} = 'Asthma';
    vars.Questions{4,2} = 'If you have asthma, rate the severity of your symptoms in the last week.';
    vars.Questions{4,3} = {'No asthma / none', 'Very severe'};
    
    %% Danish
elseif vars.language == 2
    switch vars.ConfRating
        case 1
            
            if vars.runTutorial == 0
                vars.InstructionTask = 'VELKOMMEN TIL VEJRTRÆKNINGSFØLSOMHEDSOPGAVEN! \n \n \n \n \n \n I hver runde skal du tage to åndedrag (indåndinger). \n\n Tag skarpe og overfladiske åndedrag og forsøg at indånde jævnt, mens cirklen på skærmen udvider sig. \n \n \n \n  Efterfølgende vil du blive spurgt om, hvilken af de to indåndinger, der var mest udfordrende. \n \n Første åndedrag - tryk VENSTRE museknap       eller         Andet åndedrag - tryk på HØJRE museknap \n \n \n \n Bagefter skal du vurdere, hvor sikker du var på dit valg ved at bruge markøren på skalaen. \n \n Tryk på “MELLEMRUMSTASTEN” for at fortsætte…';
            else
                vars.InstructionTask = 'VELKOMMEN TIL VEJRTRÆKNINGSFØLSOMHEDSOPGAVEN!  \n \n Tryk på “MELLEMRUMSTASTEN” for at fortsætte til vejledningen.';
            end
            
            vars.InstructionConf = 'Hvor sikker var du på dit valg?';
            vars.ConfEndPoins    = {'Gæt', 'Helt sikker'};
        case 0
            if vars.runTutorial == 0
                vars.InstructionTask = 'VELKOMMEN TIL VEJRTRÆKNINGSFØLSOMHEDSOPGAVEN! \n \n \n \n \n \n I hver runde skal du tage to åndedrag (indåndinger). \n\n Tag skarpe og overfladiske åndedrag og forsøg at indånde jævnt, mens cirklen på skærmen udvider sig. \n \n \n \n  Efterfølgende vil du blive spurgt om, hvilken af de to indåndinger, der var mest udfordrende. \n \n Første åndedrag - tryk VENSTRE museknap       eller         Andet åndedrag - tryk på HØJRE museknap \n \n \n \n Tryk på “MELLEMRUMSTASTEN” for at fortsætte…';
            else
                vars.InstructionTask = 'VELKOMMEN TIL VEJRTRÆKNINGSFØLSOMHEDSOPGAVEN!  \n \n Tryk på “MELLEMRUMSTASTEN” for at fortsætte til vejledningen.';
            end
            
            vars.InstructionConf = 'Hvor sikker var du på dit valg?';
            vars.ConfEndPoins    = {'Gæt', 'Helt sikker'};
    end
    
    % Experiment text
    vars.InstructionCalib   = 'WELCOME TO THE BREATH SENSITIVITY TASK! \n \n \n \n \n \ Please wait while the apparatus calibrates.\n \n You can continue in \n \n';
    vars.InstructionStart       = 'Eksperimentet starter nu. Tryk på MELLEMRUMSTASTEN';
    vars.InstructionPrepare     = 'Træk vejret naturligt… \n\n Gør dig klar til at ånde ind om \n \n';
    vars.InstructionGetReady    = 'Gør dig klar…';
    vars.InstructionPrepareFirstTrial     = 'Gør dig klar til at ånde ind om \n \n';
    vars.InstructionInhale1     = 'Tag den første indånding…';
    vars.InstructionInhale2     = 'Tag den anden indånding…';
    vars.InstructionISI         = 'Ånd ud… \n\n Gør dig klar til at ånde ind om \n \n';
    vars.InstructionQ           = 'Hvilket åndedrag var mest udfordrende \n\n Det første (Venstre) eller det andet (Højre)';
    vars.InstructionPause       = 'Tag en kort pause. Rejs dig op og bevæg dig. \n \n Husk at tage skarpe og overfladiske indåndinger undervejs i opgaven. \n \n \n \n Du kan fortsætte om \n \n';
    vars.InstructionPauseStart  = 'Du kan nu fortsætte. \n \n Tryk på “MELLEMRUMSTASTEN” for at fortsætte... ';
    vars.InstructionEnd         = 'Du har gennemført sessionen. Tak!';
    
    
    % Experience ratings
    vars.InstructionEQ      = 'Besvar venligst nogle få enkle spørgsmål om, hvordan du havde det under Vejrtrækningsfølsomhedsopgaven. \n \n Tryk på “MELLEMRUMSTASTEN” for at fortsætte…';
    vars.QuestionsAsthma    = 'Har du astma eller en anden luftvejssygdom? \n \n Nej (Venstre) eller Ja (Højre)';
    
    % 1 Label, 2 Question, 3 Scale
    vars.Questions{1,1} = 'TaskGeneral';
    vars.Questions{1,2} = 'Jeg fandt opgaven';
    vars.Questions{1,3} = {'Ikke ubehageligt', 'Meget ubehageligt'};
    
    vars.Questions{2,1} = 'Dizzy';
    vars.Questions{2,2} = 'Jeg føler mig svimmel / ør.';
    vars.Questions{2,3} = {'Slet ikke', 'Fuldstændigt'};
    
    vars.Questions{3,1} = 'Breathless';
    vars.Questions{3,2} = 'Jeg føler mig åndeløse / forpustet / har besvær ved at trække vejret.';
    vars.Questions{3,3} = {'Slet ikke', 'Fuldstændigt'};
    
    vars.Questions{4,1} = 'Asthma';
    vars.Questions{4,2} = 'Hvis du lider af astma, vurder da alvorsgraden af dine symptomer i løbet af den sidste uge.';
    vars.Questions{4,3} = {'Ingen astma /ingen symptomer', 'Meget alvorlige symptomer'};
    
end

vars.nQuestions = length(vars.Questions);
vars.randQOrder = mixArray([1:vars.nQuestions]);
Results.ExpRateTask = NaN .* ones(1, vars.nBreaks);
Results.ExpRareEnd = NaN .* ones(1, vars.nQuestions);
