function qcSession(matFile, outPng)
%QCSESSION Quality-control figure for one saved RRST 2.0 session. Nothing moves.
%   qcSession("data/raw/RRST_9999_psi_2026-10-28_1329.mat")
%   qcSession(matFile, "bench/sessions/<folder>/qc.png")
%
%   Three panels over trial number: the staircase (presented level, correct /
%   incorrect / no response, and the Psi threshold estimate after each trial), the
%   confidence ratings, and how long the stimulus and null moves took. Without
%   outPng the PNG is written next to the .mat file.

if nargin < 2
    [d, name] = fileparts(matFile);
    outPng = fullfile(d, name + "_qc.png");
end
S = load(matFile, 'Results', 'stair', 'vars');
R = S.Results; cfg = S.vars.cfg;
n = numel(R.trialN);
t = 1:n;
resp = R.Resp(1:n);
valid = R.trialSuccess(1:n) == 1 & ~isnan(resp);

% Reference palette (light): categorical slots 1-2, ink and grid
blue = hex2rgb("#2a78d6"); orange = hex2rgb("#eb6834");
ink = hex2rgb("#2b2b29"); muted = hex2rgb("#8a8a84"); grid = hex2rgb("#e4e3df");

fig = figure('Visible', 'off', 'Color', hex2rgb("#fcfcfb"), 'Units', 'pixels', 'Position', [0 0 1100 900]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
[~, name] = fileparts(matFile);
title(tl, sprintf('%s  (%s, %d trials, %d valid)', strrep(name, '_', '\_'), cfg.procedure, n, sum(valid)), ...
    'Color', ink, 'FontSize', 12);

% 1. Staircase
ax = nexttile(tl); hold(ax, 'on'); styleAxes(ax, ink, grid);
plot(ax, t, R.Stim(1:n), '-', 'Color', blue, 'LineWidth', 2, 'HandleVisibility', 'off');
ok = valid & resp == 1; bad = valid & resp == 0; none = ~valid;
h = gobjects(0); lab = strings(0);
if any(ok)
    h(end+1) = plot(ax, t(ok), R.Stim(ok), 'o', 'MarkerSize', 8, 'MarkerFaceColor', blue, 'MarkerEdgeColor', blue); lab(end+1) = "correct";
end
if any(bad)
    h(end+1) = plot(ax, t(bad), R.Stim(bad), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', blue, 'LineWidth', 1.5); lab(end+1) = "incorrect";
end
if any(none)
    h(end+1) = plot(ax, t(none), R.Stim(none), 'x', 'MarkerSize', 9, 'Color', muted, 'LineWidth', 1.5); lab(end+1) = "no response";
end
if cfg.procedure == "psi" && isfield(S.stair, 'PM') && ~isempty(S.stair.PM.threshold)
    th = S.stair.PM.threshold;
    h(end+1) = plot(ax, 1:numel(th), th, '--', 'Color', orange, 'LineWidth', 2); lab(end+1) = "Psi threshold estimate";
end
ylabel(ax, sprintf('Level (%s)', cfg.stim.unit)); ylim(ax, [0 100]);
legend(ax, h, lab, 'Location', 'southeast', 'TextColor', ink, 'Box', 'off');

% 2. Confidence
ax = nexttile(tl); hold(ax, 'on'); styleAxes(ax, ink, grid);
conf = R.ConfResp(1:n);
plot(ax, t(ok), conf(ok), 'o', 'MarkerSize', 8, 'MarkerFaceColor', blue, 'MarkerEdgeColor', blue);
plot(ax, t(bad), conf(bad), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', blue, 'LineWidth', 1.5);
ylabel(ax, 'Confidence (0 guess - 100 certain)'); ylim(ax, [-5 105]);

% 3. Move durations
ax = nexttile(tl); hold(ax, 'on'); styleAxes(ax, ink, grid);
plot(ax, t, R.StimMoveT(1:n), '-o', 'Color', blue, 'MarkerFaceColor', blue, 'MarkerSize', 6, 'LineWidth', 2);
plot(ax, t, R.NullMoveT(1:n), '--s', 'Color', orange, 'MarkerFaceColor', orange, 'MarkerSize', 6, 'LineWidth', 2);
ylabel(ax, 'Move time (s)'); xlabel(ax, 'Trial');
legend(ax, ["stimulus move", "null move"], 'Location', 'southeast', 'Orientation', 'horizontal', ...
    'TextColor', ink, 'Box', 'off');
yl = ylim(ax); ylim(ax, [0 max(yl(2), 3)]);

for ax = findobj(fig, 'Type', 'axes')', xlim(ax, [0.5 n + 0.5]); end
exportgraphics(fig, outPng, 'Resolution', 150);
close(fig);
fprintf('QC figure: %s\n', outPng);
end

function styleAxes(ax, ink, grid)
set(ax, 'Color', 'none', 'XColor', ink, 'YColor', ink, 'GridColor', grid, 'GridAlpha', 1, ...
    'YGrid', 'on', 'XGrid', 'off', 'Box', 'off', 'TickDir', 'out', 'FontSize', 10);
end

function c = hex2rgb(h)
h = char(h);
c = double([hex2dec(h(2:3)) hex2dec(h(4:5)) hex2dec(h(6:7))]) / 255;
end
