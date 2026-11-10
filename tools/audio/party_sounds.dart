/// Renders the party night's five cues (M14 design section 11) in the "Bubble
/// Pop" set, so they sit with `success` and the Arena's `coin`: `meow` (the
/// cat's warning), `points` (a soft pop under a points pop-up), `fanfare` (an
/// award), `celebration` (a won round or the night's winner) and `new_record`
/// (a new best time).
///
///   dart run tools/audio/party_sounds.dart
///
/// The WAV masters land in `tools/audio/final/party-wav/`, beside this script
/// and out of the repository, as `arena_sounds.dart`'s do;
/// `render-party-sounds.sh` encodes them. Each cue is built from the kit's
/// instruments, mastered with `render.py`'s event pass to its own loudness, and
/// seeded, so the same WAV comes out every run. The run prints each file's
/// length, RMS and peak, and fails if a part is cut off by its cue's end or a
/// cue lands more than a dB under its target.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'pop_kit.dart';

/// One cue: its file name, the length it is built to, the loudness
/// `render.py`'s event pass masters it to, a fixed seed for its noise, and how
/// it is built. The table's length is the cue's buffer, so a cue cannot drift
/// from the length the design gives it. The loudness order follows the design:
/// `celebration` is the night's biggest moment, `points` the quietest because
/// it plays with every pop-up, and `new_record` a step under `celebration`
/// while its higher bells make it sound brighter.
class _Sound {
  const _Sound(this.name, this.seconds, this.masterDb, this.seed, this.build);

  final String name;
  final double seconds;
  final double masterDb;
  final int seed;
  final void Function(Random rng, _Cue cue) build;
}

const _sounds = <_Sound>[
  _Sound('meow', 0.46, -20.0, 20261151, _meow),
  _Sound('points', 0.18, -23.0, 20261152, _points),
  _Sound('fanfare', 2.00, -18.0, 20261153, _fanfare),
  _Sound('celebration', 2.50, -17.0, 20261154, _celebration),
  _Sound('new_record', 1.50, -18.0, 20261155, _newRecord),
];

/// The set's peak ceiling for every mastered one-shot (design section 8).
const _peakDb = -3.0;

/// How far under its target a cue's RMS may land after the soft-knee limit
/// before the run fails: the limit takes a few tenths off a cue's loudest
/// transients, and a cue much under its target has been limited too hard.
const _rmsSlackDb = 1.0;

/// A cue's buffer of [seconds], with sounds mixed in at a time, as
/// `arena_sounds.dart` does. It also remembers whether a part was cut off by
/// the buffer's end, so the run can fail rather than lose a tail.
class _Cue {
  _Cue(this.seconds) : buf = Float64List((seconds * sampleRate).round());

  final double seconds;
  final Float64List buf;

  /// Set once a sound added here was cut off by the buffer's end.
  bool truncated = false;

  /// [sig] mixed into the buffer at [atS] seconds, cut off at its end.
  void add(double atS, List<double> sig) {
    final at = (atS * sampleRate).round();
    if (at < 0 || at >= buf.length) {
      truncated = truncated || sig.isNotEmpty;
      return;
    }
    final n = min(sig.length, buf.length - at);
    if (n < sig.length) truncated = true;
    for (var i = 0; i < n; i++) {
      buf[at + i] += sig[i];
    }
  }
}

void main() {
  final folder = Directory('${scriptDir().path}/final/party-wav')..createSync(recursive: true);
  stdout.writeln("The party night's five cues, RMS per cue, peak $_peakDb dB, into ${folder.path}");
  stdout.writeln('name         length    samples     RMS      peak');
  var failed = false;
  for (final sound in _sounds) {
    final cue = _Cue(sound.seconds);
    sound.build(Random(sound.seed), cue);
    final sig = masterEvent(cue.buf, sound.masterDb, peakDb: _peakDb);
    writeWav('${folder.path}/${sound.name}.wav', sig);
    stdout.writeln(_line(sound.name, sig));
    if (cue.truncated) {
      stderr.writeln('${sound.name}: a part ran past its ${sound.seconds} s cue; start it earlier or lengthen the cue');
      failed = true;
    }
    final mastered = rmsDb(sig);
    if (mastered < sound.masterDb - _rmsSlackDb) {
      stderr.writeln(
        '${sound.name}: mastered to ${mastered.toStringAsFixed(1)} dB, '
        'more than $_rmsSlackDb dB under its ${sound.masterDb} dB target',
      );
      failed = true;
    }
  }
  if (failed) exitCode = 1;
}

