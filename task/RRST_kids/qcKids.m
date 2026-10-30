function qcKids(matFile, outPng)
%QCKIDS Quality-control figure for one saved RRST-Kids session. Nothing moves.
%   qcKids("data/raw/RRSTkids_9001_2026-10-28_1712.mat")
%   qcKids(matFile, "bench/sessions/<folder>/qc.png")
%
%   A  Trials: level per main trial (filled = "squishy", open = "easy"; catch
%      trials at 0 as diamonds) and the Psi threshold after each answer with a
%      95 % band (+/- 1.96 posterior SE).
%   B  P("squishy") per level (marker area = number of trials), the Weibull at the
%      final estimate with its guess rate (yes-bias) and a 95 % band from the
%      final posterior, and the threshold.
%   C  Response time by answer.  D  Summary: estimates, false alarms, flags.
%   Without outPng the PNG is written next to the .mat file.

if nargin < 2
    [d, name] = fileparts(matFile);
    outPng = fullfile(d, name + "_qc.png");
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'code'));
S = load(matFile);
cfg = S.cfg; kp = S.result.kp; PM = kp.PM;
tr = S.result.trials;
[~, name] = fileparts(matFile);
if isempty(tr) || ~any(string([tr.phase]) == "main")   % stopped in the tutorial or practice
    error('rrst:qcNoMainTrials', ['%s has no main trials (outcome %s): nothing to fit. ' ...
        'The tutorial and practice slurps are in result.practice.'], name, string(S.result.outcome));
end
tr = tr(string([tr.phase]) == "main");
n = numel(tr);
lev = [tr.level]; resp = [tr.response]; isCatch = [tr.isCatch];
yes = resp == 1; no = resp == 0;

blue = hex2rgb("#2a78d6"); orange = hex2rgb("#eb6834");
ink = hex2rgb("#2b2b29"); muted = hex2rgb("#8a8a84"); grid = hex2rgb("#e4e3df");

fig = figure('Visible', 'off', 'Color', hex2rgb("#fcfcfb"), 'Units', 'pixels', 'Position', [0 0 1400 900]);
tl = tiledlayout(fig, 2, 6, 'TileSpacing', 'loose', 'Padding', 'compact');
title(tl, sprintf('%s   %s, %d main trials (%d catch), outcome %s', strrep(name, '_', '\_'), ...
    cfg.label, n, sum(isCatch), S.result.outcome), 'Color', ink, 'FontSize', 13);
yl = [-5 cfg.child.hardCap + 10];

