/// Renders the Arena's music (M14): a bouncy bumper-car funfair in G major at
/// three tempos, so the Bumper Round can hurry up as its clock runs out without
/// changing key or pitch. Sixteen bars in two parts, and its own tune from the
/// first bar, so a player knows from the first bar which game is on.
///
///   dart run tools/audio/arena_music.dart
///
/// The WAV masters land in `tools/audio/final/arena-wav/`, beside this script
/// and out of the repository, as `render.py`'s do; `render-arena-sounds.sh`
/// encodes them and `arena_sounds.dart` renders the one-shots into the same
/// folder. Every tempo is a whole number of samples per sixteenth, so a loop is
/// sample-exact and joins to itself. The run prints each loop's length, RMS and
/// peak and the size of its seam, and fails if a loop is not 16 bars or peaks
/// above -3 dB.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'pop_kit.dart';

/// The three tempos, as samples per sixteenth: 5168 is 127.999 BPM, 4494 is
/// 1.15 times faster (147.20) and 3975 is 1.30 times faster (166.42), so every
/// loop is 256 whole sixteenths. Each renders with its own seed, so the same
/// WAV comes out every time.
const _tempos = [
  (name: 'arena', sixteenth: 5168, seed: 20261140),
  (name: 'arena_hurry', sixteenth: 4494, seed: 20261141),
  (name: 'arena_final', sixteenth: 3975, seed: 20261142),
];

/// The Arena's music is mastered as the round music is: 3 dB under the lobby's
/// -20, so the game's sounds and the tick read over it, with the set's -3 dB
/// peak ceiling (design section 8).
const _arenaRmsDb = -23.0;
const _arenaPeakDb = -3.0;

/// The seconds of ring-out past the last bar that are folded back over the
/// start of the loop, so the seam carries the reverb instead of a cut.
const _spareSeconds = 2.0;

const _beatsPerBar = 4;
const _sixteenthsPerBar = 16;
const _barsPerPart = 8;

/// The piece is two parts: 16 bars, which a loop must be exactly.
const _bars = 2 * _barsPerPart;

/// The sixteenths in a beat, and the shaker's level for each one within a beat,
/// the sixteenth on the beat loudest.
const _sixteenthsPerBeat = _sixteenthsPerBar ~/ _beatsPerBar;
const _shakerLevels = [0.060, 0.032, 0.048, 0.032];

/// One bar of the score: the bass's root and fifth, the chord the off-beats
/// stab, and the lead's phrase in beats. [lead] is empty for the bar that leaves
/// the lead silent, which is where the piece breathes.
class _Bar {
  const _Bar(this.root, this.fifth, this.chord, this.lead);

  final String root;
  final String fifth;
  final List<String> chord;
  final List<(String, double)> lead;
}

/// The piece: A is bars 1-8, B is bars 9-16, both in G major.
///
///   A: G | D | Em | C | G | C | D | G
///   B: C | D | Em | Am | C | D | G | D
///
/// A's lead is a popnote call over the first half of its bar; B answers it a
/// little higher in the whistle and turns round on the dominant at bar 16, so
/// the loop falls back into G. Bar 4 is left to the band.
const _score = <_Bar>[
  _Bar('G2', 'D3', ['D4', 'G4', 'B4'], [('B4', 0.5), ('D5', 0.5), ('B4', 1)]),
  _Bar('D2', 'A2', ['F#4', 'A4', 'D5'], [('A4', 0.5), ('D5', 0.5), ('F#5', 1)]),
  _Bar('E2', 'B2', ['E4', 'G4', 'B4'], [('B4', 0.5), ('E5', 0.5), ('G5', 1)]),
  _Bar('C2', 'G2', ['E4', 'G4', 'C5'], []),
  _Bar('G2', 'D3', ['D4', 'G4', 'B4'], [('D5', 0.5), ('B4', 0.5), ('G4', 1)]),
  _Bar('C2', 'G2', ['E4', 'G4', 'C5'], [('E5', 0.5), ('G5', 0.5), ('E5', 1)]),
  _Bar('D2', 'A2', ['F#4', 'A4', 'D5'], [('F#5', 1), ('A5', 1)]),
  _Bar('G2', 'D3', ['D4', 'G4', 'B4'], [('G5', 2)]),
  _Bar('C2', 'G2', ['E4', 'G4', 'C5'], [('G4', 0.5), ('E5', 0.5), ('G5', 1)]),
  _Bar('D2', 'A2', ['F#4', 'A4', 'D5'], [('A4', 0.5), ('F#5', 0.5), ('A5', 1)]),
  _Bar('E2', 'B2', ['E4', 'G4', 'B4'], [('B4', 0.5), ('G5', 0.5), ('E5', 1)]),
  _Bar('A2', 'E3', ['E4', 'A4', 'C5'], [('A4', 0.5), ('E5', 0.5), ('C5', 1)]),
  _Bar('C2', 'G2', ['E4', 'G4', 'C5'], [('E5', 0.5), ('G5', 0.5), ('C6', 0.5), ('G5', 0.5)]),
  _Bar('D2', 'A2', ['F#4', 'A4', 'D5'], [('A5', 1), ('F#5', 1)]),
  _Bar('G2', 'D3', ['D4', 'G4', 'B4'], [('G5', 1.5)]),
  _Bar('D2', 'A2', ['F#4', 'A4', 'D5'], [('F#5', 0.5), ('A5', 1)]),
];

