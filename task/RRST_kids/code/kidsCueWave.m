function x = kidsCueWave(name, fs)
%KIDSCUEWAVE Generate one RRST-Kids cue sound.
%   x = kidsCueWave(name, fs)
%
%   Returns an N-by-2 double in [-1, 1] at sample rate fs, peak 0.9, both channels
%   the same. Every cue starts and ends with a few ms of silence and a raised-cosine
%   fade, so the first and last 5 ms are near zero (no click when a cue starts or is
%   cut off). The noise in "slurp" comes from a fixed local random stream: the same
%   sound every session, and the task's random streams are not touched.
%
%   name        duration  sound
%   "ready"     0.4 s     two-note rising chime (G5, C6): "your turn"
%   "slurp"     0.6 s     soft rising "sluuurp": noise through a sweeping resonance
%   "bubbles"   0.8 s     four popping blips (rising-pitch bubble sounds)
%   "star"      0.5 s     bright sparkle arpeggio (C6 E6 G6 C7)
%   "cup"       1.2 s     short fanfare (G5 C6 E6, then a held C major chord)
%   "mouse"     0.8 s     quick high scamper ticks in two runs
%   "tryagain"  0.5 s     neutral soft two-note (E5, D5): a whole tone down, not "sad"
%   "squeak"    0.3 s     the cheeky mouse by the cup: two short rising chirps
%                         (1.7-2.6 kHz, then 2.3-3.4 kHz)
%
%   Unknown names error with rrst:badCue. kidsSound plays these over the rain loop.

if ~(isscalar(fs) && isnumeric(fs) && isfinite(fs) && fs >= 8000)
    error('rrst:badCue', 'kidsCueWave: fs must be a sample rate of at least 8000 Hz.');
end
name = lower(string(name));
if ~isscalar(name) || ~ismember(name, kidsCueNames())
    error('rrst:badCue', 'Unknown cue sound "%s". Known: %s.', strjoin(string(name), ''), ...
        strjoin(kidsCueNames(), ', '));
end

switch name
    case "ready"
        dur = 0.4;
        y = note(784.0, 0.00, 0.15, fs, dur) + note(1046.5, 0.15, 0.20, fs, dur);
    case "slurp"
        dur = 0.6;
        y = slurp(fs, dur);
    case "bubbles"
        dur = 0.8;
        y = zeros(round(dur * fs), 1);
        starts = [0.03 0.22 0.40 0.58];
        f0 = [420 560 480 640];
        for k = 1:numel(starts)
            y = y + bubble(f0(k), starts(k), fs, dur);
        end
    case "star"
        dur = 0.5;
        f = [1046.5 1318.5 1568.0 2093.0];
        y = zeros(round(dur * fs), 1);
        for k = 1:numel(f)
            y = y + note(f(k), 0.07 * (k - 1), 0.10 + 0.04 * (k == numel(f)), fs, dur, [1 0.25 0.08]);
        end
        % sparkle: faint high partials that twinkle on the last note
        t = (0:numel(y) - 1)' / fs;
        y = y + 0.15 * sin(2 * pi * 4186 * t) .* (t > 0.21) .* exp(-(t - 0.21) / 0.08) .* ...
            (0.5 + 0.5 * sin(2 * pi * 18 * t));
    case "cup"
        dur = 1.2;
        brass = [1 0.5 0.33 0.25 0.2 0.12];
        y = note(784.0, 0.00, 0.10, fs, dur, brass, 0.02) + ...
            note(1046.5, 0.12, 0.10, fs, dur, brass, 0.02) + ...
            note(1318.5, 0.24, 0.10, fs, dur, brass, 0.02);
        for f = [523.25 659.25 784.0 1046.5]       % held C major chord with vibrato
            y = y + 0.6 * held(f, 0.38, 0.78, fs, dur, brass);
        end
    case "mouse"
        dur = 0.8;
        y = zeros(round(dur * fs), 1);
        tick = [0.02 0.06 0.09 0.13 0.16 0.20 0.23 0.27, ...   % first run
            0.42 0.45 0.49 0.52 0.56 0.59 0.63 0.67];          % second run
        pitch = 2600 + 900 * mod((1:numel(tick)) * 0.37, 1);  % fixed, varied pitches
        for k = 1:numel(tick)
            y = y + tickSound(pitch(k), tick(k), fs, dur);
        end
    case "tryagain"
        dur = 0.5;
        soft = [1 0.15];
        y = note(659.25, 0.00, 0.12, fs, dur, soft, 0.03) + ...
            note(587.33, 0.24, 0.12, fs, dur, soft, 0.03);
    case "squeak"
        dur = 0.3;
        y = chirp(1700, 2600, 0.02, 0.09, fs, dur) + chirp(2300, 3400, 0.15, 0.10, fs, dur);
