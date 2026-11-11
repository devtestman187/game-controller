import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// One round: its rate ([hz] null when the host kept the game to itself), its
/// seconds, its battery readings and the heat at its end (m12 §0.8).
Map<String, Object?> round(
  int? hz,
  double timeS, {
  double? start,
  double? end,
  bool charging = false,
  String? thermal,
}) => {
  'game': 'arena',
  'hz': ?hz,
  'timeS': timeS,
  'players': 1,
  if (start != null || end != null || charging)
    'battery': {'start': ?start, 'end': ?end, if (charging) 'charging': true},
  'thermal': ?thermal,
};

/// A player as the rate table reads them: what they measured at each rate.
Map<String, Object?> viewer({Map<String, Object?> stagesByHz = const {}, Map<String, Object?> viewByHz = const {}}) => {
  'install': 'phone-a',
  'stagesByHz': stagesByHz,
  'viewByHz': viewByHz,
};

/// A session summary of [host] with [rounds] and [players].
Map<String, Object?> summary({
  String id = 's1',
  String host = 'phone',
  Map<String, Object?>? device,
  List<Map<String, Object?>> rounds = const [],
  List<Map<String, Object?>> players = const [],
}) => {
  'schema': summarySchema,
  'id': id,
  'host': {'type': host, 'app': '0.12.0', 'device': ?device},
  'date': '2026-11-07',
  'durationS': 600,
  'players': players,
  'rounds': rounds,
  'frames': {'drawn': 0, 'dropped': 0},
};

/// One table line's cells, the padding collapsed.
List<String> cells(String line) => line.trim().split(RegExp(r'\s+'));

/// The line of [text] that starts with the rate's host and rate, e.g. `phone
/// 60 …`.
List<String> rateLine(String text, String host, int hz) =>
    cells(text.split('\n').firstWhere((line) => cells(line).take(2).join(' ') == '$host $hz'));

void main() {
  group('by frame rate (m12 §1)', () {
    test('a row per host and rate: the rounds, their minutes and the viewers numbers', () {
      final text = frameRateTable([
        summary(
          rounds: [
            round(60, 100, start: 0.80, end: 0.79, thermal: 'fair'),
            round(60, 100, start: 0.79, end: 0.78, thermal: 'fair'),
            round(30, 60, start: 0.78, end: 0.77, thermal: 'nominal'),
          ],
          players: [
            viewer(
              stagesByHz: {
                '60': {
                  'touch_to_frame': {'n': 8, 'median': 40, 'p95': 55},
                },
                '30': {
                  'touch_to_frame': {'n': 8, 'median': 90, 'p95': 120},
                },
              },
              viewByHz: {
                '60': {'frames': 6000, 'gaps': 2, 'late': 6},
                '30': {'frames': 1800, 'gaps': 1, 'late': 3},
              },
            ),
          ],
        ),
      ]);
      expect(text.split('\n')[0], 'By frame rate');
      // The headers' units keep their space; the data cells have none.
      expect(
        text.split('\n')[1].replaceAll(RegExp(r'\s+'), ' '),
        'host hz rounds minutes touch ms late/min gaps/min battery %/h thermal',
      );
      // 200 s is 3.33 min: 6 late frames are 1.8 a minute, 2 gaps are 0.6.
      expect(rateLine(text, 'phone', 60), ['phone', '60', '2', '3.3', '40/55', '1.8', '0.6', '-', 'fair']);
      expect(rateLine(text, 'phone', 30), ['phone', '30', '1', '1.0', '90/120', '3.0', '1.0', '-', 'nominal']);
    });

    test('the drop per hour covers the rounds on battery, once they add up to five minutes', () {
      final text = frameRateTable([
        summary(rounds: [round(60, 100, start: 0.80, end: 0.79), round(60, 100, start: 0.79, end: 0.78)]),
        summary(id: 's2', rounds: [round(60, 100, start: 0.78, end: 0.77)]),
      ]);
      // 300 s on battery losing 0.03 of a charge is 3 % in 1/12 h: 36 % an hour.
      expect(rateLine(text, 'phone', 60).sublist(2, 8), ['3', '5.0', '-', '0.0', '0.0', '36.0']);
    });

    test('a charging round is left out of the drop but still counts as a round', () {
      final text = frameRateTable([
        summary(
          rounds: [
            round(60, 100, start: 0.80, end: 0.79),
            round(60, 100, start: 0.79, end: 0.78),
            round(60, 100, start: 0.78, end: 0.77),
            round(60, 100, start: 0.77, end: 0.79, charging: true),
          ],
        ),
      ]);
      // 400 s of rounds, 300 s of them on battery.
      expect(rateLine(text, 'phone', 60).sublist(2, 8), ['4', '6.7', '-', '0.0', '0.0', '36.0']);
    });

    test('under five minutes on battery, a row shows a dash', () {
      final text = frameRateTable([
        summary(rounds: [round(30, 100, start: 0.80, end: 0.79), round(30, 100, start: 0.79, end: 0.78)]),
      ]);
      expect(rateLine(text, 'phone', 30).last, '-', reason: 'no thermal state recorded');
      expect(rateLine(text, 'phone', 30)[7], '-', reason: '200 s is under five minutes');
    });

    test('a round without battery readings adds no drop', () {
      final text = frameRateTable([
        summary(rounds: [round(60, 300, start: 0.80), round(60, 300)]),
      ]);
      expect(rateLine(text, 'phone', 60)[7], '-');
    });

    test('the hottest thermal state of the rounds is the row', () {
      final text = frameRateTable([
        summary(
          rounds: [
            round(60, 10, thermal: 'nominal'),
            round(60, 10, thermal: 'serious'),
            round(60, 10, thermal: 'fair'),
          ],
        ),
      ]);
      expect(rateLine(text, 'phone', 60).last, 'serious');
    });

    test('a thermal name from a newer system is not guessed at', () {
      final text = frameRateTable([
        summary(
          rounds: [
            round(60, 10, thermal: 'fair'),
            round(60, 10, thermal: 'burning'),
          ],
        ),
      ]);
      expect(rateLine(text, 'phone', 60).last, 'fair');
    });

    test('a round with no rate, or one outside 20 to 120, is not filed', () {
      final text = frameRateTable([
        summary(rounds: [round(null, 90), round(5, 90), round(240, 90)]),
      ]);
      expect(text, contains('(no data)'));
    });

    test('the CSV has a row per round, with empty cells where it has none', () {
      final text = csvRounds([
        summary(
          rounds: [
            round(60, 90, start: 0.8, end: 0.79, thermal: 'fair'),
            round(null, 12),
          ],
        ),
      ]);
      expect(text.split('\n'), [
        'session,host,game,hz,time_s,battery_start,battery_end,thermal,tags',
        's1,phone,arena,60,90.0,0.8,0.79,fair,',
        's1,phone,arena,,12.0,,,,',
      ]);
    });

    test('the report prints both new tables after the modes and before enjoyment', () {
      final text = report([
        summary(rounds: [round(60, 90)]),
      ]);
      final watched = text.indexOf('By host and where they watched');
      final rates = text.indexOf('By frame rate');
      expect(watched, greaterThan(text.indexOf('By device and mode')));
      expect(rates, greaterThan(watched));
      expect(text.indexOf('Enjoyment:'), greaterThan(rates));
    });
  });
}
