/// Renders the Arena's seven one-shot cues for the Bumper Round (M14, PRD G9)
/// in the "Bubble Pop" set, so they sit with `hit` and `pickup` (design
/// section 8): `dash`, `bump`, `bump_big`, `coin`, `coin_gold`, `coin_lost`
/// and `coin_appear`.
///
///   dart run tools/audio/arena_sounds.dart
///
/// The WAV masters land in `tools/audio/final/arena-wav/`, beside this script
/// and out of the repository, as `render.py`'s do; `render-arena-sounds.sh`
/// encodes them and `arena_music.dart` renders the three loops into the same
/// folder. Each cue is built from the kit's instruments, mastered with
/// `render.py`'s event pass to its own loudness, and seeded, so the same WAV
/// comes out every run.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'pop_kit.dart';

/// One cue: its file name, the loudness `render.py`'s event pass masters it to,
/// a fixed seed for its noise, and how it is built. The loudness order is the
/// design's: `coin_gold` is the brightest reward, `dash` and `coin_appear` the
/// quietest because they play most often.
class _Sound {
  const _Sound(this.name, this.masterDb, this.seed, this.build);

  final String name;
  final double masterDb;
  final int seed;
  final List<double> Function(Random rng) build;
}

const _sounds = <_Sound>[
  _Sound('dash', -24.0, 20261130, _dash),
  _Sound('bump', -22.0, 20261131, _bump),
  _Sound('bump_big', -20.0, 20261132, _bumpBig),
  _Sound('coin', -20.0, 20261133, _coin),
  _Sound('coin_gold', -19.0, 20261134, _coinGold),
  _Sound('coin_lost', -20.0, 20261135, _coinLost),
  _Sound('coin_appear', -26.0, 20261136, _coinAppear),
];

/// The set's peak ceiling for every mastered one-shot (design section 8).
const _peakDb = -3.0;

/// A cue's buffer of [seconds], with sounds mixed in at a time, as
/// `render.py`'s `Cue`.
class _Cue {
  _Cue(double seconds) : buf = Float64List((seconds * sampleRate).round());

  final Float64List buf;

  /// [sig] mixed into the buffer at [atS] seconds, cut off at its end.
  void add(double atS, List<double> sig, [double gain = 1]) {
    final at = (atS * sampleRate).round();
    if (at < 0 || at >= buf.length) return;
    final n = min(sig.length, buf.length - at);
    for (var i = 0; i < n; i++) {
      buf[at + i] += gain * sig[i];
    }
  }
}

void main() {
  final folder = Directory('${scriptDir().path}/final/arena-wav')..createSync(recursive: true);
  stdout.writeln("The Arena's seven one-shots, RMS per cue, peak $_peakDb dB, into ${folder.path}");
  stdout.writeln('name         length    samples     RMS      peak');
  for (final sound in _sounds) {
    final sig = masterEvent(sound.build(Random(sound.seed)), sound.masterDb, peakDb: _peakDb);
    writeWav('${folder.path}/${sound.name}.wav', sig);
    stdout.writeln(_line(sound.name, sig));
  }
}

/// One measured row of the table: name, length, samples, loudness and peak.
String _line(String name, List<double> sig) {
  final seconds = (sig.length / sampleRate).toStringAsFixed(3).padLeft(6);
  final samples = sig.length.toString().padLeft(9);
  final rms = rmsDb(sig).toStringAsFixed(1).padLeft(5);
  final peak = peakDb(sig).toStringAsFixed(1).padLeft(5);
  return '${name.padRight(12)} $seconds s $samples  $rms dB  $peak dB';
}

/// Every dash, a few a second at most: a quick band-noise swish rising into a
/// small pop — the marble's "fwip". No tune, so it can repeat all round, and
/// the quietest cue after `coin_appear`. Brighter, shorter and 4 dB quieter than
/// `rumble`, which is the dash sound the game has today, so the two read apart.
List<double> _dash(Random rng) {
  final cue = _Cue(0.18);
  cue.add(0.0, swish(rng, 700, 4800, dur: 0.15, amp: 0.6));
  cue.add(0.10, bubble(1000, 1700, dur: 0.05, amp: 0.20));
  return cue.buf;
}