/// One measured row of the table: name, length, samples, loudness and peak.
String _line(String name, List<double> sig) {
  final seconds = (sig.length / sampleRate).toStringAsFixed(3).padLeft(6);
  final samples = sig.length.toString().padLeft(9);
  final rms = rmsDb(sig).toStringAsFixed(1).padLeft(5);
  final peak = peakDb(sig).toStringAsFixed(1).padLeft(5);
  return '${name.padRight(12)} $seconds s $samples  $rms dB  $peak dB';
}

/// The cat's warning before it swipes a piece (G3): a short "mew" that rises
/// then falls, carrying a voice's second and third harmonics instead of a
/// whistle's single sine, and a slight waver from a detuned pair. Its register
/// (430–880 Hz) sits under `coin`'s G5–D6 and over the round music's stabs.
void _meow(Random rng, _Cue cue) {
  // The rise, "me": the fundamental and a copy a few Hz sharp, so the two beat.
  cue.add(0.0, bubble(430, 880, dur: 0.16, amp: 0.50));
  cue.add(0.0, bubble(437, 894, dur: 0.16, amp: 0.16));
  cue.add(0.0, bubble(860, 1760, dur: 0.15, amp: 0.20));
  cue.add(0.0, bubble(1290, 2640, dur: 0.13, amp: 0.06));
  // The fall, "ow", lower and longer, as a cat's voice drops away.
  cue.add(0.14, bubble(880, 470, dur: 0.28, amp: 0.46));
  cue.add(0.14, bubble(894, 477, dur: 0.28, amp: 0.15));
  cue.add(0.14, bubble(1760, 940, dur: 0.26, amp: 0.18));
  cue.add(0.14, bubble(2640, 1410, dur: 0.24, amp: 0.05));
  cue.add(0.02, _breath(rng, 0.38, 900, 3600, 0.02));
}

/// A breath of band noise over [seconds] from [lo] to [hi], fading in over
/// 20 ms and out over its last tenth: the air a cat's voice carries.
List<double> _breath(Random rng, double seconds, double lo, double hi, double amp) {
  final noise = bandNoise(rng, (seconds * sampleRate).round(), lo, hi);
  final n = noise.length;
  final fadeIn = max(1, (0.02 * sampleRate).round());
  final fadeOut = max(1, (0.10 * seconds * sampleRate).round());
  for (var i = 0; i < n; i++) {
    noise[i] *= amp * min(i / fadeIn, 1.0) * min((n - i) / fadeOut, 1.0);
  }
  return noise;
}

/// A point won (G1): one soft pop under the "+2" as it rises. A popnote rather
/// than `coin`'s mallets, because it plays with every award, and 3 dB under
/// `coin` and a step under `coin_appear`'s bells, so twenty pieces never nag.
void _points(Random rng, _Cue cue) {
  cue.add(0.0, popNote(hz('A5'), dur: 0.16, amp: 0.60, decay: 0.075));
  cue.add(0.0, bubble(620, 940, dur: 0.05, amp: 0.18));
}

