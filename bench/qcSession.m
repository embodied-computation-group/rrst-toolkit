function qcSession(matFile, outPng)
%QCSESSION Quality-control figure for one saved RRST 2.0 Psi session. Nothing moves.
%   qcSession("data/raw/RRST_9999_psi_2026-10-28_1409.mat")
%   qcSession(matFile, "bench/sessions/<folder>/qc.png")
%
%   A  Staircase: level per trial (filled = correct, open = incorrect, x = no
%      response) and the Psi threshold estimate after each trial with a 95 % band
%      (+/- 1.96 posterior SE), as in the methods paper (Fig. 2A) and Cardioception.
%   B  Psychometric function: proportion correct per level (marker area = number of
%      trials), the Weibull at the final Psi estimate, a 95 % band from the final
%      posterior, and the threshold.
%   C  Response time and D confidence by accuracy (methods paper Fig. 3).
%   E  Stimulus and null move times, a device check.
%   Without outPng the PNG is written next to the .mat file.

if nargin < 2
    [d, name] = fileparts(matFile);
    outPng = fullfile(d, name + "_qc.png");
end
S = load(matFile, 'Results', 'stair', 'vars');
R = S.Results; cfg = S.vars.cfg; PM = S.stair(1).PM;
n = numel(R.trialN);
t = 1:n;
row = @(v) reshape(v(1:n), 1, []);
lev = row(R.Stim); resp = row(R.Resp);
valid = row(R.trialSuccess) == 1 & ~isnan(resp);
ok = valid & resp == 1; bad = valid & resp == 0;
unit = char(cfg.stim.unit);

% Reference palette (light): categorical slots 1-2, ink, muted, grid, surface
blue = hex2rgb("#2a78d6"); orange = hex2rgb("#eb6834");
ink = hex2rgb("#2b2b29"); muted = hex2rgb("#8a8a84"); grid = hex2rgb("#e4e3df");

fig = figure('Visible', 'off', 'Color', hex2rgb("#fcfcfb"), 'Units', 'pixels', 'Position', [0 0 1400 900]);
tl = tiledlayout(fig, 2, 6, 'TileSpacing', 'loose', 'Padding', 'compact');
[~, name] = fileparts(matFile);
title(tl, sprintf('%s   %s, %d trials, %d valid, %d%% correct', strrep(name, '_', '\_'), ...
    cfg.procedure, n, sum(valid), round(100 * mean(resp(valid)))), 'Color', ink, 'FontSize', 13);

isPsi = cfg.procedure == "psi" && isfield(PM, 'threshold') && ~isempty(PM.threshold);
yl = [min([lev 50]) - 5, 100];

