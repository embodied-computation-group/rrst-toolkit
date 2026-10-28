"""Cut a seamless 30-s masking loop from the Freesound rain recording.

    python make_rain_loop.py <650541__eryps__spyre-operator-rain-2-filtered.wav> rain_loop_30s.wav

Takes LOOP_S + FADE_S seconds from the steady part of the source (the last ~2 s fade
out) and blends the extra FADE_S seconds into the start with an equal-power crossfade,
so the buffer loops without a click or a level dip. Sample rate, channels and 24-bit
depth are kept; nothing is resampled or normalised. Needs numpy.
"""
import hashlib
import sys
import wave

import numpy as np

START_S = 60.0     # inside the steady part (1-s RMS within 0.4 dB from 0 to 163 s)
LOOP_S = 30.0
FADE_S = 1.0


def read_24bit(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 3, "expected 24-bit PCM"
        ch, fs, n = w.getnchannels(), w.getframerate(), w.getnframes()
        b = np.frombuffer(w.readframes(n), dtype=np.uint8).reshape(-1, 3).astype(np.int32)
    x = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
    x = np.where(x >= 2**23, x - 2**24, x)
    return x.reshape(-1, ch), fs


def write_24bit(path, x, fs):
    x = np.clip(np.round(x), -2**23, 2**23 - 1).astype(np.int32)
    u = (x.reshape(-1) & 0xFFFFFF).astype(np.uint32)
    b = np.stack([u & 0xFF, (u >> 8) & 0xFF, (u >> 16) & 0xFF], axis=1).astype(np.uint8)
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(3)
        w.setframerate(fs)
        w.writeframes(b.tobytes())


def main(src, dst):
    x, fs = read_24bit(src)
    i0, n, f = round(START_S * fs), round(LOOP_S * fs), round(FADE_S * fs)
    seg = x[i0:i0 + n + f].astype(np.float64)
    t = (np.arange(f) + 0.5) / f
    fade_in, fade_out = np.sin(t * np.pi / 2)[:, None], np.cos(t * np.pi / 2)[:, None]
    out = seg[:n].copy()
    out[:f] = seg[:f] * fade_in + seg[n:n + f] * fade_out   # out[-1] -> out[0] continues seg[n-1] -> seg[n]
    write_24bit(dst, out, fs)
    print(f"source sha256 {hashlib.sha256(open(src, 'rb').read()).hexdigest()}")
    print(f"wrote {dst}: {n / fs:.1f} s, {fs} Hz, {x.shape[1]} ch, 24-bit, "
          f"peak {20 * np.log10(np.abs(out).max() / 2**23):.1f} dBFS")


if __name__ == "__main__":
    main(*sys.argv[1:3])