% A. Trials and threshold estimate
ax = nexttile(tl, [1 4]); hold(ax, 'on'); styleAxes(ax, ink, grid);
h = gobjects(0); lab = strings(0);
answered = find(~isnan(resp));                       % catch trials update the posterior too
th = PM.threshold(:)'; se = PM.seThreshold(:)';
k = answered(1:numel(th));
if ~isempty(th)
    pr = PM.priorAlphaRange([1 end]);
    fill(ax, [k fliplr(k)], [max(th - 1.96 * se, pr(1)), fliplr(min(th + 1.96 * se, pr(2)))], orange, ...
        'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    h(end+1) = plot(ax, k, th, '-', 'Color', orange, 'LineWidth', 2.5);
    lab(end+1) = sprintf('threshold estimate (95%% band), final %.1f', th(end));
end
plot(ax, 1:n, lev, '-', 'Color', [blue 0.35], 'LineWidth', 1.2, 'HandleVisibility', 'off');
plot(ax, [0.5 n + 0.5], cfg.child.hardCap * [1 1], ':', 'Color', ink, 'HandleVisibility', 'off');
text(ax, n + 0.4, cfg.child.hardCap, 'cap', 'Color', muted, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
m = ~isCatch & yes;
if any(m), h(end+1) = plot(ax, find(m), lev(m), 'o', 'MarkerSize', 8, 'MarkerFaceColor', blue, 'MarkerEdgeColor', 'w'); lab(end+1) = "squishy (yes)"; end
m = ~isCatch & no;
if any(m), h(end+1) = plot(ax, find(m), lev(m), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', blue, 'LineWidth', 1.5); lab(end+1) = "easy (no)"; end
m = isCatch & yes;
if any(m), h(end+1) = plot(ax, find(m), lev(m), 'd', 'MarkerSize', 9, 'MarkerFaceColor', orange, 'MarkerEdgeColor', 'w'); lab(end+1) = "catch: false alarm"; end
m = isCatch & no;
if any(m), h(end+1) = plot(ax, find(m), lev(m), 'd', 'MarkerSize', 9, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', orange, 'LineWidth', 1.5); lab(end+1) = "catch: correct no"; end
m = isnan(resp);
if any(m), h(end+1) = plot(ax, find(m), lev(m), 'x', 'MarkerSize', 9, 'Color', muted, 'LineWidth', 1.5); lab(end+1) = "repeated"; end
ylabel(ax, sprintf('Level (%s of adult scale)', cfg.stim.unit)); xlabel(ax, 'Main trial');
xlim(ax, [0.5 n + 0.5]); ylim(ax, yl);
title(ax, 'Trials', 'Color', ink);
legend(ax, h, lab, 'Location', 'northoutside', 'TextColor', ink, 'Box', 'off', 'NumColumns', 3);

% B. Psychometric function
ax = nexttile(tl, [1 2]); hold(ax, 'on'); styleAxes(ax, ink, grid);
x = linspace(0, yl(2), 300);
a = PM.threshold(end); b = 10 ^ PM.slope(end); g = PM.guess(end); lam = PM.priorLambdaRange(1);
[lo, hi] = posteriorBand(PM, x, lam);
fill(ax, [x fliplr(x)], [lo fliplr(hi)], orange, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(ax, x, PAL_Weibull([a b g lam], x), '-', 'Color', orange, 'LineWidth', 2.5);
pa = PAL_Weibull([a b g lam], a);
plot(ax, [a a], [0 pa], '--', 'Color', orange, 'LineWidth', 1.5);
plot(ax, a, pa, 'o', 'MarkerSize', 9, 'MarkerFaceColor', orange, 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
text(ax, 2, 0.97, sprintf('\\alpha = %.1f\n\\beta = %.1f\n\\gamma = %.2f (yes-bias)', a, b, g), 'Color', ink, ...
    'VerticalAlignment', 'top', 'FontSize', 10);
valid = ~isnan(resp);
u = unique(lev(valid));
for j = 1:numel(u)
    m = valid & lev == u(j);
    scatter(ax, u(j), mean(resp(m)), 40 + 60 * sum(m), blue, 'filled', 'MarkerFaceAlpha', 0.6, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 1);
end
xlim(ax, [-3 yl(2)]); ylim(ax, [-0.03 1.03]);
xlabel(ax, sprintf('Level (%s)', cfg.stim.unit)); ylabel(ax, 'P("squishy")');
title(ax, 'Psychometric function', 'Color', ink);

% C. Response time by answer
ax = nexttile(tl, [1 3]); hold(ax, 'on'); styleAxes(ax, ink, grid);
rt = [tr.rt]; rs = RandStream('mt19937ar', 'Seed', 1);
groups = {no, yes}; names = ["easy (no)", "squishy (yes)"];
for gi = 1:2
    m = groups{gi} & ~isnan(rt);
    xj = gi + 0.18 * (rand(rs, 1, sum(m)) - 0.5);
    plot(ax, xj(~isCatch(m)), rt(m & ~isCatch), 'o', 'MarkerSize', 7, 'MarkerFaceColor', blue, 'MarkerEdgeColor', 'w');
    plot(ax, xj(isCatch(m)), rt(m & isCatch), 'd', 'MarkerSize', 8, 'MarkerFaceColor', orange, 'MarkerEdgeColor', 'w');
    if any(m), plot(ax, gi + [-0.25 0.25], median(rt(m)) * [1 1], '-', 'Color', ink, 'LineWidth', 2); end
end
set(ax, 'XTick', 1:2, 'XTickLabel', names + " (n=" + [sum(no) sum(yes)] + ")");
xlim(ax, [0.4 2.6]); ylim(ax, [0 max([rt 3]) + 0.3]);
ylabel(ax, 'Response time (s, experimenter click)'); title(ax, 'Response time', 'Color', ink);

% D. Summary
ax = nexttile(tl, [1 3]); axis(ax, 'off');
f = kidsFlags(kp, cfg);
prac = S.result.practice;
if ~isempty(prac), prac = prac([prac.phase] == "practice"); end   % not the tutorial's trials
lines = [
    string(sprintf('Threshold        %.1f %%   (SE %.1f)', S.threshold, S.seThreshold))
    string(sprintf('Slope (beta)     %.1f', S.slope))
    string(sprintf('Yes-bias (gamma) %.2f', S.guess))
    string(sprintf('False alarms     %d of %d catch trials (%.0f %%)', sum(isCatch & yes), sum(isCatch & valid), 100 * f.faRate))
    string(sprintf('Hits at >= %d    %s', cfg.child.flagHighLevel, rateText(f.hitRateHigh, sum(~isCatch & valid & lev >= cfg.child.flagHighLevel))))
    string(sprintf('Unusable flag    %s', string(f.unusable)))
    string(sprintf('Practice         %d of %d correct', sum([prac.response] == ([prac.level] > 0)), numel(prac)))
    string(sprintf('Repeated trials  %d', sum(isnan(resp))))
    string(sprintf('Duration         %.1f min', S.result.duration / 60))
    ];
text(ax, 0, 1, lines, 'FontName', 'Consolas', 'FontSize', 12, 'Color', ink, 'VerticalAlignment', 'top', 'Interpreter', 'none');
title(ax, 'Summary', 'Color', ink);

exportgraphics(fig, outPng, 'Resolution', 150);
close(fig);
fprintf('QC figure: %s\n', outPng);
end

function s = rateText(r, nTrials)
if isnan(r), s = sprintf('none (%d trials)', nTrials); else, s = sprintf('%.0f %% (%d trials)', 100 * r, nTrials); end
end

function [lo, hi] = posteriorBand(PM, x, lam)
% 2.5 and 97.5 % of P(yes) over draws from the final posterior (alpha, beta, gamma).
p = sum(PM.pdf, 4);                                   % alpha x beta x gamma
[A, B, G] = ndgrid(PM.priorAlphaRange, PM.priorBetaRange, PM.priorGammaRange);
rs = RandStream('mt19937ar', 'Seed', 1);
c = cumsum(p(:)) / sum(p(:));
idx = arrayfun(@(r) find(c >= r, 1), rand(rs, 2000, 1));
f = zeros(numel(idx), numel(x));
for k = 1:numel(idx)
    f(k, :) = PAL_Weibull([A(idx(k)) 10 ^ B(idx(k)) G(idx(k)) lam], x);
end
f = sort(f);
lo = f(round(0.025 * numel(idx)), :);
hi = f(round(0.975 * numel(idx)), :);
end

function styleAxes(ax, ink, grid)
set(ax, 'Color', 'none', 'XColor', ink, 'YColor', ink, 'GridColor', grid, 'GridAlpha', 1, ...
    'YGrid', 'on', 'XGrid', 'off', 'Box', 'off', 'TickDir', 'out', 'FontSize', 10);
end

function c = hex2rgb(h)
h = char(h);
c = double([hex2dec(h(2:3)) hex2dec(h(4:5)) hex2dec(h(6:7))]) / 255;
end
