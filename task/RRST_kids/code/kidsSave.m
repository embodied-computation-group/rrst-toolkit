function file = kidsSave(cfg, vars, stim, result)
%KIDSSAVE Save an RRST-Kids session: .mat with everything, .csv with one row per trial.
%   file = kidsSave(cfg, vars, stim, result)
%   Name: [MOCK_|SIM_][Aborted_|Error_|PracticeFailed_]RRSTkids_<ID>_<date>.mat
prefix = "";
switch extractBefore(result.outcome + ":", ":")
    case "aborted", prefix = "Aborted_";
    case "error", prefix = "Error_";
    case "practiceFailed", prefix = "PracticeFailed_";
end
if ~isempty(cfg.debug.simulateChild), prefix = "SIM_" + prefix; end
if cfg.device.mock, prefix = "MOCK_" + prefix; end
name = prefix + sprintf('RRSTkids_%04d_%s', vars.subNo, datestr(now, 'yyyy-mm-dd_HHMM')); %#ok<TNOW1,DATST>
if ~exist(cfg.output.dir, 'dir'), mkdir(cfg.output.dir); end
file = fullfile(cfg.output.dir, name + ".mat");

session.result = result;
session.cfg = cfg;
session.vars = vars;
session.device = stim.summary();
if ~isempty(result.kp) && ~isempty(result.kp.PM.threshold)
    session.threshold = result.kp.PM.threshold(end);
    session.seThreshold = result.kp.PM.seThreshold(end);
    session.slope = 10 ^ result.kp.PM.slope(end);
    session.guess = result.kp.PM.guess(end);
else
    [session.threshold, session.seThreshold, session.slope, session.guess] = deal(NaN);
end
save(file, '-struct', 'session');

rows = [result.practice, result.trials];
if ~isempty(rows)
    writetable(struct2table(rows(:)), fullfile(cfg.output.dir, name + ".csv"));
end
fprintf('Outcome: %s. Saved %s\n', result.outcome, file);
if ~isnan(session.threshold)
    fprintf('Threshold %.1f %% (SE %.1f), slope %.1f, false alarms (guess) %.2f\n', ...
        session.threshold, session.seThreshold, session.slope, session.guess);
end
if ~isempty(result.flags) && result.flags.unusable
    fprintf(2, 'FLAG: threshold unusable: %s\n', result.flags.reason);
end
end
