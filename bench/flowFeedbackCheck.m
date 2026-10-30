function res = flowFeedbackCheck(durationS, opts)
%FLOWFEEDBACKCHECK Live airflow bar and display lag, before any breath-feedback run.
%   flowFeedbackCheck            20 s in a small window
%   flowFeedbackCheck(60)        60 s
%   flowFeedbackCheck(20, SmallWindow=false)   full screen on the task screen
%   res = flowFeedbackCheck(...) also return the numbers and the raw samples
%
%   No device, no calibration, no breath detection. Needs the "Flow" LSL stream
%   (Physio Recorder with the RRST preset, or plux-lsl/flow_lsl.py). Opens a window
%   with a bar whose height is the latest flow (0 to MaxSlm, default 60 slm);
%   breathe through the circuit and watch it follow. Esc stops early.
%
%   Every second the console shows the lag between the newest sample's timestamp
%   and the onset of the Flip that first drew it. At the end: median and 95th
%   percentile lag, sample rate, gaps, and the flow at rest. The lag includes the
%   bridge read (flow_lsl.py stamps a chunk when it asks the bridge for it), LSL,
%   the wait for the frame and the flip. In a small window on Windows the
%   compositor adds a frame or so; SmallWindow=false on the task screen measures
%   what the task will see.

arguments
    durationS (1, 1) double {mustBePositive} = 20
    opts.LiblslDir {mustBeTextScalar} = "C:\toolbox\liblsl-Matlab"
    opts.Timeout (1, 1) double {mustBePositive} = 10
    opts.MaxSlm (1, 1) double {mustBePositive} = 60
    opts.SmallWindow (1, 1) logical = true
end

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'task', 'helpers'));

src = flowInlet(opts.LiblslDir, opts.Timeout);
closeSrc = onCleanup(@() src.close());
fprintf('Airflow stream "%s" from %s, %g Hz nominal, times on the %s clock.\n', ...
    src.name, src.hostname, src.nominalRate, src.clockBase);
[~, msg] = src.check(1);
fprintf('Sensor check (1 s, should be at rest): %s\n', msg);

KbName('UnifyKeyNames');
escKey = KbName('ESCAPE');
scr = openWindow(opts.SmallWindow);
closeWin = onCleanup(@() closeWindow());

w = scr.winRect(3) - scr.winRect(1);
h = scr.winRect(4) - scr.winRect(2);
barW = round(w / 8);
barFrame = CenterRectOnPoint([0 0 barW round(0.75 * h)], w / 2, h / 2);
fprintf('\nBreathe through the circuit; the bar follows the flow. Esc stops.\n');
fprintf('   time   frames  samples   lag median    max      flow\n');

chunks = {};
lags = zeros(0, 1);
batchLags = zeros(0, 1);
batchFrames = 0;
batchSamples = 0;
latest = 0;
nFrames = 0;
lostSaid = false;
t0 = Screen('Flip', scr.win);
tBatch = t0;
onset = t0;
while onset - t0 < durationS
    s = src.pull();
    newest = NaN;
    if ~isempty(s)
        chunks{end + 1} = s; %#ok<AGROW>
        latest = s(end, 2);
        newest = s(end, 1);
        batchSamples = batchSamples + size(s, 1);
    end
    if src.lost && ~lostSaid
        fprintf(2, 'The airflow stream has stopped sending. Restart it and run the check again.\n');
        lostSaid = true;
    end

    level = min(max(latest, 0), opts.MaxSlm) / opts.MaxSlm;
    bar = barFrame;
    bar(2) = barFrame(4) - level * (barFrame(4) - barFrame(2));
    Screen('FillRect', scr.win, [1 1 1], barFrame);
    Screen('FillRect', scr.win, scr.colours.bar, bar);
    Screen('FrameRect', scr.win, scr.colours.text, barFrame, 2);
    DrawFormattedText(scr.win, sprintf('%.1f slm', latest), 'center', barFrame(2) - 0.05 * h, scr.colours.text);
    DrawFormattedText(scr.win, sprintf('0 to %g slm.  Esc stops.', opts.MaxSlm), 'center', ...
        barFrame(4) + 0.08 * h, scr.colours.text);
    [~, onset] = Screen('Flip', scr.win);
    nFrames = nFrames + 1;
    batchFrames = batchFrames + 1;
    if ~isnan(newest)
        lags(end + 1, 1) = onset - newest; %#ok<AGROW>
        batchLags(end + 1, 1) = onset - newest; %#ok<AGROW>
    end

    if onset - tBatch >= 1
        fprintf('  %5.1f s  %5d  %7d   %7.1f ms  %6.1f ms  %6.1f slm\n', onset - t0, batchFrames, ...
            batchSamples, 1000 * median(batchLags), 1000 * max([batchLags; NaN]), latest);
        tBatch = onset;
        batchLags = zeros(0, 1);
        batchFrames = 0;
        batchSamples = 0;
    end
    [down, ~, keys] = KbCheck(-1);
    if down && keys(escKey)
        fprintf('Stopped with Esc.\n');
        break
    end
