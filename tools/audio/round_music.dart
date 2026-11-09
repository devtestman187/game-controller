/// Renders the round music (M13 step 15): one piece at three tempos, so the
/// music can hurry up as the round's clock runs out without changing key or
/// pitch. Playful and bouncy, in F major, sixteen bars in two parts.
///
///   dart run tools/audio/round_music.dart
///
/// The WAV masters land in `tools/audio/final/round-wav/`, beside this script
/// and out of the repository, as `render.py`'s do; `README.md` says how the
/// shipping `.ogg` files are encoded from them. Every tempo is a whole number
/// of samples per sixteenth, so a loop is sample-exact and joins to itself.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'pop_kit.dart';

/// The three tempos. [sixteenth] samples per sixteenth at 44.1 kHz is a tempo
/// of sampleRate/4/sixteenth BPM: 5512 is 120.01 BPM, 4793 is 1.15 times faster
/// (138.01) and 4240 exactly 1.30 times faster (156.01), as section 8 says.
/// Each renders with its own seed, so the same WAV comes out every time.
const _tempos = [
  (name: 'round', sixteenth: 5512, seed: 20261115),
  (name: 'round_hurry', sixteenth: 4793, seed: 20261116),
  (name: 'round_final', sixteenth: 4240, seed: 20261117),
];

/// The round music is mastered 3 dB under the lobby's -20 dB, so the lobby is
/// the loudest thing the host plays; the peak keeps the set's -3 dB ceiling.
const _roundRmsDb = -23.0;
const _roundPeakDb = -3.0;

/// The seconds of ring-out past the last bar that are folded back over the
/// start of the loop, so the seam carries the reverb instead of a cut.
const _spareSeconds = 2.0;

const _beatsPerBar = 4;
const _sixteenthsPerBar = 16;
const _barsPerPart = 8;

/// One bar of the score: the bass's root and fifth, the chord the off-beats
/// stab, and the whistle's phrase. [lead] is empty for the bars that leave the
/// lead silent, which is where the piece breathes.
class _Bar {
  const _Bar(this.root, this.fifth, this.chord, this.lead);

  final String root;
  final String fifth;
  final List<String> chord;
  final List<(String, double)> lead;
}

/// The piece: A is bars 1-8, B is bars 9-16, both in F major.
///
///   A: F | C | Dm | Bb | F | Bb | C | F
///   B: Bb | C | F | Dm | Gm | C | Bb | F
///
/// The lead is a call in A and its higher answer in B; each phrase runs over
/// the first half of its bar, so the second half is bass, off-beat chords and
/// shaker only.
const _score = <_Bar>[
  _Bar('F2', 'C3', ['F4', 'A4', 'C5'], [('C5', 0.5), ('A4', 0.5), ('C5', 1)]),
  _Bar('C3', 'G3', ['E4', 'G4', 'C5'], [('E5', 1), ('C5', 1)]),
  _Bar('D3', 'A3', ['D4', 'F4', 'A4'], [('D5', 0.5), ('F5', 0.5), ('A5', 1)]),
  _Bar('Bb2', 'F3', ['D4', 'F4', 'Bb4'], []),
  _Bar('F2', 'C3', ['F4', 'A4', 'C5'], [('A5', 0.5), ('G5', 0.5), ('F5', 1)]),
  _Bar('Bb2', 'F3', ['D4', 'F4', 'Bb4'], [('D5', 0.5), ('F5', 0.5), ('Bb5', 1)]),
  _Bar('C3', 'G3', ['E4', 'G4', 'C5'], [('G5', 1), ('E5', 1)]),
  _Bar('F2', 'C3', ['F4', 'A4', 'C5'], [('F5', 2)]),
  _Bar('Bb2', 'F3', ['D4', 'F4', 'Bb4'], [('Bb5', 0.5), ('A5', 0.5), ('G5', 1)]),
  _Bar('C3', 'G3', ['E4', 'G4', 'C5'], [('E5', 0.5), ('G5', 0.5), ('C6', 1)]),
  _Bar('F2', 'C3', ['F4', 'A4', 'C5'], [('F5', 0.5), ('A5', 0.5), ('C6', 1)]),
  _Bar('D3', 'A3', ['D4', 'F4', 'A4'], []),
  _Bar('G2', 'D3', ['D4', 'G4', 'Bb4'], [('G5', 0.5), ('Bb5', 0.5), ('D6', 0.5), ('Bb5', 0.5)]),
  _Bar('C3', 'G3', ['E4', 'G4', 'C5'], [('C6', 1), ('G5', 1)]),
  _Bar('Bb2', 'F3', ['D4', 'F4', 'Bb4'], [('Bb5', 0.5), ('A5', 0.5), ('G5', 0.5), ('A5', 0.5)]),
  _Bar('F2', 'C3', ['F4', 'A4', 'C5'], [('F5', 1.5)]),
];

void main() {
  final output = Directory('${_scriptDir().path}/final/round-wav')..createSync(recursive: true);
  stdout.writeln('Round music, F major, ${_score.length} bars, into ${output.path}');
  for (final tempo in _tempos) {
    final loop = _loop(tempo.sixteenth, tempo.seed);
    final path = '${output.path}/${tempo.name}.wav';
    writeWav(path, loop);
    stdout.writeln(_describe(tempo.name, tempo.sixteenth, loop, path));
  }
}

