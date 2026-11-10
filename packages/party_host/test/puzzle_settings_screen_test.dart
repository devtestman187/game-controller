import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart' show Chaos;

import 'support/host_harness.dart';

void main() {
  testWidgets('the puzzle settings change straight away, are saved, and reset to the defaults', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(find.text('±15°'), findsOneWidget);
    // The remote: − is focused first; Right goes to the value's +.
    await tester.tap(find.byTooltip('More Angle tolerance'));
    await tester.pump();
    expect(find.text('±16°'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleSettingsScreen)));
    expect(container.read(puzzleSettingsProvider).angleToleranceDeg, 16);
    final prefs = container.read(prefsProvider);
    expect(prefs.getString('puzzleSettings'), contains('"angleToleranceDeg":16'));
    await tester.scrollUntilVisible(find.byKey(const Key('setting-dropReadyHighlight')), 200);
    await tester.ensureVisible(find.byKey(const Key('setting-dropReadyHighlight')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const Key('setting-dropReadyHighlight')), matching: find.byType(Switch)),
    );
    await tester.pump();
    expect(container.read(puzzleSettingsProvider).dropReadyHighlight, isFalse);
    await tester.tap(find.byKey(const Key('resetPuzzleSettings')));
    await tester.pump();
    expect(container.read(puzzleSettingsProvider).angleToleranceDeg, 15);
    expect(container.read(puzzleSettingsProvider).dropReadyHighlight, isTrue);
  });

  testWidgets('the cat\'s three buttons set the Chaos setting, saved, and a new host plays on A little', (
    tester,
  ) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleSettingsScreen)));
    expect(
      container.read(puzzleSettingsProvider).chaos,
      Chaos.little,
      reason: 'a host that saved none plays on A little',
    );
    expect(find.text('A little'), findsOneWidget);
    for (final (chaos, label) in const [(Chaos.off, 'Off'), (Chaos.party, 'Party'), (Chaos.little, 'A little')]) {
      await tester.tap(find.byKey(Key('chaos-${chaos.name}')));
      await tester.pump();
      expect(container.read(puzzleSettingsProvider).chaos, chaos, reason: 'the $label button');
      expect(container.read(prefsProvider).getString('puzzleSettings'), contains('"chaos":"${chaos.name}"'));
    }
    // Reset goes back to the host's own default, A little.
    await tester.tap(find.byKey(const Key('chaos-party')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resetPuzzleSettings')));
    await tester.pump();
    expect(container.read(puzzleSettingsProvider).chaos, Chaos.little);
  });
}