% A. Staircase with threshold estimate and its band
ax = nexttile(tl, [1 4]); hold(ax, 'on'); styleAxes(ax, ink, grid);
h = gobjects(0); lab = strings(0);
if isPsi
    th = PM.threshold(:)'; se = PM.seThreshold(:)'; k = 1:numel(th);
    pr = PM.priorAlphaRange([1 end]);                % the band cannot leave the prior
    fill(ax, [k fliplr(k)], [max(th - 1.96 * se, pr(1)), fliplr(min(th + 1.96 * se, pr(2)))], orange, ...
        'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    h(end+1) = plot(ax, k, th, '-', 'Color', orange, 'LineWidth', 2.5);
    lab(end+1) = sprintf('threshold estimate (95%% band), final %.1f', th(end));
end
plot(ax, t, lev, '-', 'Color', [blue 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');
[h, lab] = markers(ax, t, lev, ok, bad, ~valid, blue, muted, h, lab);
ylabel(ax, sprintf('Level (%s)', unit)); xlabel(ax, 'Trial');
xlim(ax, [0.5 n + 0.5]); ylim(ax, yl);
title(ax, 'Staircase', 'Color', ink);
legend(ax, h, lab, 'Location', 'southeast', 'TextColor', ink, 'Box', 'off');

% B. Psychometric function
ax = nexttile(tl, [1 2]); hold(ax, 'on'); styleAxes(ax, ink, grid);
x = linspace(yl(1), 100, 300);
if isPsi
    gam = PM.priorGammaRange(1); lam = PM.priorLambdaRange(1);
    [lo, hi] = posteriorBand(PM, x, gam, lam);
    fill(ax, [x fliplr(x)], [lo fliplr(hi)], orange, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    a = PM.threshold(end); b = 10 ^ PM.slope(end);
    plot(ax, x, PAL_Weibull([a b gam lam], x), '-', 'Color', orange, 'LineWidth', 2.5);
    pa = PAL_Weibull([a b gam lam], a);
    plot(ax, [a a], [0 pa], '--', 'Color', orange, 'LineWidth', 1.5);
    plot(ax, a, pa, 'o', 'MarkerSize', 9, 'MarkerFaceColor', orange, 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
    text(ax, yl(1) + 2, 0.97, sprintf('\\alpha = %.1f\n\\beta = %.1f', a, b), 'Color', ink, ...
        'VerticalAlignment', 'top', 'FontSize', 10);
    plot(ax, yl, [0.5 0.5], ':', 'Color', ink, 'LineWidth', 1);   % chance
end
u = unique(lev(valid));
for k = 1:numel(u)
    m = valid & lev == u(k);
    scatter(ax, u(k), mean(resp(m)), 40 + 60 * sum(m), blue, 'filled', 'MarkerFaceAlpha', 0.6, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 1);
end
xlim(ax, yl); ylim(ax, [-0.03 1.03]);
xlabel(ax, sprintf('Level (%s)', unit)); ylabel(ax, 'P(correct)');
title(ax, 'Psychometric function', 'Color', ink);

% C. Response time by accuracy
ax = nexttile(tl, [1 2]); hold(ax, 'on'); styleAxes(ax, ink, grid);
byAccuracy(ax, row(R.RT), ok, bad, blue, ink);
ylabel(ax, 'Response time (s)'); title(ax, 'Response time', 'Color', ink);

% D. Confidence by accuracy
ax = nexttile(tl, [1 2]); hold(ax, 'on'); styleAxes(ax, ink, grid);
byAccuracy(ax, row(R.ConfResp), ok, bad, blue, ink);
ylim(ax, [-5 105]); ylabel(ax, 'Confidence (0 guess, 100 certain)');
title(ax, 'Confidence', 'Color', ink);

% E. Move times
ax = nexttile(tl, [1 2]); hold(ax, 'on'); styleAxes(ax, ink, grid);
plot(ax, t, row(R.StimMoveT), '-o', 'Color', blue, 'MarkerFaceColor', blue, 'MarkerSize', 5, 'LineWidth', 1.5);
plot(ax, t, row(R.NullMoveT), '--s', 'Color', orange, 'MarkerFaceColor', orange, 'MarkerSize', 5, 'LineWidth', 1.5);
xlim(ax, [0.5 n + 0.5]); ylim(ax, [0 max(3.2, max([row(R.StimMoveT) row(R.NullMoveT)]) + 0.2)]);
xlabel(ax, 'Trial'); ylabel(ax, 'Move time (s)'); title(ax, 'Device moves', 'Color', ink);
legend(ax, ["stimulus", "null"], 'Location', 'south', 'Orientation', 'horizontal', 'TextColor', ink, 'Box', 'off');

exportgraphics(fig, outPng, 'Resolution', 150);
close(fig);
fprintf('QC figure: %s\n', outPng);
end

function [h, lab] = markers(ax, t, y, ok, bad, none, col, muted, h, lab)
if any(ok)
    h(end+1) = plot(ax, t(ok), y(ok), 'o', 'MarkerSize', 8, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'w');
    lab(end+1) = "correct";
end
if any(bad)
    h(end+1) = plot(ax, t(bad), y(bad), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', col, 'LineWidth', 1.5);
    lab(end+1) = "incorrect";
end
if any(none)
    h(end+1) = plot(ax, t(none), y(none), 'x', 'MarkerSize', 9, 'Color', muted, 'LineWidth', 1.5);
    lab(end+1) = "no response";
end
end

function byAccuracy(ax, v, ok, bad, col, ink)
% Jittered points with the median as a bar: correct filled, incorrect open.
rs = RandStream('mt19937ar', 'Seed', 1);
groups = {bad, ok}; names = ["incorrect", "correct"];
for g = 1:2
    m = groups{g} & ~isnan(v);
    xj = g + 0.18 * (rand(rs, 1, sum(m)) - 0.5);
    if g == 2
        plot(ax, xj, v(m), 'o', 'MarkerSize', 7, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'w');
    else
        plot(ax, xj, v(m), 'o', 'MarkerSize', 7, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', col, 'LineWidth', 1.5);
    end
    if any(m)
        plot(ax, g + [-0.25 0.25], median(v(m)) * [1 1], '-', 'Color', ink, 'LineWidth', 2);
    end
end
set(ax, 'XTick', 1:2, 'XTickLabel', names + " (n=" + [sum(bad) sum(ok)] + ")");
xlim(ax, [0.4 2.6]);
end

function [lo, hi] = posteriorBand(PM, x, gam, lam)
% 2.5 and 97.5 % of the psychometric function over draws from the final posterior.
p = squeeze(sum(sum(PM.pdf, 4), 3));                % alpha x beta
[A, B] = ndgrid(PM.priorAlphaRange, PM.priorBetaRange);
rs = RandStream('mt19937ar', 'Seed', 1);
c = cumsum(p(:)) / sum(p(:));
idx = arrayfun(@(r) find(c >= r, 1), rand(rs, 2000, 1));
f = zeros(numel(idx), numel(x));
for k = 1:numel(idx)
    f(k, :) = PAL_Weibull([A(idx(k)) 10 ^ B(idx(k)) gam lam], x);
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
