"""Loopable masking noise. Port of rrst.maskingNoise (same method; the random numbers
differ from MATLAB's, so buffers are not sample-identical across languages)."""
import numpy as np

from . import errors


def masking_noise(fs, dur_s, colour, seed):
    """A loopable noise buffer to mask the motor sound, replacing the 60-minute rain
    recording. The spectrum is shaped in the frequency domain, so the buffer is
    periodic and loops without a click. colour is "white", "pink" (power ~ 1/f,
    rain-like) or "brown" (power ~ 1/f^2). Scaled to a peak of 0.9; the same seed
    gives the same buffer."""
    n = int(round(fs * dur_s))
    X = np.fft.fft(np.random.default_rng(seed).standard_normal(n))
    f = np.abs(np.fft.fftfreq(n, d=1 / fs))
    colour = str(colour).lower()
    if colour == "white":
        g = np.ones(n)
    elif colour == "pink":
        g = 1 / np.sqrt(np.maximum(f, 20))      # flat below 20 Hz
    elif colour == "brown":
        g = 1 / np.maximum(f, 20)
    else:
        raise errors.BadNoise(f'Unknown noise colour "{colour}" (white, pink or brown).')
    g[0] = 0                                    # no DC offset
    x = np.real(np.fft.ifft(X * g))
    return 0.9 * x / np.max(np.abs(x))
