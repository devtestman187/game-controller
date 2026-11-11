import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('the phone alone works the menus: the game picker, Shape Race, Puzzle settings and back home', (
    tester,
  ) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
    // The sample phone starts holding A and right: let it go first.
    await neutral(tester, fake, ['p1']);
    // In the menus the phone says A "OK", B "Back".
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'OK');
    expect(host.layouts['p1']!.labels[ControllerButton.b], 'Back');

    // Play has the focus, so A on the phone opens the game picker.
    Focus.of(tester.element(focusText('openPlay'))).requestFocus();
    await tester.pump();
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(StubHome), findsNothing);

    // The party night's card has the focus on the picker, so A opens the
    // night's start card (M14 c1); B goes back.
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(NightStartScreen), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(NightStartScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);

    // Left walks the cards from the night's to Shape Race: A opens it.
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    expect(focused(tester, 'pickShapeRace'), isTrue, reason: 'left reaches Shape Race\'s card');
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
    // B goes back to the picker.
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);

    // The arrows reach Puzzle settings.
    for (var i = 0; i < 3 && !focused(tester, 'openPuzzleSettings'); i++) {
      await press(tester, fake, 'p1', GamepadButton.dpadDown);
    }
    expect(focused(tester, 'openPuzzleSettings'), isTrue, reason: 'down reaches the settings button');
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(PuzzleSettingsScreen), findsOneWidget);
    // The first − has the focus; right reaches the value's +.
    expect(focusedTooltip(), 'Less Angle tolerance');
    for (var i = 0; i < 3 && !(focusedTooltip()?.startsWith('More') ?? false); i++) {
      await press(tester, fake, 'p1', GamepadButton.dpadRight);
    }
    expect(focusedTooltip(), startsWith('More'));
    await press(tester, fake, 'p1', GamepadButton.a);
    await tester.pump();
    expect(find.text('±16°'), findsOneWidget);

    // B twice: the settings, then the picker, back to the main screen.
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(PuzzleSettingsScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsNothing);
    expect(find.byType(StubHome), findsOneWidget);
  });

  testWidgets('a held direction repeats, and the focus never ends up where A cannot press', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('openPuzzleSettings')));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleSettingsScreen), findsOneWidget);

    /// The settings row whose button has the focus ("Less Angle tolerance"
    /// → "Angle tolerance").
    String? row() => focusedTooltip()?.split(' ').skip(1).join(' ');

    final start = row();
    expect(start, 'Angle tolerance');
    await phone(tester, fake, 'p1', {GamepadButton.dpadDown});
    final once = row();
    expect(once, isNot(start), reason: 'a press moves the focus');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(row(), once, reason: 'a held direction waits before it repeats');

    // Still held for a second more: the focus keeps moving down the list.
    final rows = <String>{?start, ?once};
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final r = row();
      if (r != null) rows.add(r);
    }
    expect(rows.length, greaterThanOrEqualTo(3), reason: 'the held direction kept moving: $rows');

    // A direction never leaves the focus where A cannot press.
    await phone(tester, fake, 'p1', {});
    const directions = [GamepadButton.dpadUp, GamepadButton.dpadDown, GamepadButton.dpadLeft, GamepadButton.dpadRight];
    for (var i = 0; i < 8; i++) {
      await press(tester, fake, 'p1', directions[i % directions.length]);
      final context = FocusManager.instance.primaryFocus?.context;
      expect(context, isNotNull, reason: 'after ${directions[i % directions.length].name}');
      expect(
        Actions.maybeFind<ActivateIntent>(context!),
        isNotNull,
        reason: 'the focus after ${directions[i % directions.length].name} must be pressable',
      );
    }
  });

  testWidgets('the D-pad reaches Shape Race\'s Best times button, and B comes back from the board', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    expect(find.byType(ShapeRaceScreen), findsOneWidget);

    // The first level's button opens the pick, so down walks from it to the
    // button under the levels (M14 f1, r5 finding 4).
    for (var i = 0; i < 8 && !focused(tester, 'openBestTimes'); i++) {
      await press(tester, fake, 'p1', GamepadButton.dpadDown);
    }
    expect(focused(tester, 'openBestTimes'), isTrue, reason: 'down reaches the Best times button');

    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(BestTimesScreen), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(BestTimesScreen), findsNothing);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
  });

  testWidgets('simulated controllers never work the menus', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
    await neutral(tester, fake, ['p1']);
    fake.state = withController(fake.state, phoneInfo('sim1', 2, platform: 'sim'));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['sim1']);
    expect(host.players.map((p) => (p.id, p.simulated)), [('p1', false), ('sim1', true)]);

    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(find.byType(GamesScreen), findsOneWidget);
    // B back and A on the Simulated controller's phone: nothing happens.
    await press(tester, fake, 'sim1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    await press(tester, fake, 'sim1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(ShapeRaceScreen), findsNothing);
    expect(find.byType(PuzzleSettingsScreen), findsNothing);
    // It never gets the menu's buttons either.
    expect(host.layouts['sim1']?.labels[ControllerButton.a], isNot('OK'));
  });
}