/// Two marbles meeting: a soft body thump, a rubbery glide up (the "boing") and
/// a mallet tick where the shells touch (the "bonk"). Friendly and low-mid, and
/// no noise burst, so it is not `hit`, a marble against a wall.
List<double> _bump(Random rng) {
  final cue = _Cue(0.25);
  cue.add(0.0, thump(200, 105, 0.14, 0.55));
  cue.add(0.0, malletGlide(190, 330, dur: 0.20, amp: 0.45, decay: 0.085));
  cue.add(0.0, mallet(rng, hz('C5'), dur: 0.10, amp: 0.32, decay: 0.055, tone: 0.7));
  return cue.buf;
}

/// The same meeting when a dash shoves: more body, a lower and longer tick, and
/// a spring back up 0.10 s in. A tone lower and longer than `bump`, so the two
/// are told apart even when they play at once.
List<double> _bumpBig(Random rng) {
  final cue = _Cue(0.35);
  cue.add(0.0, thump(215, 80, 0.22, 0.75));
  cue.add(0.0, malletGlide(140, 300, dur: 0.28, amp: 0.55, decay: 0.13));
  cue.add(0.0, mallet(rng, hz('F4'), dur: 0.12, amp: 0.36, decay: 0.07, tone: 0.6));
  cue.add(0.10, bubble(240, 520, dur: 0.14, amp: 0.22));
  return cue.buf;
}

/// Picking up a coin: a bright two-note rise a fifth apart on the mallet — the
/// happiest short cue in the set without being the four-note `success`. The
/// mallet's struck-bar timbre and the fifth are a pair no other cue uses.
List<double> _coin(Random rng) {
  final cue = _Cue(0.25);
  cue.add(0.0, mallet(rng, hz('G5'), dur: 0.22, amp: 0.55, decay: 0.09, tone: 0.9));
  cue.add(0.07, mallet(rng, hz('D6'), dur: 0.24, amp: 0.55, decay: 0.10, tone: 0.9));
  return cue.buf;
}

/// A gold coin, worth 2: the coin's G5 and D6 inside a four-note G major rise
/// (G5 B5 D6 G6), with two high bells shimmering over it. More notes and more
/// shimmer than `coin`, so it sounds worth more to the ear at once.
List<double> _coinGold(Random rng) {
  final cue = _Cue(0.40);
  var at = 0.0;
  for (final name in ['G5', 'B5', 'D6', 'G6']) {
    cue.add(at, mallet(rng, hz(name), dur: 0.26, amp: 0.42, decay: 0.10, tone: 0.9));
    at += 0.055;
  }
  cue.add(0.165, bell(hz('G6'), dur: 0.30, amp: 0.14));
  cue.add(0.22, bell(hz('D7'), dur: 0.25, amp: 0.08));
  return cue.buf;
}

/// Dropping a coin: a small mallet tap as it leaves the marble, a fall from E5
/// to B4 (the "plonk") and, 0.12 s in, a low falling "plink" made of two bubbles
/// a few Hz apart, so the drop wobbles. A "whoops", never sad: no minor interval
/// and no buzz, so it is not `wrong` or `error`.
List<double> _coinLost(Random rng) {
  final cue = _Cue(0.40);
  cue.add(0.0, mallet(rng, hz('A4'), dur: 0.07, amp: 0.22, decay: 0.035));
  cue.add(0.0, malletGlide(hz('E5'), hz('B4'), dur: 0.18, amp: 0.55, decay: 0.085));
  cue.add(0.0, thump(170, 110, 0.07, 0.16));
  cue.add(0.12, bubble(500, 330, dur: 0.24, amp: 0.20));
  cue.add(0.12, bubble(506, 334, dur: 0.24, amp: 0.18));
  return cue.buf;
}

/// A new coin starting its 1 s sparkle: a breath of high noise and two soft
/// bells, G6 then D7, with a third G7 above as the twinkle. Quiet, because
/// three coins come and go all round.
List<double> _coinAppear(Random rng) {
  final cue = _Cue(0.30);
  final sparkle = bandNoise(rng, (0.03 * sampleRate).round(), 3000, 8000);
  for (var i = 0; i < sparkle.length; i++) {
    sparkle[i] *= 0.05 * exp(-i / sampleRate / 0.008);
  }
  cue.add(0.0, sparkle);
  cue.add(0.0, bell(hz('G6'), dur: 0.26, amp: 0.16));
  cue.add(0.055, bell(hz('D7'), dur: 0.22, amp: 0.10));
  cue.add(0.11, bell(hz('G7'), dur: 0.20, amp: 0.06));
  return cue.buf;
}
