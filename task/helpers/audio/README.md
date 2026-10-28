# Masking sound

`rain_loop_30s.wav`: 30 s of synthesised rain, cut to loop without a click.

**Source:** spyre Operator Rain 2 Filtered by eryps -- https://freesound.org/s/650541/ -- License: Creative Commons 0

- Original: `650541__eryps__spyre-operator-rain-2-filtered.wav`, 2:46.9, 48 kHz, 24-bit
  stereo, SHA-256 `0156e5f6ade46091d6047240db85d066a6742c16f4b82b851a91742e31aea680`.
  Not stored here.
- The author made it with the Operator synth in Ableton Live ("a muted tone with
  occasional heavy droplets, like rain heard inside a tent under a tree"). It is not a
  field recording, and not the 60-minute waterfall recording RRS_3-0 used
  (`32-Waterfall-60min.wav`, which neither repo has).
- CC0 1.0: no attribution required; credited here anyway.

**Made with** `make_rain_loop.py` (2026-10-28): 31 s from 60 s into the original, the
last second crossfaded (equal power) into the first. Rate, channels and bit depth
kept; not resampled or normalised. Output SHA-256
`3cf58c234d74dde144dc028edd0e64921b0f7229daaf2fbfc9156b43342c3399`.

**Checked:**
- the step across the loop seam (0.0062) equals the median sample-to-sample step;
- the 0.25-s RMS stays between -29.7 and -28.3 dBFS, with no dip at the crossfade;
- left and right are uncorrelated (r = 0.0 in the original).

**Limits:**
- One heavy droplet reaches 0 dBFS at 23.6 s and returns every loop. Three more reach
  -6 dBFS (3.9, 15.0, 25.2 s). That is typical of the original (about 1.4 droplets
  above -3 dBFS per 30 s).
- Spectrum relative to the total (1/3-octave bands): 250 Hz -17 dB, 1-2 kHz -10 dB,
  14 kHz -37 dB, nothing below about 80 Hz or above 16 kHz. Martin measured the motor's
  peaks near 250 Hz (StealthChop) and 14 kHz (SpreadCycle). This sound is weak at
  14 kHz, so whether it masks the SpreadCycle whine needs checking by ear at the device.
