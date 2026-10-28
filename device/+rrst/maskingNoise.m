function x = maskingNoise(fs, durS, colour, seed)
%MASKINGNOISE A loopable noise buffer to mask the motor sound.
%   x = rrst.maskingNoise(44100, 30, "pink", 1)
%
%   Replaces the 60-minute rain recording. The spectrum is shaped in the frequency
%   domain, so the buffer is periodic and loops without a click. colour is "white",
%   "pink" (power ~ 1/f, rain-like) or "brown" (power ~ 1/f^2). Output is a column
%   vector scaled to a peak of 0.9. The same seed gives the same buffer.

n = round(fs * durS);
s = RandStream('mt19937ar', 'Seed', seed);
X = fft(randn(s, n, 1));
k = [0:floor(n / 2), -ceil(n / 2) + 1:-1]';    % signed frequency index
f = abs(k) * fs / n;
switch lower(string(colour))
    case "white", g = ones(n, 1);
    case "pink",  g = 1 ./ sqrt(max(f, 20));    % flat below 20 Hz
    case "brown", g = 1 ./ max(f, 20);
    otherwise
        error('rrst:badNoise', 'Unknown noise colour "%s" (white, pink or brown).', colour);
end
g(1) = 0;                                       % no DC offset
x = real(ifft(X .* g));
x = 0.9 * x / max(abs(x));
end
