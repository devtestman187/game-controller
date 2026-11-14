import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart' show CatPreset, PuzzleSettings;

import 'support/host_harness.dart';

/// The Cat setting on the puzzle settings screen (PRD v2 G3, M14 bug b006):
/// the row beside Chaos, its three buttons, and the debug define a device test
/// sets it with.
void main() {
  /// Opens the puzzle settings screen from the home screen.
  Future<ProviderContainer> openSettings(WidgetTester tester) async {
    await pumpHost(tester, screen: const StubHome());
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PuzzleSettingsScreen)));
  }

  testWidgets('the Cat row sets how often the cat comes, and the host saves it', (tester) async {
    final container = await openSettings(tester);
    expect(
      container.read(puzzleSettingsProvider).catPreset,
      CatPreset.lively,
      reason: 'a host that saved none plays on Lively',
    );
    expect(find.text('Lively'), findsOneWidget);
    for (final (preset, label) in const [(CatPreset.calm, 'Calm'), (CatPreset.wild, 'Wild')]) {
      await tester.tap(find.byKey(Key('catPreset-${preset.name}')));
      await tester.pump();
      expect(container.read(puzzleSettingsProvider).catPreset, preset, reason: 'the $label button');
      expect(container.read(prefsProvider).getString('puzzleSettings'), contains('"catPreset":"${preset.name}"'));
    }
    await tester.tap(find.byKey(const Key('resetPuzzleSettings')));
    await tester.pump();
    expect(container.read(puzzleSettingsProvider).catPreset, CatPreset.lively, reason: 'Reset goes back to Lively');
  });

  test('a debug CAT_PRESET define sets the Cat setting, and nothing else does', () {
    const saved = PuzzleSettings(timeLimitS: 90);
    expect(withCatPresetDefine(saved, define: 'wild').catPreset, CatPreset.wild, reason: 'a device test asks for Wild');
    expect(withCatPresetDefine(saved).catPreset, CatPreset.lively, reason: 'a build with no define keeps the setting');
    expect(
      withCatPresetDefine(saved, define: 'furious').catPreset,
      CatPreset.lively,
      reason: 'a name it doesn\'t know',
    );
    expect(
      withCatPresetDefine(saved, define: 'wild', debug: false).catPreset,
      CatPreset.lively,
      reason: 'a release build',
    );
    expect(withCatPresetDefine(saved, define: 'wild').timeLimitS, 90, reason: 'only the Cat setting moves');
  });
}
