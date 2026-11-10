/// The "Bubble Pop" instruments, ported from `render.py` to Dart (M13 step 15)
/// so the round music renders on a PC that has no numpy. Every shape and every
/// relative level is the Python's, so the round music sits with the rest of the
/// set and sounds like the same band.
///
/// Only what the renderers in this folder need is here: the mallet and the
/// bars, the bell, the bubble, the popnote, the bass, the pluck, the whistle,
/// the swish and the four percussion sounds, the room they play in, the two
/// mastering passes of `render.py` (one for a loop, one for a one-shot) and
/// the WAV writer.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// The set's rate: mono, 44.1 kHz, as every file in `assets/audio`.
const double sampleRate = 44100;

const double _rate = 44100;
const double _tau = 2 * pi;

/// Semitones above C for each note letter, as `render.py`'s NOTE table.
const _note = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

/// The frequency of a note name such as `C5`, `F#4` or `Bb3`.
double hz(String name) {
  final letter = name[0];
  var rest = name.substring(1);
  var semis = 0;
  if (rest.isNotEmpty && (rest[0] == '#' || rest[0] == 'b')) {
    semis = rest[0] == '#' ? 1 : -1;
    rest = rest.substring(1);
  }
  // Every name the score writes is a letter of the table above.
  final midi = 12 * (int.parse(rest) + 1) + (_note[letter] ?? 0) + semis;
  return 440.0 * pow(2, (midi - 69) / 12);
}

/// [value] rounded up to the next power of two, at least 2.
int nextPowerOfTwo(int value) {
  var size = 2;
  while (size < value) {
    size <<= 1;
  }
  return size;
}

/// An in-place radix-2 FFT of [re] and [im], whose length must be a power of
/// two. The inverse divides by the length, so the pair round-trips as numpy's
/// `fft`/`irfft` do.
void fft(Float64List re, Float64List im, {required bool inverse}) {
  final n = re.length;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    while (j & bit != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      final swapRe = re[i];
      re[i] = re[j];
      re[j] = swapRe;
      final swapIm = im[i];
      im[i] = im[j];
      im[j] = swapIm;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final half = len >> 1;
    final angle = (inverse ? 1.0 : -1.0) * _tau / len;
    final cosTable = Float64List(half);
    final sinTable = Float64List(half);
    for (var k = 0; k < half; k++) {
      cosTable[k] = cos(angle * k);
      sinTable[k] = sin(angle * k);
    }
    for (var block = 0; block < n; block += len) {
      for (var k = 0; k < half; k++) {
        final a = block + k;
        final b = a + half;
        final vRe = re[b] * cosTable[k] - im[b] * sinTable[k];
        final vIm = re[b] * sinTable[k] + im[b] * cosTable[k];
        re[b] = re[a] - vRe;
        im[b] = im[a] - vIm;
        re[a] += vRe;
        im[a] += vIm;
      }
    }
  }
  if (!inverse) return;
  for (var i = 0; i < n; i++) {
    re[i] /= n;
    im[i] /= n;
  }
}

/// White noise through a soft band-pass, as `render.py`'s `bandnoise`: the mask
/// is 1/(1+(lo/f)⁴) times 1/(1+(f/hi)⁴), so [lo] or [hi] of zero leaves that
/// side open. The buffer is zero-padded to a power of two, which only changes
/// the filter's resolution, not its shape.
List<double> bandNoise(Random rng, int length, double lo, double hi) {
  final n = max(length, 16);
  final size = nextPowerOfTwo(n);
  final re = Float64List(size);
  final im = Float64List(size);
  for (var i = 0; i < n; i++) {
    re[i] = rng.nextDouble() * 2 - 1;
  }
  fft(re, im, inverse: false);
  for (var k = 0; k <= size >> 1; k++) {
    final f = k * _rate / size;
    var mask = 1.0;
    if (lo > 0) {
      final r = lo / max(f, 1e-3);
      mask /= 1 + r * r * r * r;
    }
    if (hi > 0) {
      final r = f / hi;
      mask /= 1 + r * r * r * r;
    }
    re[k] *= mask;
    im[k] *= mask;
    final mirror = size - k;
    if (k > 0 && mirror > size >> 1 && mirror < size) {
      re[mirror] *= mask;
      im[mirror] *= mask;
    }
  }
  fft(re, im, inverse: true);
  return [for (var i = 0; i < n; i++) re[i]];
}

