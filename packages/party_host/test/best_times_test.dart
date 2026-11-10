import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The best times kept on the host (M14 c2, PRD v2 T15 and design section 9
/// N14): a finished board's time saved, shown on the results, and beaten.
void main() {
  /// A container over an empty set of saved preferences.
  Future<ProviderContainer> timesContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    return container;
  }

  group('the best times', () {
    test('a first finished board is saved as the best, its time and names', () async {
      final container = await timesContainer();
      final times = container.read(bestTimesProvider.notifier);
      final now = times.record(puzzleId: 'house', team: false, timeMs: 95000, names: ['Mia']);
      expect(now.isRecord, isTrue);
      expect(now.best!.timeMs, 95000);
      expect(now.best!.names, ['Mia']);
      expect(times.bestFor('house', team: false)!.timeMs, 95000);
    });

    test('a faster board beats it, a slower one does not, and the best stays', () async {
      final container = await timesContainer();
      final times = container.read(bestTimesProvider.notifier);
      times.record(puzzleId: 'house', team: false, timeMs: 95000, names: ['Mia']);
      final faster = times.record(puzzleId: 'house', team: false, timeMs: 88000, names: ['Dad']);
      expect(faster.isRecord, isTrue);
      final slower = times.record(puzzleId: 'house', team: false, timeMs: 91000, names: ['Sam']);
      expect(slower.isRecord, isFalse);
      expect(slower.best!.timeMs, 88000);
      expect(times.bestFor('house', team: false)!.names, ['Dad']);
    });

    test('solo and team times are kept apart, and an even one is the same', () async {
      final container = await timesContainer();
      final times = container.read(bestTimesProvider.notifier);
      times.record(puzzleId: 'house', team: false, timeMs: 95000, names: ['Mia']);
      final team = times.record(puzzleId: 'house', team: true, timeMs: 110000, names: ['Mia', 'Dad']);
      expect(team.isRecord, isTrue, reason: 'the team board had no time yet');
      expect(times.bestFor('house', team: false)!.timeMs, 95000);
      expect(times.bestFor('house', team: true)!.timeMs, 110000);
      final even = times.record(puzzleId: 'house', team: false, timeMs: 95000, names: ['Sam']);
      expect(even.isRecord, isFalse, reason: 'a time level with the best does not beat it');
    });

    test('only the fastest three are kept', () async {
      final container = await timesContainer();
      final times = container.read(bestTimesProvider.notifier);
      for (final (i, timeMs) in [120000, 100000, 110000, 90000].indexed) {
        times.record(puzzleId: 'house', team: false, timeMs: timeMs, names: ['P${i + 1}']);
      }
      expect([for (final time in times.boardFor('house', team: false)) time.timeMs], [90000, 100000, 110000]);
    });

    test('the times are saved on the host: a new container reads them back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(first.dispose);
      first
          .read(bestTimesProvider.notifier)
          .record(puzzleId: 'house', team: true, timeMs: 88000, names: ['Mia', 'Dad']);

      final second = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(second.dispose);
      final best = second.read(bestTimesProvider).bestFor('house', team: true)!;
      expect(best.timeMs, 88000);
      expect(best.names, ['Mia', 'Dad']);
    });
  });

  group('on the results', () {
    /// Play the house puzzle alone to its end: the results card is up.
    Future<FakeHostService> playHouseSolo(WidgetTester tester) async {
      final fake = await pumpHost(tester, screen: const StubHome());
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      await startRound(tester, fake);
      lockEveryPiece(tester);
      await endRound(tester);
      return fake;
    }

    testWidgets('a finished round saves its time, shows it with New record! and plays the cue', (tester) async {
      await playHouseSolo(tester);

      expect(find.byKey(const Key('newRecord')), findsOneWidget);
      expect(sounds.played, contains('new_record'));
      final best = tester.widget<Text>(find.byKey(const Key('bestTime-left')));
      expect(best.data, startsWith('Best 0:0'));
      final saved = appContainer(tester).read(bestTimesProvider).bestFor('house', team: false)!;
      expect(saved.timeMs, inInclusiveRange(0, 1000));
      expect(saved.names, ['iPhone 3F1C']);
    });

    testWidgets('a round slower than the best shows the best and no chip', (tester) async {
      final fake = await pumpHost(tester, screen: const StubHome());
      appContainer(tester)
          .read(bestTimesProvider.notifier)
          .record(puzzleId: 'house', team: false, timeMs: 1, names: ['Mia']);
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      await startRound(tester, fake);
      lockEveryPiece(tester);
      await endRound(tester);

      expect(find.byKey(const Key('newRecord')), findsNothing);
      expect(sounds.played, isNot(contains('new_record')));
      expect(tester.widget<Text>(find.byKey(const Key('bestTime-left'))).data, 'Best 0:00');
    });
  });
}
