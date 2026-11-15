import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/src/session_recorder.dart';

/// The recorder's clock (M14 stats b5-2): a round's offset into the session is
/// read from the clock [SessionRecorder] is given, so a test names it exactly
/// and no real time is involved.
void main() {
  late HostServer server;
  late ServerGameHost host;
  late SessionCollector session;
  late SessionRecorder recorder;

  /// The injected clock, in ms: only the test moves it.
  late int clockMs;

  /// Every round of the session, as the summary writes them.
  List<Map<String, Object?>> rounds() => [
    for (final round in session.summary(clockMs)['rounds'] as List) round as Map<String, Object?>,
  ];

  /// Plays one 60 s arena round that began when the clock read [atMs].
  void playRound(int atMs) {
    clockMs = atMs;
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
  }

  setUp(() {
    server = HostServer(hostId: 'host', hostName: 'TV', appVersion: '0.13.0', listeners: const []);
    host = ServerGameHost(server);
    // The session began at 1 s on the fake clock, a time the host's real clock
    // never reads, so only the injected clock can give the offsets below.
    session = SessionCollector(
      id: 's1',
      hostType: HostType.androidTv,
      hostApp: '0.13.0',
      startedAt: DateTime.utc(2026, 11, 15),
      startMs: 1000,
    )..joined('p1', number: 1, atMs: 1000);
    clockMs = 1000;
    recorder = SessionRecorder(host: host, session: () => session, nowMs: () => clockMs);
  });

  tearDown(() async {
    await host.dispose();
    await server.dispose();
  });

  test('each round says exactly how far into the session it began', () {
    playRound(1000);
    playRound(62500);
    playRound(126000);

    expect([for (final round in rounds()) round['startS']], [0.0, 61.5, 125.0]);
  });

  test('the clock\'s ms reach the session, which keeps a tenth of a second', () {
    // 12.34 s into the session reads as 12.3.
    playRound(13340);

    expect(rounds().single['startS'], 12.3);
  });
}