/// Marimba / kalimba style struck bar: a few fast-decaying partials, with a
/// small noise click at the strike.
List<double> mallet(
  Random rng,
  double f, {
  double dur = 0.8,
  double amp = 1,
  double decay = 0.45,
  double tone = 1,
}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  const partials = [
    (1.0, 1.0, 1.0, false),
    (1.997, 0.14, 0.55, false),
    (3.93, 0.085, 0.32, true),
    (9.2, 0.02, 0.14, true),
  ];
  for (final (ratio, level, k, byTone) in partials) {
    final a = byTone ? level * tone : level;
    final tau = decay * k + 1e-4;
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] += a * exp(-t / tau) * sin(_tau * f * ratio * t);
    }
  }
  for (var i = 0; i < n; i++) {
    out[i] *= (i / (_rate * 0.0025)).clamp(0.0, 1.0);
  }
  final m = min(n, (0.005 * sampleRate).round());
  if (m > 16) {
    final click = bandNoise(rng, m, 1200, 5200);
    for (var i = 0; i < m; i++) {
      out[i] += 0.10 * tone * click[i] * exp(-i / _rate / 0.0012);
    }
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.45 * amp];
}

/// The same bar bending from [f0] to [f1] over [dur], as `render.py`'s
/// `mallet_glide`: palette A's soft "nope" for `wrong`, and here the rubbery
/// upward glide that makes a bump and a dropped coin sound like a toy, not a
/// knock.
List<double> malletGlide(double f0, double f1, {double dur = 0.35, double amp = 1, double decay = 0.30}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final f = f0 * pow(f1 / f0, t / dur);
    phase += _tau * f / _rate;
    final env = (t / 0.004).clamp(0.0, 1.0) * exp(-t / decay);
    out[i] = (sin(phase) + 0.18 * sin(2 * phase) * exp(-t / (decay * 0.6))) * env;
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.5 * amp];
}

/// Glockenspiel / soft chime: five inharmonic partials, as `render.py`'s
/// `bell` — the coin's shimmer and `coin_appear`'s twinkle.
List<double> bell(double f, {double dur = 1.0, double amp = 1}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  const partials = [
    (1.0, 1.0, 0.55),
    (2.0, 0.30, 0.40),
    (2.76, 0.22, 0.30),
    (5.4, 0.10, 0.18),
    (8.93, 0.04, 0.10),
  ];
  for (final (ratio, level, k) in partials) {
    final tau = dur * k + 1e-4;
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] += level * exp(-t / tau) * sin(_tau * f * ratio * t);
    }
  }
  for (var i = 0; i < n; i++) {
    out[i] *= (i / (_rate * 0.001)).clamp(0.0, 1.0) * 0.35;
  }
  return [for (var i = 0; i < n; i++) out[i] * amp];
}

/// Rounded synth pluck: a sine plus a little odd-harmonic sparkle.
List<double> popNote(double f, {double dur = 0.35, double amp = 1, double decay = 0.42}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final env = (t / 0.004).clamp(0.0, 1.0) * exp(-t / decay);
    final v =
        sin(_tau * f * t) +
        0.28 * sin(_tau * 3 * f * t) * exp(-t / (decay * 0.45)) +
        0.09 * sin(_tau * 5 * f * t) * exp(-t / (decay * 0.25));
    out[i] = v * env;
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.55 * amp];
}

/// Soft synth bass: a sine plus a little second harmonic.
List<double> bassNote(double f, {double dur = 1.2, double amp = 1, double decay = 0.55}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final env = (t / 0.005).clamp(0.0, 1.0) * exp(-t / decay);
    out[i] = (sin(_tau * f * t) + 0.20 * sin(2 * _tau * f * t)) * env;
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.5 * amp];
}

/// Karplus-Strong: ukulele / nylon-string pluck. The excitation is softened so
/// the loop has no hissy 6-10 kHz edge (as `render.py` explains).
List<double> pluck(
  Random rng,
  double f, {
  double dur = 0.6,
  double amp = 1,
  double damp = 0.9955,
  double bright = 0.35,
}) {
  final n = (dur * sampleRate).round();
  final size = max(2, (_rate / f).round());
  var buf = Float64List(size);
  for (var i = 0; i < size; i++) {
    buf[i] = rng.nextDouble() * 2 - 1;
  }
  for (var pass = 0; pass < 6; pass++) {
    final smoothed = Float64List(size);
    for (var i = 0; i < size; i++) {
      smoothed[i] = 0.5 * (buf[i] + buf[(i - 1 + size) % size]);
    }
    buf = smoothed;
  }
  final out = Float64List(n);
  var index = 0;
  for (var i = 0; i < n; i++) {
    final cur = buf[index];
    out[i] = cur;
    buf[index] = damp * (bright * cur + (1 - bright) * buf[(index + 1) % size]);
    index = (index + 1) % size;
  }
  for (var i = 0; i < n; i++) {
    out[i] *= exp(-i / _rate / (dur * 0.55));
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.8 * amp];
}

