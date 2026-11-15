import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A session with one phone in it, so a round has a player to count
/// (M14 stats b5-2). [startMs] is the session's start on the host's clock,
/// which a round's offset counts from.
SessionCollector collector({int startMs = 0}) => SessionCollector(
  id: 's1',
  hostType: HostType.windows,
  hostApp: '0.15.0',
  startedAt: DateTime.utc(2026, 11, 15),
  startMs: startMs,
)..joined('phone-a', number: 1, atMs: startMs);

/// The one round of [c]'s summary, as the report reads it.
Map roundOf(SessionCollector c) => (c.summary(60000)['rounds'] as List).single as Map;

/// Every round of [c]'s summary, in the order they were played.
List<Map> roundsOf(SessionCollector c) => [for (final round in c.summary(60000)['rounds'] as List) round as Map];

/// The last line of [c]'s rounds CSV: its last round's row.
String rowOf(SessionCollector c) => csvRounds([c.summary(60000)]).split('\n').last;

void main() {
  test('a round says how far into the session it began, to one decimal', () {
    final c = collector()
      ..roundStarted(hz: 60, atMs: 1500)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    // The session began at 0 ms, the round at 1500: 1.5 s in.
    expect(roundOf(c), {'game': 'arena', 'hz': 60, 'timeS': 60.0, 'startS': 1.5, 'players': 1});
  });

  test('the offset counts from the session\'s start, not from zero', () {
    final c = collector(startMs: 10000)
      ..roundStarted(hz: 60, atMs: 12000)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    // 2000 ms after the session's own start.
    expect(roundOf(c)['startS'], 2.0);
  });

  test('a round before the session\'s start reads 0, never negative', () {
    final c = collector(startMs: 10000)
      ..roundStarted(hz: 60, atMs: 9000)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect(roundOf(c)['startS'], 0.0);
  });

  test('the offset is kept to a tenth of a second', () {
    final c = collector()
      ..roundStarted(hz: 60, atMs: 12340)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    // 12.34 s reads as 12.3.
    expect(roundOf(c)['startS'], 12.3);
  });

  test('two rounds give the offsets they began at, which grow', () {
    final c = collector()
      ..roundStarted(hz: 60, atMs: 2000)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'})
      ..roundStarted(hz: 60, atMs: 5000)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect([for (final round in roundsOf(c)) round['startS']], [2.0, 5.0]);
  });

  test('a round with no start recorded has no offset, as before M14', () {
    // Both an old caller (roundStarted with no atMs) and a game that wrote no
    // round_start at all.
    final old = collector()
      ..roundStarted(hz: 60)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    final noStart = collector()..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect(roundOf(old).containsKey('startS'), isFalse);
    expect(roundOf(noStart).containsKey('startS'), isFalse);
  });

  test('an abandoned round\'s start is not carried into the next round', () {
    final c = collector()
      ..roundStarted(hz: 60, atMs: 2000)
      ..roundEnded('arena', timeS: 0, modes: {'phone-a': 'dpad'}, abandoned: true)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect(roundOf(c).containsKey('startS'), isFalse);
  });

  test('the rounds CSV ends with start_s and host_build, after the fps', () {
    expect(roundsCsvHeader, endsWith(',frames_late,fps,start_s,host_build'));
    // The 16 before, the offset and the host build (M14 stats).
    expect(roundsCsvHeader.split(','), hasLength(18));
  });

  test('a round row carries its start offset, to one decimal', () {
    final c = collector()
      ..roundStarted(hz: 60, atMs: 1500)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect(rowOf(c).split(',')[16], '1.5');
  });

  test('a round with no offset leaves its cell empty', () {
    final c = collector()..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect(rowOf(c).split(','), hasLength(18));
    expect(rowOf(c).split(',')[16], '');
  });

  test('a round from before the offset was kept still parses, with an empty cell', () {
    final old = <String, Object?>{
      'id': 's1',
      'host': {'type': 'windows', 'app': '0.14.0'},
      'rounds': [
        {'game': 'arena', 'hz': 60, 'timeS': 12.5, 'players': 1},
      ],
    };
    final cells = csvRounds([old]).split('\n').last.split(',');
    expect(cells, hasLength(18));
    expect(cells.sublist(4), ['12.5', '', '', '', '', '0.14.0', '', '', '1', '', '', '', '', '']);
  });
}
