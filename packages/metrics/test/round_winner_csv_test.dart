import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A session with two phones in it, so a round has players to name.
SessionCollector collector() =>
    SessionCollector(
        id: 's1',
        hostType: HostType.windows,
        hostApp: '0.14.0',
        startedAt: DateTime.utc(2026, 11, 15),
        startMs: 0,
      )
      ..joined('phone-a', number: 1, atMs: 0)
      ..joined('phone-b', number: 2, atMs: 0);

/// A session with one round of [modes] at 60 Hz, ended as asked.
SessionCollector round(Map<String, String> modes, {String? winnerId, bool draw = false, bool robotWin = false}) =>
    collector()
      ..roundStarted(hz: 60)
      ..roundEnded('arena', timeS: 60, modes: modes, winnerId: winnerId, draw: draw, robotWin: robotWin);

/// The one round of [c]'s summary, as the report reads it.
Map roundOf(SessionCollector c) => (c.summary(1000)['rounds'] as List).single as Map;

/// The last line of [c]'s rounds CSV: its one round's row.
String rowOf(SessionCollector c) => csvRounds([c.summary(1000)]).split('\n').last;

void main() {
  test('the rounds CSV has winner, draw and players after host_app', () {
    expect(roundsCsvHeader, contains(',host_app,winner,draw,players,'));
  });

  test('a round names its winner by player number, never a name or an id', () {
    final c = round({'phone-a': 'dpad', 'phone-b': 'dpad'}, winnerId: 'phone-b');
    expect(roundOf(c)['winner'], 2, reason: 'phone-b is player 2');
    expect(rowOf(c), 's1,windows,arena,60,60.0,,,,,0.14.0,2,,2,,,,,');
  });

  test('a robot win is written as a robot, and counts for no player', () {
    final c = round({'phone-a': 'dpad'}, robotWin: true);
    expect(roundOf(c), {'game': 'arena', 'hz': 60, 'timeS': 60.0, 'players': 1, 'robot': true});
    expect(rowOf(c), 's1,windows,arena,60,60.0,,,,,0.14.0,robot,,1,,,,,');
  });

  test('a draw says so, and its winner cell stays empty', () {
    final c = round({'phone-a': 'dpad', 'phone-b': 'dpad'}, draw: true);
    expect(roundOf(c), {'game': 'arena', 'hz': 60, 'timeS': 60.0, 'players': 2, 'draw': true});
    expect(rowOf(c), 's1,windows,arena,60,60.0,,,,,0.14.0,,1,2,,,,,');
  });

  test('a team win lists each winner number, space separated, since a cell holds no comma', () {
    final c = collector()
      ..roundStarted(hz: 60)
      ..roundEnded(
        'arena',
        timeS: 60,
        modes: {'phone-a': 'dpad', 'phone-b': 'dpad'},
        winnerIds: {'phone-a', 'phone-b'},
      );
    expect(roundOf(c)['winners'], [1, 2]);
    expect(rowOf(c), 's1,windows,arena,60,60.0,,,,,0.14.0,1 2,,2,,,,,');
  });

  test('a round from before M14 leaves its cells empty, as it has them', () {
    final old = <String, Object?>{
      'id': 's1',
      'host': {'type': 'windows', 'app': '0.13.0'},
      'rounds': [
        {'game': 'arena', 'hz': 60, 'timeS': 12.5},
      ],
    };
    expect(csvRounds([old]).split('\n').last, 's1,windows,arena,60,12.5,,,,,0.13.0,,,,,,,,');
  });
}
