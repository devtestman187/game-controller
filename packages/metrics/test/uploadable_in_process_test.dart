import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

SessionCollector newSession() => SessionCollector(
  id: 's1',
  hostType: HostType.phone,
  hostApp: '0.14.0',
  startedAt: DateTime.utc(2026, 11, 16, 12),
  startMs: 0,
);

/// The objects in a summary list such as `players` or `rounds`.
List<Map<String, Object?>> mapsOf(Object? list) => [
  if (list is List<Object?>)
    for (final entry in list)
      if (entry is Map<String, Object?>) entry,
];

void main() {
  test("the host phone's own player is in the upload, since its answer is the host's", () {
    final session = newSession()
      ..joined('own-player', number: 1, atMs: 0, inProcess: true, platform: 'ios', app: '0.14.0')
      ..roundStarted(atMs: 0)
      ..roundEnded('arena', timeS: 5, modes: {'own-player': 'dpad'}, winnerId: 'own-player');

    final upload = uploadableSummary(session.summary(10000));
    final player = mapsOf(upload['players']).single;

    expect(player['install'], 'own-player', reason: 'Play on this phone joined over the in-process link');
    expect(player['share'], isTrue, reason: 'the host said yes, so its own player counts as sharing');
    expect(player['watched'], 'host_phone');
    expect(mapsOf(upload['rounds']).single['winner'], 1, reason: 'the winner shares, so the round keeps it');
  });
}