end
x = finish(y, fs);
end

function names = kidsCueNames()
names = ["ready" "slurp" "bubbles" "star" "cup" "mouse" "tryagain" "squeak"];
end

% --- building blocks ---------------------------------------------------------
function y = note(f, t0, tau, fs, dur, partials, attack)
%NOTE Decaying tone starting at t0 s, exponential decay with time constant tau.
if nargin < 6, partials = [1 0.3 0.1]; end
if nargin < 7, attack = 0.005; end
n = round(dur * fs);
t = (0:n - 1)' / fs - t0;
on = t >= 0;
env = on .* min(max(t, 0) / attack, 1) .* exp(-max(t, 0) / tau);
y = zeros(n, 1);
for k = 1:numel(partials)
    y = y + partials(k) * sin(2 * pi * k * f * max(t, 0));
end
y = y .* env;
end

function y = held(f, t0, t1, fs, dur, partials)
%HELD Tone held from t0 to t1 s with a soft attack, 5 Hz vibrato and a soft release.
n = round(dur * fs);
t = (0:n - 1)' / fs;
phase = 2 * pi * f * (t - t0) + 0.004 * f / 5 * (1 - cos(2 * pi * 5 * max(t - t0, 0)));
env = min(max(t - t0, 0) / 0.04, 1) .* (t >= t0);
env = env .* min(max((t1 + 0.15 - t) / 0.15, 0), 1);       % release after t1
y = zeros(n, 1);
for k = 1:numel(partials)
    y = y + partials(k) * sin(k * phase);
end
y = y .* env;
end

function y = bubble(f0, t0, fs, dur)
%BUBBLE A single pop: a sine whose pitch rises quickly as it decays.
n = round(dur * fs);
t = (0:n - 1)' / fs - t0;
tt = max(t, 0);
tau = 0.035;
f = f0 * (1 + 2.5 * tt / 0.05);                       % pitch rises as the bubble closes
phase = 2 * pi * cumsum(f) / fs;
env = (t >= 0) .* min(tt / 0.003, 1) .* exp(-tt / tau);
y = sin(phase) .* env;
end

function y = chirp(f0, f1, t0, len, fs, dur)
%CHIRP A short squeak from t0 s, len s long: the pitch rises linearly from f0 to f1
% under a smooth arch, with a little second harmonic.
n = round(dur * fs);
t = (0:n - 1)' / fs - t0;
on = t >= 0 & t <= len;
tt = min(max(t, 0), len);
f = f0 + (f1 - f0) * tt / len;
phase = 2 * pi * cumsum(f .* on) / fs;
env = on .* sin(pi * tt / len) .^ 0.6;
y = (sin(phase) + 0.2 * sin(2 * phase)) .* env;
end

function y = tickSound(f, t0, fs, dur)
%TICKSOUND A tiny click-like tick: a high sine burst, very short decay.
n = round(dur * fs);
t = (0:n - 1)' / fs - t0;
tt = max(t, 0);
env = (t >= 0) .* min(tt / 0.0008, 1) .* exp(-tt / 0.006);
y = sin(2 * pi * f * tt) .* env;
end

function y = slurp(fs, dur)
%SLURP Noise through a resonance that sweeps up (300 -> 1400 Hz), with a slow swell
% and a gurgling 22 Hz flutter.
n = round(dur * fs);
t = (0:n - 1)' / fs;
rs = RandStream('mt19937ar', 'Seed', 20261030);
noise = randn(rs, n, 1);
fc = 300 * (1400 / 300) .^ (t / dur);               % exponential sweep
r = 0.992;
y = zeros(n, 1);
y1 = 0; y2 = 0;
for i = 1:n
    a1 = 2 * r * cos(2 * pi * fc(i) / fs);
    y0 = (1 - r) * noise(i) + a1 * y1 - r * r * y2;
    y(i) = y0;
    y2 = y1; y1 = y0;
end
swell = sin(pi * min(t / dur, 1)) .^ 0.7;           % rises, then eases off
flutter = 0.65 + 0.35 * sin(2 * pi * 22 * t);
y = y .* swell .* flutter;
end

function x = finish(y, fs)
%FINISH Silent lead and tail, raised-cosine fades, peak 0.9, two channels.
lead = round(0.004 * fs);                % 4 ms of silence at each end...
fade = round(0.010 * fs);                % ...then a 10 ms raised-cosine fade
n = numel(y);
g = ones(n, 1);
ramp = sin(pi / 2 * (1:fade)' / fade) .^ 2;
g(1:lead) = 0;
g(lead + (1:fade)) = ramp;
g(end - lead + 1:end) = 0;
g(end - lead - fade + 1:end - lead) = flipud(ramp);
y = y .* g;
y = 0.9 * y / max(abs(y));
x = [y y];
end
