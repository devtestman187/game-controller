import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/host_harness.dart';

/// The best times of the puzzles redrawn in M14 (B-012): the Medium boards
/// saved on the old pictures are cleared the once, and Easy and Hard stay.
void main() {
  /// A saved board of [id] at [timeMs], with the names that played it.
  Map<String, Object?> savedBoard(String id, {required bool team, required int timeMs}) => {
    BestTimes.boardKey(id, team: team): [
      {
        'ms': timeMs,
        'names': team ? ['Mia', 'Dad'] : ['Mia'],
      },
    ],
  };

  /// The times an older build saved: both boards of every Medium puzzle, plus
  /// an Easy and a Hard one.
  final oldTimes = <String, Object?>{
    for (final id in redoneMediumPuzzleIds) ...{
      ...savedBoard(id, team: false, timeMs: 60000),
      ...savedBoard(id, team: true, timeMs: 90000),
    },
    ...savedBoard('house', team: false, timeMs: 95000),
    ...savedBoard('dragon', team: true, timeMs: 120000),
  };

  /// The prefs holding [values], as the host saves them.
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  /// A container over [prefs], the host's best times read from it.
  ProviderContainer timesContainer(SharedPreferences prefs) {
    final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    return container;
  }

  group('the old Medium best times', () {
    test('go once, and the Easy and Hard ones stay', () async {
      final prefs = await prefsWith({'bestTimes': jsonEncode(oldTimes)});
      final container = timesContainer(prefs);
      final times = container.read(bestTimesProvider);

      for (final id in redoneMediumPuzzleIds) {
        expect(times.boardFor(id, team: false), isEmpty, reason: '$id solo was cleared');
        expect(times.boardFor(id, team: true), isEmpty, reason: '$id team was cleared');
      }
      expect(times.bestFor('house', team: false)!.timeMs, 95000, reason: 'Easy stays');
      expect(times.bestFor('dragon', team: true)!.timeMs, 120000, reason: 'Hard stays');
    });

    test('are saved back without the Medium boards', () async {
      final prefs = await prefsWith({'bestTimes': jsonEncode(oldTimes)});
      timesContainer(prefs).read(bestTimesProvider);

      final saved = jsonDecode(prefs.getString('bestTimes')!) as Map<String, Object?>;
      expect(
        saved.keys,
        unorderedEquals([BestTimes.boardKey('house', team: false), BestTimes.boardKey('dragon', team: true)]),
      );
      expect(prefs.getInt('bestTimesVersion'), bestTimesVersion, reason: 'the clear is marked done');
    });

    test('are cleared only once: a Medium time played after it survives a restart', () async {
      final prefs = await prefsWith({'bestTimes': jsonEncode(oldTimes)});
      final first = timesContainer(prefs);
      final now = first
          .read(bestTimesProvider.notifier)
          .record(puzzleId: 'boat', team: false, timeMs: 71000, names: ['Mia']);
      expect(now.isRecord, isTrue, reason: 'the boat board has nothing left');

      final second = timesContainer(prefs);
      final best = second.read(bestTimesProvider).bestFor('boat', team: false);
      expect(best, isNotNull, reason: 'the restart does not clear it again');
      expect(best!.timeMs, 71000);
    });

    test('leave a fresh install marked, so its first Medium time survives a restart', () async {
      final prefs = await prefsWith({});
      final first = timesContainer(prefs);
      expect(first.read(bestTimesProvider).bestFor('car', team: false), isNull, reason: 'nothing is kept yet');
      expect(prefs.getInt('bestTimesVersion'), bestTimesVersion);
      first.read(bestTimesProvider.notifier).record(puzzleId: 'car', team: false, timeMs: 50000, names: ['Mia']);

      final second = timesContainer(prefs);
      expect(second.read(bestTimesProvider).bestFor('car', team: false)!.timeMs, 50000);
    });

    test('list the library\'s Medium puzzles', () {
      final medium = [for (final puzzle in testPuzzles().ofLevel(Level.medium)) puzzle.id];
      expect(
        redoneMediumPuzzleIds,
        unorderedEquals(medium),
        reason: 'the clear names every Medium puzzle, and no other',
      );
    });

    test('leave unreadable times alone: the host starts with none', () async {
      final prefs = await prefsWith({'bestTimes': 'not a times map'});
      final times = timesContainer(prefs).read(bestTimesProvider);
      expect(times.bestFor('house', team: false), isNull);
      expect(prefs.getString('bestTimes'), 'not a times map', reason: 'the clear does not throw on bad data');
    });
  });
}