/// Legato sine whistle over [seq]'s (frequency, seconds) notes, gliding from
/// one to the next, with vibrato and a breath of noise. The phrase fades out
/// over its last 20 ms, so a phrase needs room after it.
List<double> whistle(
  Random rng,
  List<(double, double)> seq, {
  double amp = 1,
  double glide = 0.035,
  double vibHz = 5.5,
  double vibCent = 6,
  double breath = 0.05,
}) {
  final parts = <Float64List>[];
  double? prev;
  for (final (f, dur) in seq) {
    final n = (dur * sampleRate).round();
    final freq = Float64List(n);
    for (var i = 0; i < n; i++) {
      freq[i] = f;
    }
    if (prev != null && glide > 0) {
      final g = max(1, (min(glide, dur * 0.5) * sampleRate).round());
      for (var i = 0; i < g; i++) {
        freq[i] = prev + (f - prev) * i / g;
      }
    }
    final part = Float64List(n);
    final vibrato = pow(2, vibCent / 1200) - 1;
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final vib = 1 + vibrato * sin(_tau * vibHz * t);
      phase += _tau * freq[i] * vib / _rate;
      part[i] = sin(phase) * (t / 0.012).clamp(0.0, 1.0);
    }
    parts.add(part);
    prev = f;
  }
  final total = parts.fold<int>(0, (sum, part) => sum + part.length);
  final sig = Float64List(total);
  var at = 0;
  for (final part in parts) {
    for (var i = 0; i < part.length; i++) {
      sig[at + i] = part[i];
    }
    at += part.length;
  }
  for (var i = 0; i < total; i++) {
    sig[i] *= 0.55;
  }
  if (breath > 0) {
    final noise = bandNoise(rng, total, 1800, 5200);
    var loudest = 0.0;
    for (final v in noise) {
      loudest = max(loudest, v.abs());
    }
    for (var i = 0; i < total; i++) {
      sig[i] += breath * noise[i] / (loudest + 1e-9);
    }
  }
  final last = min(total, (0.02 * sampleRate).round());
  for (var i = 0; i < last; i++) {
    sig[total - last + i] *= 1 - i / last;
  }
  return [for (var i = 0; i < total; i++) sig[i] * amp];
}

/// Cartoon water-drop / bloop: a rising or falling sine chirp, as
/// `render.py`'s `bubble` — the bounce of a bump and the fall of a coin.
List<double> bubble(double f0, double f1, {double dur = 0.09, double amp = 1}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final f = f0 * pow(f1 / f0, t / dur);
    phase += _tau * f / _rate;
    out[i] = sin(phase) * (t / 0.003).clamp(0.0, 1.0) * exp(-t / (dur * 0.55));
  }
  return [for (var i = 0; i < n; i++) out[i] * amp];
}

/// Soft body hit: a fast downward sine sweep.
List<double> thump(double f0, double f1, double dur, double amp) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final f = f0 * pow(f1 / f0, t / dur);
    phase += _tau * f / _rate;
    out[i] = sin(phase) * (t / 0.002).clamp(0.0, 1.0) * exp(-t / (dur * 0.30));
  }
  return [for (var i = 0; i < n; i++) out[i] * amp];
}

/// Soft hand clap: three short noise bursts plus a body tone.
List<double> clap(Random rng, {double dur = 0.18, double amp = 1}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  const offsets = [0.0, 0.010, 0.021];
  final m = (0.05 * sampleRate).round();
  for (var k = 0; k < offsets.length; k++) {
    final noise = bandNoise(rng, m, 700, 4200);
    final start = (offsets[k] * sampleRate).round();
    for (var i = 0; i < m && start + i < n; i++) {
      out[start + i] += (0.9 - 0.22 * k) * noise[i] * exp(-i / _rate / 0.011);
    }
  }
  final body = thump(220, 130, 0.12, 0.35);
  for (var i = 0; i < body.length && i < n; i++) {
    out[i] += body[i];
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.5 * amp];
}

/// A wooden "tok": a short noise body plus a pitched knock.
List<double> woodblock(Random rng, {double dur = 0.06, double amp = 1, double f = 1150}) {
  final n = (dur * sampleRate).round();
  final noise = bandNoise(rng, n, 800, 3300);
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    out[i] = 0.55 * noise[i] * exp(-t / 0.004) + 0.55 * sin(_tau * f * t) * exp(-t / 0.007);
  }
  return [for (var i = 0; i < n; i++) out[i] * amp];
}

