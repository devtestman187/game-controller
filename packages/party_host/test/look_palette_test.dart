import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The look's providers in the app [pumpHost] mounted.
ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(StubHome)));

/// A host screen with a dialog on it, for the case that is not a page route.
class _DialogHome extends StatelessWidget {
  const _DialogHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: HostButton(
        key: const Key('openLookDialog'),
        label: 'Open dialog',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('A dialog')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Auto at 18:59 is Sunny, and stays Sunny at 19:01 with no page route', (tester) async {
    var now = DateTime(2026, 11, 8, 18, 59);
    await pumpHost(tester, screen: const StubHome(), clock: () => now);
    final container = _container(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    // The evening comes while the screen stays put: nothing is worked out
    // again, because a round never changes its palette half-way (design D1).
    now = DateTime(2026, 11, 8, 19, 1);
    await tester.pump();
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);
  });

  testWidgets('a page pushed after 19:00 turns the look to Night', (tester) async {
    var now = DateTime(2026, 11, 8, 18, 59);
    await pumpHost(tester, screen: const StubHome(), clock: () => now);
    final container = _container(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    now = DateTime(2026, 11, 8, 19, 1);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(container.read(lookPaletteProvider), ToyPalette.night);
    // The new page draws the night sky and the night's white text.
    final theme = Theme.of(tester.element(find.byType(GamesScreen)));
    expect(theme.canvasColor, ToyColors.night.background);
  });

  testWidgets('a page popped after 7:00 turns it back to Sunny', (tester) async {
    var now = DateTime(2026, 11, 8, 19, 1);
    await pumpHost(tester, screen: const StubHome(), clock: () => now);
    final container = _container(tester);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(container.read(lookPaletteProvider), ToyPalette.night);

    now = DateTime(2026, 11, 9, 7, 1);
    await tester.tap(find.byKey(const Key('hostTitleBarBack')));
    await tester.pumpAndSettle();
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);
  });

  testWidgets('a change of the Look setting works the palette out again', (tester) async {
    final now = DateTime(2026, 11, 8, 19, 30);
    await pumpHost(tester, screen: const StubHome(), clock: () => now);
    final container = _container(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.night);

    container.read(lookSettingsProvider.notifier).setChoice(LookChoice.sunny);
    await tester.pump();
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    container.read(lookSettingsProvider.notifier).setChoice(LookChoice.night);
    await tester.pump();
    expect(container.read(lookPaletteProvider), ToyPalette.night);
  });

  testWidgets('a round freezes the palette, and a page pushed after it turns Night', (tester) async {
    var now = DateTime(2026, 11, 8, 18, 59);
    await openRace(tester, clock: () => now);
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleScreen)));
    // The host's games navigator, the one the round's pages are pushed on: the
    // home under it is off stage now, so the round's screen is the way to it.
    final navigator = Navigator.of(tester.element(find.byType(PuzzleScreen)));
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    // 19:01, with a page pushed over the round: the palette stays where the
    // round started it (design D1, M13 9 review).
    now = DateTime(2026, 11, 8, 19, 1);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Settings'))));
    await navigated(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny, reason: 'a round is on');
    navigator.pop();
    await navigated(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny, reason: 'the round goes on');

    // The round ends and Change teams brings back the join screen. No round is
    // on any more, so the next page pushed works the palette out again.
    lockEveryPiece(tester);
    await endRound(tester);
    await tester.tap(find.byKey(const Key('changeTeams')));
    await navigated(tester);
    expect(find.byType(JoinScreen), findsOneWidget);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Settings'))));
    await navigated(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.night, reason: 'no round is on now');
  });

  // Claude's step 9 review: Settings opened over a round could change the Look
  // setting itself, and the palette followed at once. The setting is saved, and
  // it shows from the first page after the round.
  testWidgets('a Look change during a round waits for the round to end', (tester) async {
    await openRace(tester, clock: () => DateTime(2026, 11, 8, 12));
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleScreen)));
    final navigator = Navigator.of(tester.element(find.byType(PuzzleScreen)));
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    container.read(lookSettingsProvider.notifier).setChoice(LookChoice.night);
    await tester.pump();
    expect(container.read(lookSettingsProvider).choice, LookChoice.night, reason: 'the setting is saved');
    expect(container.read(lookPaletteProvider), ToyPalette.sunny, reason: 'a round is on');

    lockEveryPiece(tester);
    await endRound(tester);
    await tester.tap(find.byKey(const Key('changeTeams')));
    await navigated(tester);
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Settings'))));
    await navigated(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.night, reason: 'the first page after the round');
  });

  testWidgets('a dialog is not a page route: opening one leaves the palette alone', (tester) async {
    var now = DateTime(2026, 11, 8, 18, 59);
    await pumpHost(tester, screen: const _DialogHome(), clock: () => now);
    final container = ProviderScope.containerOf(tester.element(find.byType(_DialogHome)));
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    now = DateTime(2026, 11, 8, 19, 1);
    await tester.tap(find.byKey(const Key('openLookDialog')));
    await tester.pumpAndSettle();
    expect(find.text('A dialog'), findsOneWidget);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);
  });
}
