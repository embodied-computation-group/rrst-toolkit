function line = kidsRunReport(kp, cfg, what, why)
%KIDSRUNREPORT The experimenter's console lines about the main trials (pure).
%   line = kidsRunReport(kp, cfg, "plan")             at main start: how many trials
%   line = kidsRunReport(kp, cfg, "progress")         after every answer: the estimate
%                                                     and where the early stop stands
%   line = kidsRunReport(kp, cfg, "end", why)         why it stopped (kidsShouldStop:
%                                                     "precise", "complete", "repeats")
%
%   kp from kidsProcedure (the trials so far), cfg.child (numPsiTrials,
%   numCatchTrials, stopSE, stopMinTrials, maxRepeats). Second real run (2026-10-30):
%   with 20 Psi + 8 catch trials the session went to "trial 21" and a third break,
%   which looked like a bug; the early stop needs stopMinTrials *Psi* trials.
%   Console only: kidsMain prints these, the child sees none of it.
c = cfg.child;
nPlanned = numel(kp.schedule);
nRun = kp.k - 1;
rule = sprintf('SE < %g after %d Psi trials', c.stopSE, c.stopMinTrials);
[th, se] = estimate(kp);
switch string(what)
    case "plan"
        line = sprintf('Main trials: up to %d (%d Psi + %d catch). Early stop: %s.', ...
            nPlanned, c.numPsiTrials, c.numCatchTrials, rule);
    case "progress"
        if isnan(se)
            line = sprintf('No estimate yet. Early stop: %s.', rule);
            return
        end
        cur = sprintf('now SE %.1f after %d', se, kp.nPsiDone);
        if kp.nPsiDone < c.stopMinTrials
            more = c.stopMinTrials - kp.nPsiDone;
            state = sprintf('%s (%d more Psi trial%s needed)', cur, more, plural(more));
        elseif se < c.stopSE
            state = [cur ': stops now'];
        else
            left = nPlanned - nRun;
            state = sprintf('%s: goes on (%d trial%s left)', cur, left, plural(left));
        end
        line = sprintf('Threshold %.1f %%, SE %.1f. Early stop: %s; %s.', th, se, rule, state);
    case "end"
        if nargin < 4, why = ""; end
        switch string(why)
            case "precise"
                line = sprintf('Stopped early: SE %.1f < %g after %d Psi trials (%d of up to %d trials run). Threshold %.1f %%.', ...
                    se, c.stopSE, kp.nPsiDone, nRun, nPlanned, th);
            case "complete"
                nCatch = nnz([kp.history.isCatch]);
                line = sprintf(['Stopped: all %d planned trials run (%d Psi, %d catch); SE %.1f ' ...
                    '(the early stop needs %s). Threshold %.1f %%.'], nPlanned, kp.nPsiDone, nCatch, se, rule, th);
            case "repeats"
                line = sprintf(['Stopped: more than %d repeated trials (no answer, bad breath or pause). ' ...
                    'Threshold %.1f %%, SE %.1f.'], c.maxRepeats, th, se);
            otherwise
                error('rrst:badPrompt', 'Unknown stop reason "%s".', why);
        end
    otherwise
        error('rrst:badPrompt', 'kidsRunReport: what must be "plan", "progress" or "end".');
end
end

function [th, se] = estimate(kp)
% The posterior's threshold and its SE after the last answer (NaN before any).
th = NaN; se = NaN;
if isfield(kp.PM, 'threshold') && ~isempty(kp.PM.threshold), th = kp.PM.threshold(end); end
if isfield(kp.PM, 'seThreshold') && ~isempty(kp.PM.seThreshold), se = kp.PM.seThreshold(end); end
end

function s = plural(n)
if n == 1, s = ''; else, s = 's'; end
end
