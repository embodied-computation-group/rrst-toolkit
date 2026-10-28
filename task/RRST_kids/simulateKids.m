function T = simulateKids(cfg, nSim)
%SIMULATEKIDS Simulate RRST-Kids sessions for a range of children. No screen, no device.
%   T = simulateKids()            kidsConfig, 200 runs per profile
%   T = simulateKids(cfg, nSim)
%
%   Each simulated child answers yes/no with a Weibull p(yes) = [alpha beta gamma
%   lambda]: threshold alpha (% of the adult scale), slope 8, false-alarm rate gamma
%   and lapse 0.1. Reports, per profile, the threshold bias and RMS error, the final
%   posterior SE, trials used, how often the run stopped early, and how often it was
%   flagged unusable. Practice is not simulated.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'code'), fullfile(here, 'config'));
if nargin < 1 || isempty(cfg), cfg = kidsConfig(); end
if nargin < 2, nSim = 200; end
alphas = [55 70 80];
gammas = [0.05 0.2 0.35];
rows = {};
for a = alphas
    for g = gammas
        est = nan(nSim, 1); se = est; n = est; early = false(nSim, 1); flagged = early; maxLevel = est;
        for s = 1:nSim
            kp = kidsProcedure(cfg, s);
            rs = RandStream('mt19937ar', 'Seed', 1e4 + s);
            while ~kidsShouldStop(kp, cfg)
                [level, info] = kidsNextLevel(kp, cfg);
                kidsCheckLevel(level, cfg);
                kp = kidsRecord(kp, level, rand(rs) < PAL_Weibull([a 8 g 0.1], level), info);
            end
            [~, why] = kidsShouldStop(kp, cfg);
            est(s) = kp.PM.threshold(end); se(s) = kp.PM.seThreshold(end);
            n(s) = numel(kp.history); early(s) = why == "precise";
            f = kidsFlags(kp, cfg); flagged(s) = f.unusable;
            maxLevel(s) = max([kp.history.level]);
        end
        rows(end + 1, :) = {a, g, mean(est) - a, sqrt(mean((est - a).^2)), mean(se), mean(n), ...
            mean(early), mean(flagged), max(maxLevel)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'trueThreshold', 'falseAlarm', 'bias', 'rmsError', ...
    'meanSE', 'meanTrials', 'fracStoppedEarly', 'fracFlagged', 'maxLevel'});
disp(T);
end
