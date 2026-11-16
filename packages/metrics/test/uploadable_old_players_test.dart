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
  test('a file saved before this build uploads no player and no round winner', () {
    final saved = oldFile();

    final upload = uploadableSummary(saved);

    expect(hasShareMarks(saved), isFalse, reason: 'nobody in this file was asked');
    expect(upload['players'], isEmpty, reason: 'the owner drops a session nobody in was asked about (sentry2)');
    expect(mapsOf(upload['rounds']), hasLength(2), reason: 'the rounds happened, so their totals stay');
    expect(mapsOf(upload['rounds']).first, {'game': 'arena', 'players': 2, 'timeS': 5.0});
    expect(mapsOf(upload['rounds']).last, {
      'game': 'arena',
      'players': 3,
      'timeS': 9.0,
    }, reason: 'the winner and the winning team go with the players');
    expect(upload['frames'], {'drawn': 300, 'dropped': 3}, reason: 'the session totals stay');
    expect(mapsOf(saved['players']), hasLength(2), reason: 'the saved file itself is not changed');
  });
}
