function kp = kidsProcedure(cfg, seed)
%KIDSPROCEDURE Set up the RRST-Kids yes/no Psi procedure.
%   kp = kidsProcedure(cfg, seed)
%
%   kp.PM        Palamedes Psi structure: Weibull for p(yes), guess rate (yes-bias)
%                marginalised, lapse fixed.
%   kp.schedule  logical, true = catch trial (level 0), from kidsSchedule
%   kp.k         index of the next trial in the schedule
%   kp.nPsiDone, kp.runningMax, kp.nRepeats, kp.history (level, response, isCatch)
%
%   Use: [level, info] = kidsNextLevel(kp, cfg); present it; then
%   kp = kidsRecord(kp, level, response, info), or kp = kidsRequeue(kp) if there
%   was no usable answer. Stop when kidsShouldStop(kp, cfg).
p = cfg.psi;
kp.PM = PAL_AMPM_setupPM('priorAlphaRange', p.priorAlphaRange, ...
    'priorBetaRange', p.priorBetaRange, ...
    'priorGammaRange', p.priorGammaRange, ...
    'priorLambdaRange', p.priorLambdaRange, ...
    'numtrials', cfg.child.numPsiTrials + cfg.child.numCatchTrials, ...
    'PF', str2func(p.PF), ...
    'stimRange', p.stimRange, ...
    'marginalize', 'guess');
kp.schedule = kidsSchedule(cfg.child.numPsiTrials, cfg.child.numCatchTrials, seed);
kp.k = 1;
kp.nPsiDone = 0;
kp.runningMax = 0;
kp.nRepeats = 0;
kp.history = struct('level', {}, 'response', {}, 'isCatch', {});
end
