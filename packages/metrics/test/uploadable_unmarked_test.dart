import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// The objects in a summary list such as `players` or `rounds`.
List<Map<String, Object?>> mapsOf(Object? list) => [
  if (list is List<Object?>)
    for (final entry in list)
      if (entry is Map<String, Object?>) entry,
];

/// A session saved by a build that never asked: no player entry has a `share`
/// key, since there was no answer to keep.
Map<String, Object?> unmarked() => {
  'schema': summarySchema,
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
  test('a summary with no answer on any player has no share marks', () {
    expect(hasShareMarks(unmarked()), isFalse);
  });

  test('a player who said no is a mark: the build asked, and the answer is kept', () {
    final answered = unmarked();
    (answered['players'] as List<Object?>)[1] = {'install': 'b', 'player': 2, 'share': false};

    expect(hasShareMarks(answered), isTrue, reason: 'a no is an answer, not a missing one');
  });

  test('an unmarked summary uploads no player and no round winner', () {
    final saved = unmarked();

    final upload = uploadableSummary(saved);

    expect(upload['players'], isEmpty, reason: 'nobody in this file was asked');
    expect(mapsOf(upload['rounds']).first, {
      'game': 'arena',
      'players': 2,
      'timeS': 5.0,
    }, reason: 'the round keeps only its totals');
    expect(mapsOf(upload['rounds']).last, {
      'game': 'arena',
      'players': 3,
      'timeS': 9.0,
    }, reason: 'the winning team and the winner go with the players');
    expect(upload['frames'], {'drawn': 300, 'dropped': 3}, reason: 'the session totals stay');
    expect(mapsOf(saved['players']), hasLength(2), reason: 'the record handed in is not changed');
  });
}
