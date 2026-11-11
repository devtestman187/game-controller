import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// A session with one phone in it, so a round and a rating have a player to
/// count (M14's "By game and feature").
SessionCollector collector() => SessionCollector(
  id: 's1',
  hostType: HostType.windows,
  hostApp: '0.13.0',
  startedAt: DateTime.utc(2026, 11, 10),
  startMs: 0,
)..joined('phone-a', number: 1, atMs: 0);

/// The one round of [c]'s summary, as the report reads it.
Map roundOf(SessionCollector c) => (c.summary(1000)['rounds'] as List).single as Map;

/// The one rating of [c]'s summary's player.
Map ratingOf(SessionCollector c) =>
    (((c.summary(1000)['players'] as List).single as Map)['ratings'] as List).single as Map;

void main() {
  test('a round keeps the tags it was given, which place it in the report', () {
    final c = collector()
      ..roundEnded(
        'arena',
        timeS: 60,
        modes: {'phone-a': 'dpad'},
        tags: ['mode_bumper', 'map_toy-factory', 'robo_easy', 'finished', 'night_2of3'],
      );
    expect(roundOf(c), {
      'game': 'arena',
      'timeS': 60.0,
      'players': 1,
      'tags': ['mode_bumper', 'map_toy-factory', 'robo_easy', 'finished', 'night_2of3'],
    });
  });

  test('a round with no tags has none in its summary, as before M14', () {
    final c = collector()..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});
    expect(roundOf(c), {'game': 'arena', 'timeS': 60.0, 'players': 1});
  });

  test('a tag that is no round tag is dropped, so none carries a person\'s words', () {
    final c = collector()
      ..roundEnded(
        'arena',
        timeS: 60,
        modes: {'phone-a': 'dpad'},
        tags: ['mode_bumper', 'Mia was here', 'a' * 40, 'finished'],
      );
    expect(roundOf(c)['tags'], ['mode_bumper', 'finished']);
  });

  test('a round keeps at most eight tags', () {
    final c = collector()
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'}, tags: [for (var i = 0; i < 12; i++) 'tag_$i']);
    expect(roundOf(c)['tags'], ['tag_0', 'tag_1', 'tag_2', 'tag_3', 'tag_4', 'tag_5', 'tag_6', 'tag_7']);
    expect(maxRoundTags, 8);
  });

  test('a rating says which round it asked about, so the report counts it there', () {
    final c = collector()
      ..rating(
        'phone-a',
        RatingMessage(id: 'r1', face: RatingFace.good),
        game: 'arena',
        roundTags: ['mode_bumper', 'map_playroom', 'night_1of3'],
      );
    expect(ratingOf(c), {
      'game': 'arena',
      'face': 'good',
      'tags': [],
      'round': ['mode_bumper', 'map_playroom', 'night_1of3'],
    });
  });

  test('a rating asked about an untagged round says no round', () {
    final c = collector()
      ..rating(
        'phone-a',
        RatingMessage(id: 'r1', face: RatingFace.okay),
        game: 'arena',
      );
    expect(ratingOf(c), {'game': 'arena', 'face': 'okay', 'tags': []});
  });
}
