function [x, fs] = loadMaskingSound(file)
%LOADMASKINGSOUND Read a masking sound file to play as a loop.
%   [x, fs] = rrst.loadMaskingSound("task/helpers/audio/rain_loop_30s.wav")
%
%   Returns the samples as a (samples x 2) matrix in [-1, 1] and the file's own
%   sample rate, so it is played without resampling. A mono file is duplicated to
%   both channels. The file must already loop without a click (see
%   task/helpers/audio/README.md); this function does not crossfade.

if ~isfile(file)
    error('rrst:badNoise', 'Masking sound file not found: %s', file);
end
[x, fs] = audioread(file);
if size(x, 2) == 1
    x = [x x];
elseif size(x, 2) > 2
    error('rrst:badNoise', 'Masking sound must be mono or stereo (got %d channels): %s', ...
        size(x, 2), file);
end
end