/// An award revealed on the night's scoreboard (G4): four mallets up the
/// C-major triad into a held chord, with bells over it. Slower and more formal
/// than `success` (popnotes, 1.02 s) and longer than `coin_gold`, so an award
/// reads as an announcement rather than another reward.
void _fanfare(Random rng, _Cue cue) {
  var at = 0.0;
  for (final name in ['C5', 'E5', 'G5', 'C6']) {
    cue.add(at, mallet(rng, hz(name), dur: 0.55, amp: 0.50, decay: 0.20, tone: 0.85));
    at += 0.11;
  }
  // The held chord: long, soft mallets and a low root under the bells.
  for (final name in ['C5', 'E5', 'G5']) {
    cue.add(0.34, mallet(rng, hz(name), dur: 1.60, amp: 0.26, decay: 0.65, tone: 0.70));
  }
  cue.add(0.34, bassNote(hz('C3'), dur: 1.60, amp: 0.28, decay: 0.75));
  cue.add(0.40, bell(hz('C6'), dur: 0.90, amp: 0.20));
  cue.add(0.46, bell(hz('E6'), dur: 0.85, amp: 0.15));
  cue.add(0.52, bell(hz('G6'), dur: 0.80, amp: 0.11));
  cue.add(0.58, bell(hz('C7'), dur: 0.70, amp: 0.06));
}

/// A round won, and the night's winner (G4): two "ta-da"s, a G-major hit
/// answered by C major, each with a clap, a thump and its bass, the second one
/// ending in a ring of bells. The percussion and bass are what tell it from
/// `fanfare` at a similar loudness, and the two halves fill the design's 2.5 s.
void _celebration(Random rng, _Cue cue) {
  _stomp(rng, cue, 0.0, 'G2');
  var at = 0.0;
  for (final name in ['G4', 'B4', 'D5', 'G5']) {
    cue.add(at, mallet(rng, hz(name), dur: 0.55, amp: 0.50, decay: 0.22, tone: 0.90));
    at += 0.09;
  }
  cue.add(0.27, bell(hz('G5'), dur: 0.70, amp: 0.14));
  cue.add(0.33, bell(hz('D6'), dur: 0.60, amp: 0.10));
  _stomp(rng, cue, 1.20, 'C3');
  at = 1.20;
  for (final name in ['C5', 'E5', 'G5', 'C6']) {
    cue.add(at, mallet(rng, hz(name), dur: 0.60, amp: 0.52, decay: 0.24, tone: 0.90));
    at += 0.09;
  }
  cue.add(1.46, bell(hz('C6'), dur: 1.00, amp: 0.18));
  cue.add(1.53, bell(hz('E6'), dur: 0.95, amp: 0.13));
  cue.add(1.60, bell(hz('G6'), dur: 0.90, amp: 0.10));
  cue.add(1.67, bell(hz('C7'), dur: 0.80, amp: 0.06));
}

/// The stomp under a "ta-da": a clap, a soft thump and the chord's low root for
/// 1.1 s, so the hit has weight without a drum the kit does not have.
void _stomp(Random rng, _Cue cue, double atS, String root) {
  cue.add(atS, clap(rng, dur: 0.18, amp: 0.55));
  cue.add(atS, thump(150, 70, 0.12, 0.35));
  cue.add(atS, bassNote(hz(root), dur: 1.10, amp: 0.42, decay: 0.55));
}

/// A new best time on the results card (T15, N14): four bells up a C-major
/// climb over a soft popnote, then a long, high ring. Everything is G5 and up,
/// with no bass or clap, so it sounds brighter than `celebration` even a step
/// quieter; `player_joined`'s C6–E6–G6 bells sit mostly below its G6–G7.
void _newRecord(Random rng, _Cue cue) {
  cue.add(0.0, popNote(hz('G5'), dur: 0.30, amp: 0.35, decay: 0.12));
  var at = 0.0;
  for (final name in ['G6', 'C7', 'E7', 'G7']) {
    cue.add(at, bell(hz(name), dur: 0.60, amp: 0.16));
    at += 0.07;
  }
  cue.add(0.28, bell(hz('C7'), dur: 1.15, amp: 0.14));
  cue.add(0.40, bell(hz('E7'), dur: 1.00, amp: 0.09));
  cue.add(0.52, bell(hz('G7'), dur: 0.85, amp: 0.06));
}