/// A shaker: a short band of noise with a soft attack.
List<double> shaker(Random rng, {double dur = 0.07, double amp = 1}) {
  final n = (dur * sampleRate).round();
  final noise = bandNoise(rng, n, 1200, 4200);
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    out[i] = 0.7 * noise[i] * (t / 0.004).clamp(0.0, 1.0) * exp(-t / 0.013);
  }
  return [for (var i = 0; i < n; i++) out[i] * amp];
}

/// Noise swell with a band moving from [fromHz] to [toHz] over [dur], as
/// `render.py`'s `whoosh`: six short bands in a row, each 0.6 to 1.5 times the
/// moving centre, under a sine swell that rises and falls once. A rising one is
/// the dash's "fwip"; `rumble` is the wider, lower one.
List<double> swish(Random rng, double fromHz, double toHz, {double dur = 0.45, double amp = 1}) {
  final n = (dur * sampleRate).round();
  final out = Float64List(n);
  const steps = 6;
  final seg = n ~/ steps;
  for (var i = 0; i < steps; i++) {
    final a = i * seg;
    final b = i < steps - 1 ? (i + 1) * seg : n;
    final centre = fromHz * pow(toHz / fromHz, i / (steps - 1));
    final band = bandNoise(rng, b - a, centre * 0.6, centre * 1.5);
    for (var k = a; k < b; k++) {
      out[k] = band[k - a];
    }
  }
  for (var i = 0; i < n; i++) {
    out[i] *= pow(sin(pi * (i / _rate / dur).clamp(0.0, 1.0)), 1.5);
  }
  return [for (var i = 0; i < n; i++) out[i] * 0.55 * amp];
}

/// The tiny early-reflection sheen every cue of the set sits in: [sig] plus
/// [wet] times its convolution with a short decaying noise tail.
List<double> room(
  Random rng,
  List<double> sig, {
  double wet = 0.10,
  double size = 0.22,
  double decay = 0.055,
}) {
  final n = (size * sampleRate).round();
  var ir = Float64List(n);
  for (var i = 0; i < n; i++) {
    ir[i] = (rng.nextDouble() * 2 - 1) * exp(-i / _rate / decay);
  }
  // A room, not a hiss: a five-tap moving average, silent for the first 4 ms.
  final smoothed = Float64List(n);
  for (var i = 0; i < n; i++) {
    var sum = 0.0;
    for (var k = -2; k <= 2; k++) {
      final j = i + k;
      if (j >= 0 && j < n) sum += ir[j];
    }
    smoothed[i] = sum / 5;
  }
  ir = smoothed;
  final silent = min(n, (0.004 * sampleRate).round());
  for (var i = 0; i < silent; i++) {
    ir[i] = 0;
  }
  var scale = 0.0;
  for (final v in ir) {
    scale += v.abs();
  }
  for (var i = 0; i < n; i++) {
    ir[i] /= scale + 1e-9;
  }
  final wetSig = _convolve(sig, ir);
  final out = Float64List(wetSig.length);
  for (var i = 0; i < sig.length; i++) {
    out[i] = sig[i];
  }
  for (var i = 0; i < out.length; i++) {
    out[i] += wet * wetSig[i] * 8.0;
  }
  return out;
}

/// The full convolution of [a] and [b], through the FFT: a 1.4 M-sample loop
/// against a 15 k-sample room tail is too long to run sample by sample.
List<double> _convolve(List<double> a, List<double> b) {
  final length = a.length + b.length - 1;
  final size = nextPowerOfTwo(length);
  final aRe = Float64List(size);
  final aIm = Float64List(size);
  final bRe = Float64List(size);
  final bIm = Float64List(size);
  for (var i = 0; i < a.length; i++) {
    aRe[i] = a[i];
  }
  for (var i = 0; i < b.length; i++) {
    bRe[i] = b[i];
  }
  fft(aRe, aIm, inverse: false);
  fft(bRe, bIm, inverse: false);
  for (var k = 0; k < size; k++) {
    final pRe = aRe[k] * bRe[k] - aIm[k] * bIm[k];
    final pIm = aRe[k] * bIm[k] + aIm[k] * bRe[k];
    aRe[k] = pRe;
    aIm[k] = pIm;
  }
  fft(aRe, aIm, inverse: true);
  return [for (var i = 0; i < length; i++) aRe[i]];
}

