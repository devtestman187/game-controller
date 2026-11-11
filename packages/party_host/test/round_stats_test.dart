import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/src/session_recorder.dart';
import 'package:protocol/protocol.dart';

/// What a round leaves in the session's stats (M14 groundwork, design §2 N1):
/// a round that was played adds its round and its rounds-per-format count, and
/// the empty `round_end` both games write when the host abandons a round adds
/// neither. The recorder is asked directly, so the records stay in step.
void main() {
  late HostServer server;
  late ServerGameHost host;
  late SessionCollector session;
  late SessionRecorder recorder;

  /// The session's rounds, as the summary writes them.
  List<Object?> rounds() => session.summary(0)['rounds'] as List<Object?>;

  /// P1's record, as the summary writes it.
  Map<String, Object?> player() => (session.summary(0)['players'] as List).single as Map<String, Object?>;

  /// P1's counts for [game], or null when the session has none.
  Map<String, Object?>? gameCounts(String game) {
    final games = player()['games'];
    final counts = games is Map ? games[game] : null;
    return counts is Map<String, Object?> ? counts : null;
  }

  setUp(() {
    server = HostServer(hostId: 'host', hostName: 'TV', appVersion: '0.13.0', listeners: const []);
    host = ServerGameHost(server);
    session = SessionCollector(
      id: 's1',
      hostType: HostType.androidTv,
      hostApp: '0.13.0',
      startedAt: DateTime.utc(2026, 11, 9),
      startMs: 0,
    );
    session.joined('p1', number: 1, atMs: 0);
    recorder = SessionRecorder(host: host, session: () => session);
  });

  tearDown(() async {
    await host.dispose();
    await server.dispose();
  });

  test('an abandoned round adds no round and no rounds-per-format to the stats', () {
    recorder.onRecord(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
    // Both games' abandon(): a round_end with only the reason.
    recorder.onRecord(const GameRecord(game: 'arena', name: 'round_end', data: {'reason': ViewEndReason.abandoned}));

    expect(rounds(), isEmpty, reason: 'a round nobody played is no round');
    expect(gameCounts('arena'), isNull, reason: 'no round and no rounds-per-format count');

    // The round stopped, so the player leaving now is not a quit mid-game.
    session.left('p1', 1000);
    expect(player()['quitsMidGame'], isNull, reason: 'the abandoned round ended');
  });

  test('a played round still adds its round and its rounds-per-format count', () {
    recorder.onRecord(const GameRecord(game: 'puzzle', name: 'round_start', data: {'hz': 60}));
    recorder.onRecord(
      const GameRecord(
        game: 'puzzle',
        name: 'round_end',
        data: {
          'timeS': 42.0,
          'modes': {'p1': 'dpad'},
          'format': 'solo',
          'winner': 'p1',
        },
      ),
    );

    expect(rounds(), [
      {'game': 'puzzle', 'hz': 60, 'timeS': 42.0, 'players': 1, 'winner': 1},
    ]);
    expect(gameCounts('puzzle'), {'wins': 1, 'rounds': 1, 'rounds_solo': 1});
  });

  test('a round\'s tags go into its summary, for "By game and feature" (M14)', () {
    recorder.onRecord(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
    recorder.onRecord(
      const GameRecord(
        game: 'arena',
        name: 'round_end',
        data: {
          'timeS': 60.0,
          'modes': {'p1': 'dpad'},
          'winner': 'p1',
          'tags': ['mode_bumper', 'map_playroom', 'robo_easy', 'finished', 'night_1of3'],
        },
      ),
    );

    expect(rounds().single, {
      'game': 'arena',
      'hz': 60,
      'timeS': 60.0,
      'players': 1,
      'winner': 1,
      'tags': ['mode_bumper', 'map_playroom', 'robo_easy', 'finished', 'night_1of3'],
    });
  });
}