void main() {
  final folder = Directory('${scriptDir().path}/final/arena-wav')..createSync(recursive: true);
  stdout.writeln('The Arena music, G major, $_bars bars, into ${folder.path}');
  var failed = false;
  if (_score.length != _bars) {
    stderr.writeln('the score has ${_score.length} bars, not $_bars');
    failed = true;
  }
  for (final tempo in _tempos) {
    final loop = _loop(tempo.sixteenth, tempo.seed);
    writeWav('${folder.path}/${tempo.name}.wav', loop);
    stdout.writeln(_describe(tempo.name, tempo.sixteenth, loop, '${folder.path}/${tempo.name}.wav'));
    if (!_checkLoop(tempo.name, loop, sixteenth: tempo.sixteenth)) failed = true;
  }
  if (failed) exitCode = 1;
}

/// True if [loop] is exactly 16 bars of [sixteenth] samples per sixteenth and
/// peaks under the ceiling; otherwise says on stderr what is wrong.
bool _checkLoop(String name, List<double> loop, {required int sixteenth}) {
  final expected = _bars * _sixteenthsPerBar * sixteenth;
  if (loop.length != expected) {
    final bars = loop.length / (_sixteenthsPerBar * sixteenth);
    stderr.writeln('$name: ${loop.length} samples is ${bars.toStringAsFixed(3)} bars, not $_bars');
    return false;
  }
  final peak = peakDb(loop);
  if (peak > _arenaPeakDb + 0.01) {
    stderr.writeln('$name: peaks at ${peak.toStringAsFixed(2)} dB, above the $_arenaPeakDb dB ceiling');
    return false;
  }
  return true;
}

/// The prepared loop at [sixteenth] samples per sixteenth, seeded with [seed]:
/// the score, the room, the spare ring-out folded back over the start, and the
/// mastering pass. No fades: a loop joins itself.
List<double> _loop(int sixteenth, int seed) {
  final rng = Random(seed);
  final length = _bars * _sixteenthsPerBar * sixteenth;
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
  return finishLoop(out, _arenaRmsDb, peakDb: _arenaPeakDb);
}

/// Every note of [score] laid into its buffer, with a spare tail for the ring.
Float64List _play(List<_Bar> score, int sixteenth, Random rng) {
  final barSamples = _sixteenthsPerBar * sixteenth;
  final beat = _beatsPerBar * sixteenth;
  final buf = Float64List(score.length * barSamples + (_spareSeconds * sampleRate).round());
  for (var i = 0; i < score.length; i++) {
    final at = i * barSamples;
    final partB = i >= _barsPerPart;
    _bassLine(buf, at, beat, score[i], rng);
    _stabs(buf, at, beat, score[i], partB: partB, rng: rng);
    _percussion(buf, at, beat, i, rng);
    _lead(buf, at, beat, score[i], partB: partB, rng: rng);
  }
  return buf;
}

