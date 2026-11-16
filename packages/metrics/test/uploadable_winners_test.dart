import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

SessionCollector newSession() => SessionCollector(
  id: 's1',
  hostType: HostType.windows,
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
  test('a team keeps its winners only while two of them share', () {
    final session = newSession();
    session
      ..joined('a', number: 1, atMs: 0)
      ..joined('b', number: 2, atMs: 0)
      ..joined('c', number: 3, atMs: 0)
      ..statsShare('a', true)
      ..statsShare('b', true)
      ..statsShare('c', false)
      ..roundEnded('arena', timeS: 5, modes: {'a': 'dpad', 'b': 'dpad'}, winnerIds: {'a', 'b'})
      ..roundEnded('arena', timeS: 6, modes: {'a': 'dpad', 'b': 'dpad', 'c': 'dpad'}, winnerIds: {'a', 'c'});

    final rounds = mapsOf(uploadableSummary(session.summary(10000))['rounds']);

    expect(rounds[0]['winners'], [1, 2], reason: 'both members of the winning team share');
    expect(
      rounds[1].containsKey('winners'),
      isFalse,
      reason: 'one member shares and one said no: naming half a team would say who the other was',
    );
    expect(rounds[1]['winner'], 1, reason: 'the sharing winner stays');
  });
}
