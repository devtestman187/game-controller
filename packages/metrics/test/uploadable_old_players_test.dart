import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// The objects in a summary list such as `players` or `rounds`.
List<Map<String, Object?>> mapsOf(Object? list) => [
  if (list is List<Object?>)
    for (final entry in list)
      if (entry is Map<String, Object?>) entry,
];

/// A session as a build without `stats_share` saved it: no player entry has a
/// `share` key, since there was no answer to keep.
Map<String, Object?> oldFile() => {
  'schema': 1,
  'id': 'old',
  'host': {'type': 'windows'},
  'durationS': 60,
  'players': [
    {'install': 'a', 'player': 1},
    {'install': 'b', 'player': 2},
  ],
  'rounds': [
    {'game': 'arena', 'players': 2, 'timeS': 5.0, 'winner': 1},
    {
      'game': 'arena',
      'players': 3,
      'timeS': 9.0,
      'winner': 1,
      'winners': [1, 2],
    },
  ],
  'frames': {'drawn': 300, 'dropped': 3},
};

void main() {
  test('a file saved before this build uploads every player and every winner, as it did then', () {
    final upload = uploadableSummary(oldFile());

    expect(
      [for (final p in mapsOf(upload['players'])) p['install']],
      ['a', 'b'],
      reason: 'nobody was asked, so nobody is left out',
    );
    expect(mapsOf(upload['players']).first.containsKey('share'), isFalse, reason: 'there is no answer to mark');
    expect(mapsOf(upload['rounds']).last['winners'], [
      1,
      2,
    ], reason: 'with no answers the round goes up as it was saved');
    expect(upload['frames'], {'drawn': 300, 'dropped': 3}, reason: 'the session totals stay');
  });
}
