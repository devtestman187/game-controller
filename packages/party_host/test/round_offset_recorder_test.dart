import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/src/session_recorder.dart';

/// When in the session each round began (M14 stats b5-2): the recorder stamps
/// `round_start` with the clock it is given, the one the session counts its
/// start from, so a round says how far into the session it began.
void main() {
  late HostServer server;
  late ServerGameHost host;
  late SessionCollector session;
  late SessionRecorder recorder;

  /// The fake clock, in ms: the recorder and the session both read it.
  late int clockMs;

  /// The one round of the session, as the summary writes it.
  Map<String, Object?> round() => (session.summary(clockMs)['rounds'] as List).single as Map<String, Object?>;

  /// A session that began [agoMs] before the clock's current time.
  void startSession({int agoMs = 0}) {
    session = SessionCollector(
      id: 's1',
      hostType: HostType.androidTv,
      hostApp: '0.13.0',
      startedAt: DateTime.utc(2026, 11, 15),
      startMs: clockMs - agoMs,
    );
    recorder = SessionRecorder(host: host, session: () => session, nowMs: () => clockMs);
  }

  setUp(() {
    server = HostServer(hostId: 'host', hostName: 'TV', appVersion: '0.13.0', listeners: const []);
    host = ServerGameHost(server);
    clockMs = 900000;
  });

  tearDown(() async {
    await host.dispose();
    await server.dispose();
  });

  test('a round keeps the time it started at, not the time it ended', () {
    // The session began 20 s before now; the round begins now, so it reads
    // 20 s in, and its 60 s of play do not move that.
    startSession(agoMs: 20000);
    recorder.onRecord(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
    clockMs += 60000;
    recorder.onRecord(
      const GameRecord(
        game: 'arena',
        name: 'round_end',
        data: {
          'timeS': 60.0,
          'modes': {'p1': 'dpad'},
        },
      ),
    );

    expect(round(), {'game': 'arena', 'hz': 60, 'timeS': 60.0, 'startS': 20.0, 'players': 1});
  });

  test('a round the game wrote no start for has no offset', () {
    startSession(agoMs: 61500);
    recorder.onRecord(
      const GameRecord(
        game: 'arena',
        name: 'round_end',
        data: {
          'timeS': 10.0,
          'modes': {'p1': 'dpad'},
        },
      ),
    );

    expect(round().containsKey('startS'), isFalse);
  });
}
