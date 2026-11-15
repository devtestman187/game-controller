import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/src/session_recorder.dart';

/// When in the session each round began (M14 stats b5-2): the recorder stamps
/// `round_start` with the host's own clock, the one the session counts its
/// start from, so a round says how far into the session it began.
void main() {
  late HostServer server;
  late ServerGameHost host;
  late SessionCollector session;
  late SessionRecorder recorder;

  /// The one round of the session, as the summary writes it.
  Map<String, Object?> round() => (session.summary(host.nowMs)['rounds'] as List).single as Map<String, Object?>;

  /// A session that began [agoMs] before now on the host's clock.
  void startSession({int agoMs = 0}) {
    session = SessionCollector(
      id: 's1',
      hostType: HostType.androidTv,
      hostApp: '0.13.0',
      startedAt: DateTime.utc(2026, 11, 15),
      startMs: host.nowMs - agoMs,
    );
    recorder = SessionRecorder(host: host, session: () => session);
  }

  setUp(() {
    server = HostServer(hostId: 'host', hostName: 'TV', appVersion: '0.13.0', listeners: const []);
    host = ServerGameHost(server);
  });

  tearDown(() async {
    await host.dispose();
    await server.dispose();
  });

  test('the recorder starts a round on the host\'s clock, so its offset is known', () {
    // The session began 61.5 s ago; the round begins now, so it reads 61.5 s
    // in (the host's clock takes a few ms, far under the tenth of a second).
    startSession(agoMs: 61500);
    recorder.onRecord(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
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

    expect(round(), {'game': 'arena', 'hz': 60, 'timeS': 60.0, 'startS': 61.5, 'players': 1});
  });

  test('a round at the session\'s start reads 0', () {
    startSession();
    recorder.onRecord(const GameRecord(game: 'arena', name: 'round_start', data: {'hz': 60}));
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

    expect(round()['startS'], 0.0);
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
