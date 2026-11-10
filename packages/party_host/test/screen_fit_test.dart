import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/toy_fonts.dart';

/// The two looks every restyled screen is measured in (M13 3b, rule 7): the
/// TV's at 960×540 and a phone's at 852×393, Sunny and Night, with the look's
/// own fonts loaded. A screen that spills its type throws, so a fit is "no
/// exception"; nothing here pins a size, so a screen may shrink its spacing or
/// its layout to fit, but never its type.
final _tvSunny = (name: '960x540 TV, Sunny', size: const Size(960, 540), tv: true, clock: DateTime(2026, 11, 8, 12));
final _tvNight = (name: '960x540 TV, Night', size: const Size(960, 540), tv: true, clock: DateTime(2026, 11, 8, 22));
final _phoneSunny = (
  name: '852x393 phone, Sunny',
  size: const Size(852, 393),
  tv: false,
  clock: DateTime(2026, 11, 8, 12),
);
final _phoneNight = (
  name: '852x393 phone, Night',
  size: const Size(852, 393),
  tv: false,
  clock: DateTime(2026, 11, 8, 22),
);
final _looks = [_tvSunny, _tvNight, _phoneSunny, _phoneNight];

/// Mounts [screen] in one of the looks' sizes and palettes.
Future<FakeHostService> pumpIn(
  WidgetTester tester,
  ({String name, Size size, bool tv, DateTime clock}) look, {
  Widget screen = const StubHome(),
  List<Override> overrides = const [],
  List<Map<String, Object?>> sessions = const [],
}) => pumpHost(
  tester,
  screen: screen,
  size: look.size,
  clock: () => look.clock,
  sessions: sessions,
  overrides: [toyTvProvider.overrideWithValue(look.tv), ...overrides],
);

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);

  for (final look in _looks) {
    testWidgets('the menus fit at ${look.name}', (tester) async {
      final fake = await pumpIn(tester, look);
      // The game picker.
      await tapVisible(tester, find.byKey(const Key('openPlay')));
      await tester.pumpAndSettle();
      expect(find.byType(GamesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The puzzle's playtest settings.
      await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // The Shape Race list, then the join screen with P1 on the left.
      await tapVisible(tester, find.byKey(const Key('pickShapeRace')));
      await tester.pumpAndSettle();
      expect(find.byType(ShapeRaceScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byKey(const Key('puzzle-house')));
      await tester.pumpAndSettle();
      await neutral(tester, fake, ['p1']);
      await press(tester, fake, 'p1', GamepadButton.a);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cards over the round fit at ${look.name}', (tester) async {
      final fake = await openRace(
        tester,
        size: look.size,
        clock: () => look.clock,
        overrides: [toyTvProvider.overrideWithValue(look.tv)],
      );
      expect(find.byType(PuzzleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The pause menu.
      await press(tester, fake, 'p1', GamepadButton.start);
      await navigated(tester);
      expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('pauseResume')));
      await navigated(tester);

      // The card over a phone that is away, then the game goes on without it.
      await holdSlot(tester, fake, 'p2');
      expect(find.byKey(const Key('awayCard')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('goOnWithout')));
      await navigated(tester);

      // The results card.
      lockEveryPiece(tester);
      await endRound(tester);
      expect(find.byKey(const Key('puzzleResults')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Arena and its debug card fit at ${look.name}', (tester) async {
      final fake = await pumpIn(tester, look);
      // The waiting card first, with its maps and Robo's line (M14 b2). The
      // sample phone holds A, which readies it at once, so it is quieted first.
      await neutral(tester, fake, ['p1']);
      await openArenaCard(tester);
      expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await readyUp(tester, fake);
      await roundStarted(tester);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The debug overlay is a paper card at the top left (M13 3b). The arena
      // runs a loop, so it never settles: the frames are counted.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const Key('debugOverlay')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stats, its sessions and the consent dialog fit at ${look.name}', (tester) async {
      await pumpIn(tester, look, screen: const StatsScreen(), sessions: [sampleSession()]);
      expect(find.byKey(const Key('sessionTable')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('statsSharing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('consentNo')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  // Claude's 4c review: with each badge's accessory given room above it, two
  // players on a side no longer fitted a TV's side card, and the second row was
  // cut in half. Four players must show whole on a TV, without scrolling.
  testWidgets("four players show whole on a TV's join screen", (tester) async {
    final fake = await pumpIn(tester, _tvSunny);
    var state = fake.state;
    for (final n in [2, 3, 4]) {
      state = withController(state, phoneInfo('p$n', n));
    }
    fake.state = state;
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2', 'p3', 'p4']);
    await openJoin(tester);
    for (final id in ['p1', 'p2', 'p3', 'p4']) {
      await press(tester, fake, id, GamepadButton.a);
    }
    for (final side in ['left', 'right']) {
      final card = tester.getRect(find.descendant(of: find.byKey(Key('side-$side')), matching: find.byType(ToyCard)));
      final names = find.descendant(of: find.byKey(Key('side-$side')), matching: find.textContaining('Phone'));
      expect(names, findsWidgets);
      for (final name in tester.widgetList<Text>(names)) {
        final rect = tester.getRect(find.text(name.data!));
        expect(rect.bottom, lessThanOrEqualTo(card.bottom), reason: '${name.data} sits whole inside the $side card');
      }
    }
    expect(tester.takeException(), isNull);
  });
}