end
tEnd = onset;
clear closeWin

S = cat(1, chunks{:});
if isempty(S)
    S = zeros(0, 2);
end
res = struct('durationS', tEnd - t0, 'nFrames', nFrames, 'frameRate', nFrames / (tEnd - t0), ...
    'lagS', lags, 'lagMedianMs', 1000 * median(lags), 'lagP95Ms', 1000 * pct(lags, 95), ...
    'nSamples', size(S, 1), 'sampleRate', NaN, 'nGaps', src.nGaps, 'nDropped', src.nDropped, ...
    'restSlm', NaN, 'peakSlm', NaN, 'samples', S, 'smallWindow', opts.SmallWindow, ...
    'clockBase', src.clockBase);
if size(S, 1) > 1
    res.sampleRate = (size(S, 1) - 1) / (S(end, 1) - S(1, 1));
    rest = S(S(:, 2) < flowInlet.MinBreathSlm, 2);
    res.restSlm = median(rest);
    res.peakSlm = max(S(:, 2));
    res.breathingS = sum(S(:, 2) >= flowInlet.MinBreathSlm) / res.sampleRate;
end

fprintf('\nflowFeedbackCheck, %.1f s, %d frames (%.1f Hz), %s window\n', res.durationS, ...
    res.nFrames, res.frameRate, ternary(opts.SmallWindow, 'small', 'full-screen'));
fprintf('  lag, newest sample to the flip that drew it: median %.1f ms, 95th percentile %.1f ms (%d frames with new samples)\n', ...
    res.lagMedianMs, res.lagP95Ms, numel(lags));
fprintf('  samples: %d at %.1f Hz; gaps %d, %d samples lost\n', res.nSamples, res.sampleRate, ...
    res.nGaps, res.nDropped);
fprintf('  flow at rest (median of samples under %g slm): %.2f slm; peak %.1f slm\n', ...
    flowInlet.MinBreathSlm, res.restSlm, res.peakSlm);
if isfield(res, 'breathingS')
    fprintf('  time above %g slm (breathing): %.1f s\n', flowInlet.MinBreathSlm, res.breathingS);
end
end

function scr = openWindow(small)
Screen('Preference', 'SkipSyncTests', 1);       % as runKidsRRST
Screen('Preference', 'VisualDebugLevel', 0);
scr.screenID = max(Screen('Screens'));
scr.colours = struct('background', [0.55 0.82 0.95], 'bar', [150 80 200] / 255, ...
    'text', [0.1 0.1 0.25]);                    % kidsMain's openScreen colours
PsychImaging('PrepareConfiguration');
if small
    r = Screen('Rect', scr.screenID);
    [scr.win, scr.winRect] = PsychImaging('OpenWindow', scr.screenID, scr.colours.background, [0 0 r(3) r(4)] / 3);
else
    [scr.win, scr.winRect] = PsychImaging('OpenWindow', scr.screenID, scr.colours.background);
end
Screen('ColorRange', scr.win, 1);
Screen('BlendFunction', scr.win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
Screen('TextFont', scr.win, 'Arial');
Screen('TextSize', scr.win, max(14, round(48 * scr.winRect(4) / 1440)));
Priority(MaxPriority(scr.win));
end

function closeWindow()
sca;
Priority(0);
end

function v = pct(x, p)
% Percentile by linear interpolation (prctile needs the Statistics Toolbox before R2022a).
x = sort(x(isfinite(x)));
if isempty(x)
    v = NaN;
    return
end
k = 1 + (numel(x) - 1) * p / 100;
v = x(floor(k)) + (k - floor(k)) * (x(ceil(k)) - x(floor(k)));
end

function out = ternary(c, a, b)
if c
    out = a;
else
    out = b;
end
end