/// [sig] with its mean removed and everything under [fc] Hz filtered out (the
/// FFT mask `render.py`'s `highpass` uses).
List<double> highpass(List<double> sig, {double fc = 30}) {
  var mean = 0.0;
  for (final v in sig) {
    mean += v;
  }
  mean /= sig.length;
  final length = sig.length;
  final size = nextPowerOfTwo(length);
  final re = Float64List(size);
  final im = Float64List(size);
  for (var i = 0; i < length; i++) {
    re[i] = sig[i] - mean;
  }
  fft(re, im, inverse: false);
  for (var k = 0; k <= size >> 1; k++) {
    final f = k * _rate / size;
    final r = fc / max(f, 1e-6);
    final mask = 1 / (1 + r * r * r * r);
    re[k] *= mask;
    im[k] *= mask;
    final mirror = size - k;
    if (k > 0 && mirror > size >> 1 && mirror < size) {
      re[mirror] *= mask;
      im[mirror] *= mask;
    }
  }
  fft(re, im, inverse: true);
  return [for (var i = 0; i < length; i++) re[i]];
}

/// `render.py`'s `finish_loop`: the high-pass, the loudness to [rmsDb] over the
/// samples above a -45 dB gate, then a soft-knee limit at [peakDb]: no fades,
/// because a loop has to join to itself cleanly.
List<double> finishLoop(List<double> sig, double rmsDb, {double peakDb = -3}) {
  final out = highpass(sig);
  var peak = 0.0;
  for (final v in out) {
    peak = max(peak, v.abs());
  }
  if (peak < 1e-9) return out;
  final gate = peak * pow(10, -45 / 20);
  var sum = 0.0;
  var count = 0;
  for (final v in out) {
    if (v.abs() > gate) {
      sum += v * v;
      count++;
    }
  }
  if (count == 0) return out;
  final gain = pow(10, rmsDb / 20) / max(sqrt(sum / count), 1e-9);
  final limit = pow(10, peakDb / 20).toDouble();
  final knee = limit * 0.7;
  for (var i = 0; i < out.length; i++) {
    out[i] *= gain;
    final mag = out[i].abs();
    if (mag > knee) {
      final sign = out[i].isNegative ? -1.0 : 1.0;
      out[i] = sign * (knee + (limit - knee) * _tanh((mag - knee) / (limit - knee)));
    }
  }
  return out;
}

/// `render.py`'s `master`: `finishLoop`'s high-pass, loudness and soft-knee
/// limit, then the 4 ms fade in at the start and out at the end that a
/// one-shot has and a loop must not, so every cue starts and ends on silence.
List<double> masterEvent(List<double> sig, double rmsDb, {double peakDb = -3}) {
  final out = finishLoop(sig, rmsDb, peakDb: peakDb);
  final fade = min(out.length ~/ 2, (0.004 * sampleRate).round());
  for (var i = 0; i < fade; i++) {
    final ramp = fade > 1 ? i / (fade - 1) : 1.0;
    out[i] *= ramp;
    out[out.length - fade + i] *= 1 - ramp;
  }
  return out;
}

/// The loudness of [sig] in dB over the same -45 dB gate the mastering uses.
double rmsDb(List<double> sig) {
  final peak = sig.fold<double>(0, (top, v) => max(top, v.abs()));
  final gate = peak * pow(10, -45 / 20);
  var sum = 0.0;
  var count = 0;
  for (final v in sig) {
    if (v.abs() > gate) {
      sum += v * v;
      count++;
    }
  }
  return count == 0 ? -180 : 20 * log(sqrt(sum / count)) / ln10;
}

/// The highest sample of [sig] in dB, or -180 dB for digital silence.
double peakDb(List<double> sig) {
  final peak = sig.isEmpty ? 0.0 : sig.fold<double>(0, (top, v) => max(top, v.abs()));
  return 20 * log(max(peak, 1e-9)) / ln10;
}

/// The hyperbolic tangent, which dart:math does not have: (e²ˣ-1)/(e²ˣ+1),
/// with [x] clamped so the exponential cannot run away.
double _tanh(double x) {
  final e = exp(2 * x.clamp(-20.0, 20.0));
  return (e - 1) / (e + 1);
}

/// Writes [sig] as a mono 16-bit PCM WAV, as `render.py`'s `write_wav` does.
void writeWav(String path, List<double> sig) {
  final bytes = ByteData(44 + sig.length * 2);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  final int rate = sampleRate.round();
  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + sig.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, sig.length * 2, Endian.little);
  for (var i = 0; i < sig.length; i++) {
    bytes.setInt16(44 + i * 2, (sig[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
}

/// The folder holding the running script, so the WAV masters land beside it as
/// `render.py`'s do and never in the repository.
Directory scriptDir() {
  final script = File(Platform.script.toFilePath());
  if (script.existsSync()) return script.parent;
  return Directory('tools/audio');
}
