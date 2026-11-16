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
  test('a player who said yes stays in the upload, a player who said nothing goes', () {
    final session = newSession();
    session
      ..joined('yes', number: 1, atMs: 0)
      ..joined('silent', number: 2, atMs: 0)
      ..statsShare('yes', true)
      ..gameValue('arena', 'wall_hit', 'silent', 3)
      ..roundStarted(atMs: 0)
      ..roundEnded('arena', timeS: 10, modes: {'yes': 'dpad', 'silent': 'sticks'}, winnerId: 'silent');
    final saved = session.summary(20000);

    final upload = uploadableSummary(saved);

    // The saved record marks every player's answer and keeps both of them.
    expect([for (final p in mapsOf(saved['players'])) p['share']], [true, false]);
    expect([for (final p in mapsOf(saved['players'])) p['install']], ['yes', 'silent']);
    // The upload keeps the one who said yes, with all their own data.
    expect([for (final p in mapsOf(upload['players'])) p['install']], ['yes']);
    expect(mapsOf(upload['players']).single['share'], isTrue);
    // The round keeps its totals, and loses the winner who said nothing.
    expect(mapsOf(upload['rounds']).single, {'game': 'arena', 'timeS': 10.0, 'startS': 0.0, 'players': 2});
    expect(mapsOf(saved['rounds']).single['winner'], 2, reason: 'the saved file keeps the winner');
    // The session's own totals stay.
    expect(upload['id'], 's1');
    expect(upload['durationS'], 20);
    expect(upload['frames'], {'drawn': 0, 'dropped': 0});
  });

  test('a winning team keeps only the members who share', () {
    final session = newSession();
    session
      ..joined('yes', number: 1, atMs: 0)
      ..joined('no', number: 2, atMs: 0)
      ..joined('also', number: 3, atMs: 0)
      ..statsShare('yes', true)
      ..statsShare('also', true)
      ..roundEnded('arena', timeS: 5, modes: {'yes': 'dpad', 'no': 'dpad', 'also': 'dpad'}, winnerIds: {'yes', 'no'});

    final round = mapsOf(uploadableSummary(session.summary(10000))['rounds']).single;

    expect(round['winner'], 1, reason: 'the team\'s first player said yes');
    expect(round['winners'], [1], reason: 'player 2 said no and is left out');
    expect(round['players'], 3, reason: 'three players took part');
  });

  test('a local player of the host shares, since the host\'s own answer allows the upload', () {
    final session = newSession()..joined('tv', number: 1, atMs: 0, local: true);

    expect(mapsOf(session.summary(1000)['players']).single['share'], isTrue);
  });

  test('a summary with no answer at all uploads no player but every round total', () {
    final old = <String, Object?>{
      'schema': 1,
      'id': 'x',
      'host': {'type': 'windows'},
      'durationS': 5,
      'players': [
        {'install': 'a', 'player': 1},
        {'install': 'b', 'player': 2},
      ],
      'rounds': [
        {'game': 'arena', 'players': 4, 'timeS': 2.0, 'winner': 1},
      ],
      'frames': {'drawn': 10, 'dropped': 1},
    };

    final upload = uploadableSummary(old);

    expect(mapsOf(upload['players']), isEmpty);
    expect(mapsOf(upload['rounds']).single, {'game': 'arena', 'players': 4, 'timeS': 2.0});
    expect(upload['frames'], {'drawn': 10, 'dropped': 1});
    expect(mapsOf(old['players']), hasLength(2), reason: 'the record handed in is not changed');
  });
}
