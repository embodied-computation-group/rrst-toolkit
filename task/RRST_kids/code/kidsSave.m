function file = kidsSave(cfg, vars, stim, result)
%KIDSSAVE Save an RRST-Kids session: .mat with everything, .csv with one row per trial.
%   file = kidsSave(cfg, vars, stim, result)
%   The per-slurp records (tr.slurps) are in the .mat only; the .csv has them as
%   nSlurps (counted slurps), slurpVolumeL and slurpPeakSlm (means over the counted
%   slurps, NaN if none), next to the trial's shortSlurps and flowLost.
%   Name: [MOCK_|SIM_][Aborted_|Error_|PracticeFailed_]RRSTkids_<ID>_<date>.mat, with _2, _3
%   added if that name is taken (never overwrites).
%   Standalone recording (kidsMain adds result.flow, N-by-2 [t flowSlm], and
%   result.markers, a table of t and label, both on the GetSecs clock): the flow is
%   also written to <name>_flow.csv (columns t, flow), next to the .mat.
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
name = string(uniqueFileName(cfg.output.dir, char(name)));   % never overwrite: _2, _3
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
    writetable(flatRows(rows(:)), fullfile(cfg.output.dir, name + ".csv"));
end
if isfield(result, 'flow')
    flowFile = fullfile(cfg.output.dir, name + "_flow.csv");
    writeFlow(flowFile, result.flow);
    nMarkers = 0;
    if isfield(result, 'markers'), nMarkers = height(result.markers); end
    fprintf('Flow: %d samples (%.1f min) and %d markers saved; the flow also in %s\n', ...
        size(result.flow, 1), size(result.flow, 1) / 1000 / 60, nMarkers, flowFile);
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

function writeFlow(file, flow)
% t (GetSecs, s) and flow (slm), one row per sample; fprintf: 1.2 million rows in seconds.
fid = fopen(file, 'w');
if fid < 0
    error('rrst:saveFailed', 'Cannot write %s.', file);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 't,flow\n');
if ~isempty(flow)
    fprintf(fid, '%.6f,%.4f\n', flow.');
end
end

function t = flatRows(rows)
% One row per trial: the slurp records become summary columns.
if ~isfield(rows, 'slurps')
    t = struct2table(rows);
    return
end
nSlurps = zeros(numel(rows), 1);
[vol, peak] = deal(nan(numel(rows), 1));
for k = 1:numel(rows)
    s = rows(k).slurps;
    if isempty(s), continue; end
    ok = logical([s.counted]);
    nSlurps(k) = nnz(ok);
    if any(ok)
        vol(k) = mean([s(ok).volumeL]);
        peak(k) = mean([s(ok).peakSlm]);
    end
end
t = struct2table(rmfield(rows, 'slurps'), 'AsArray', true);
t.nSlurps = nSlurps;
t.slurpVolumeL = vol;
t.slurpPeakSlm = peak;
end