/// Octave-jumping bass, one note per eighth: the root on the beats — the fifth
/// on beat 4, walking back to the root — and a plucked octave on every off-beat,
/// which is the toy band's bounce.
void _bassLine(Float64List buf, int at, int beat, _Bar bar, Random rng) {
  final eighth = beat ~/ 2;
  final beatSeconds = beat / sampleRate;
  for (var k = 0; k < _beatsPerBar; k++) {
    final start = at + k * beat;
    final name = k == _beatsPerBar - 1 ? bar.fifth : bar.root;
    _add(buf, start, bassNote(hz(name), dur: beatSeconds * 0.9, amp: k.isEven ? 0.42 : 0.32, decay: 0.24));
    final octave = k.isOdd ? bar.fifth : bar.root;
    _add(buf, start + eighth, pluck(rng, hz(octave) * 2, dur: eighth / sampleRate * 1.6, amp: 0.18, bright: 0.3));
  }
}

/// Mallet stabs on every off-beat: short and quiet in A, a little longer and
/// fuller in B, which is where the piece lifts. The voicings stay between D4 and
/// D5, above the bump's thump and under the coin and the lead, and nothing new
/// lands on a beat, where the round's tick sits.
void _stabs(Float64List buf, int at, int beat, _Bar bar, {required bool partB, required Random rng}) {
  final dur = partB ? 0.26 : 0.20;
  final amp = partB ? 0.085 : 0.055;
  final decay = partB ? 0.13 : 0.10;
  for (var k = 0; k < _beatsPerBar; k++) {
    final start = at + k * beat + beat ~/ 2;
    for (final name in bar.chord) {
      _add(buf, start, mallet(rng, hz(name), dur: dur, amp: amp, decay: decay, tone: 0.85));
    }
  }
}

/// The driving toy beat: a soft kick on every beat, a clap on 2 and 4, a shaker
/// on every sixteenth, and a clap on the head of each part's last bar. The kick
/// stays under 120 Hz and no bright transient sits on a beat, so `bump`, `coin`
/// and `tick` keep their room.
void _percussion(Float64List buf, int at, int beat, int bar, Random rng) {
  final sixteenth = beat ~/ _sixteenthsPerBeat;
  for (var k = 0; k < _sixteenthsPerBar; k++) {
    _add(buf, at + k * sixteenth, shaker(rng, amp: _shakerLevels[k % _shakerLevels.length]));
  }
  for (var k = 0; k < _beatsPerBar; k++) {
    _add(buf, at + k * beat, thump(120, 70, 0.09, 0.13));
  }
  _add(buf, at + beat, clap(rng, amp: 0.10));
  _add(buf, at + (_beatsPerBar - 1) * beat, clap(rng, amp: 0.10));
  if (bar % _barsPerPart == _barsPerPart - 1) {
    _add(buf, at, clap(rng, amp: 0.12));
  }
}

/// The bar's phrase over the first half of the bar: a staccato popnote call in
/// A, a legato whistle answer in B, both placed note by note so each note's
/// beat is exact.
void _lead(Float64List buf, int at, int beat, _Bar bar, {required bool partB, required Random rng}) {
  if (bar.lead.isEmpty) return;
  if (partB) {
    final notes = [for (final (name, beats) in bar.lead) (hz(name), beats * beat / sampleRate)];
    _add(buf, at, whistle(rng, notes, amp: 0.24));
    return;
  }
  var cursor = at;
  for (final (name, beats) in bar.lead) {
    _add(buf, cursor, popNote(hz(name), dur: 0.30, amp: 0.22, decay: 0.16));
    cursor += (beats * beat).round();
  }
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
  final seam = (loop.first - loop.last).abs();
  var steps = 0.0;
  for (var i = 1; i < loop.length; i++) {
    steps += (loop[i] - loop[i - 1]).abs();
  }
  final step = steps / (loop.length - 1);
  return '$path\n'
      '  $name: ${bpm.toStringAsFixed(2)} BPM, ${loop.length} samples, '
      '${seconds.toStringAsFixed(3)} s, RMS ${rmsDb(loop).toStringAsFixed(1)} dB, '
      'peak ${peakDb(loop).toStringAsFixed(1)} dB, seam ${seam.toStringAsFixed(5)} '
      'against a mean step of ${step.toStringAsFixed(5)}';
}