/// The prepared loop at [sixteenth] samples per sixteenth, seeded with [seed]:
/// the score, the room, the spare ring-out folded back over the start, and the
/// mastering pass. No fades: a loop joins itself.
List<double> _loop(int sixteenth, int seed) {
  final rng = Random(seed);
  final length = _score.length * _sixteenthsPerBar * sixteenth;
  final buf = _play(_score, sixteenth, rng);
  final wet = room(rng, buf, wet: 0.10, size: 0.35, decay: 0.08);
  final out = Float64List(length);
  for (var i = 0; i < length; i++) {
    out[i] = wet[i];
  }
  final spare = min(wet.length - length, length);
  for (var i = 0; i < spare; i++) {
    out[i] += wet[length + i];
  }
  return finishLoop(out, _roundRmsDb, peakDb: _roundPeakDb);
}

/// Every note of [score] laid into its buffer, with a spare tail for the ring.
Float64List _play(List<_Bar> score, int sixteenth, Random rng) {
  final barSamples = _sixteenthsPerBar * sixteenth;
  final beat = _beatsPerBar * sixteenth;
  final buf = Float64List(score.length * barSamples + (_spareSeconds * sampleRate).round());
  for (var i = 0; i < score.length; i++) {
    final at = i * barSamples;
    _bassLine(buf, at, beat, score[i], rng);
    _stabs(buf, at, beat, score[i], partB: i >= _barsPerPart, rng: rng);
    _percussion(buf, at, beat, i, rng);
    _lead(buf, at, beat, score[i], rng);
  }
  return buf;
}

/// Oom-pah bass, one note per beat: root, its octave, the fifth, its octave.
void _bassLine(Float64List buf, int at, int beat, _Bar bar, Random rng) {
  final beatSeconds = beat / sampleRate;
  for (var k = 0; k < _beatsPerBar; k++) {
    final up = k.isOdd;
    final f = hz(up ? bar.fifth : bar.root) * (up ? 2 : 1);
    final start = at + k * beat;
    if (up) {
      _add(buf, start, pluck(rng, f, dur: beatSeconds * 0.9, amp: 0.24, bright: 0.3));
    } else {
      _add(buf, start, bassNote(f, dur: beatSeconds * 1.6, amp: 0.50, decay: 0.35));
    }
  }
}

/// Staccato chord stabs on every off-beat: popnote in A, mallet in B, which is
/// the lift when the piece turns around at bar 9.
void _stabs(Float64List buf, int at, int beat, _Bar bar, {required bool partB, required Random rng}) {
  for (var k = 0; k < _beatsPerBar; k++) {
    final start = at + k * beat + beat ~/ 2;
    for (final name in bar.chord) {
      if (partB) {
        _add(buf, start, mallet(rng, hz(name), dur: 0.30, amp: 0.20, decay: 0.16, tone: 0.8));
      } else {
        _add(buf, start, popNote(hz(name), dur: 0.18, amp: 0.075, decay: 0.10));
      }
    }
  }
}

/// Shaker on every eighth, a woodblock on beats 1 and 3, a clap on the last bar
/// of each part. The woodblock keeps off the second beat on purpose: that is
/// where the round's own tick lands, and the two would fight.
void _percussion(Float64List buf, int at, int beat, int bar, Random rng) {
  final eighth = beat ~/ 2;
  for (var k = 0; k < _beatsPerBar * 2; k++) {
    _add(buf, at + k * eighth, shaker(rng, amp: k.isEven ? 0.10 : 0.055));
  }
  _add(buf, at, woodblock(rng, amp: 0.10));
  _add(buf, at + 2 * beat, woodblock(rng, amp: 0.08));
  if (bar % _barsPerPart == _barsPerPart - 1) {
    _add(buf, at, clap(rng, amp: 0.14));
  }
}

/// The bar's whistle phrase, its notes in beats of [beat] samples.
void _lead(Float64List buf, int at, int beat, _Bar bar, Random rng) {
  if (bar.lead.isEmpty) return;
  final notes = [for (final (name, beats) in bar.lead) (hz(name), beats * beat / sampleRate)];
  _add(buf, at, whistle(rng, notes, amp: 0.32));
}

/// [sig] mixed into [buf] at sample [at], cut off at the buffer's end.
void _add(Float64List buf, int at, List<double> sig, [double gain = 1]) {
  if (at < 0 || at >= buf.length) return;
  final n = min(sig.length, buf.length - at);
  for (var i = 0; i < n; i++) {
    buf[at + i] += gain * sig[i];
  }
}

/// One measured line of the table: tempo, exact length, loudness and how the
/// loop point compares with the signal's own sample-to-sample steps.
String _describe(String name, int sixteenth, List<double> loop, String path) {
  final bpm = sampleRate / (_beatsPerBar * sixteenth) * 60;
  final seconds = loop.length / sampleRate;
  final peak = loop.fold<double>(0, (top, v) => max(top, v.abs()));
  final seam = (loop.first - loop.last).abs();
  var steps = 0.0;
  for (var i = 1; i < loop.length; i++) {
    steps += (loop[i] - loop[i - 1]).abs();
  }
  final step = steps / (loop.length - 1);
  return '$path\n'
      '  $name: ${bpm.toStringAsFixed(2)} BPM, ${loop.length} samples, '
      '${seconds.toStringAsFixed(3)} s, RMS ${_db(_rms(loop)).toStringAsFixed(1)} dB, '
      'peak ${_db(peak).toStringAsFixed(1)} dB, seam ${seam.toStringAsFixed(5)} '
      'against a mean step of ${step.toStringAsFixed(5)}';
}

/// The loudness of [sig] over the samples above the same -45 dB gate the
/// mastering uses.
double _rms(List<double> sig) {
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
  return count == 0 ? 0 : sqrt(sum / count);
}

double _db(double amp) => 20 * log(max(amp, 1e-9)) / ln10;

/// The folder holding this script, so the WAV masters land beside it as
/// `render.py`'s do and never in the repository.
Directory _scriptDir() {
  final script = File(Platform.script.toFilePath());
  if (script.existsSync()) return script.parent;
  return Directory('tools/audio');
}
