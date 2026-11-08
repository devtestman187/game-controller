import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// A text inside one side's panel.
Finder sideText(String side, String text) =>
    find.descendant(of: find.byKey(Key('side-$side')), matching: find.text(text));

void main() {
  testWidgets('players join a side first; the puzzle gives the phone Pick up and Rotate, and the panel; '
      'leaving gives the menu buttons back', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
    await openShapeRace(tester);
    // In the menus the phone says A "OK", B "Back".
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'OK');
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'Join');

    await phone(tester, fake, 'p1', {});
    await phone(tester, fake, 'p1', {GamepadButton.a});
    await phone(tester, fake, 'p1', {});
    expect(find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 iPhone 3F1C')), findsOne);
    expect(find.text('1 player. Press A or Start to begin.'), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.a], 'Start', reason: 'once joined, A begins');
    // A again begins (Start does too: tested in the pause menu tests).
    await phone(tester, fake, 'p1', {GamepadButton.a});
    await phone(tester, fake, 'p1', {});
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.byKey(const Key('puzzleView')), findsOneWidget);
    final layout = fake.gameHost.layouts['p1']!;
    expect(layout.labels[ControllerButton.a], 'Pick up');
    expect(layout.labels[ControllerButton.x], startsWith('Rotate'));
    expect(layout.hidden, contains(ControllerButton.b));
    expect(fake.gameHost.statuses['p1']!.progress, isNotNull);
    expect(layout.labels[ControllerButton.start], 'Pause');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The menus take the buttons back on their next look, once the screen's gone.
    await tester.pump(const Duration(milliseconds: 16));
    expect(fake.gameHost.layouts['p1']!.labels[ControllerButton.a], 'OK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on the join screen A joins the side with fewer players, left and right switch sides, B leaves, '
      'at most two a side', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p3', 2));
    fake.state = withController(fake.state, phoneInfo('p4', 3));
    fake.state = withController(fake.state, phoneInfo('p5', 4));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p3', 'p4', 'p5']);
    await openJoin(tester);
    expect(find.byType(JoinScreen), findsOneWidget);

    Finder onSide(String side, String label) =>
        find.descendant(of: find.byKey(Key('side-$side')), matching: find.text(label));

    // The first player goes left, the next right, then left, then right.
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);
    await press(tester, fake, 'p3', GamepadButton.a);
    expect(onSide('right', 'P2 Phone 2'), findsOneWidget);
    await press(tester, fake, 'p4', GamepadButton.a);
    expect(onSide('left', 'P3 Phone 3'), findsOneWidget);
    // Two against one while three have joined.
    expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('2 vs 1'));
    await press(tester, fake, 'p5', GamepadButton.a);
    expect(onSide('right', 'P4 Phone 4'), findsOneWidget);

    // The right side is full: pushing right keeps player 1 on the left.
    await press(tester, fake, 'p1', GamepadButton.dpadRight);
    expect(onSide('left', 'P1 iPhone 3F1C'), findsOneWidget);

    // B leaves a side; again, not joined, it goes back.
    await press(tester, fake, 'p3', GamepadButton.b);
    expect(onSide('right', 'P2 Phone 2'), findsNothing);
    expect(find.byType(JoinScreen), findsOneWidget);
    await press(tester, fake, 'p3', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(JoinScreen), findsNothing);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
  });

  testWidgets('Start begins the match with the teams; simulated controllers join by themselves', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 iPhone 3F1C')), findsOne);

    // The simulated controller joins the side with fewer players by itself.
    fake.state = withController(fake.state, phoneInfo('sim1', 2, platform: 'sim'));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['sim1']);
    expect(
      find.descendant(of: find.byKey(const Key('side-right')), matching: find.text('P2 Phone 2 (simulated)')),
      findsOne,
    );

    // Start on player 1's phone begins the match: two sides, the split screen.
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.byType(MatchView), findsOneWidget);
    expect(tester.widget<CustomPaint>(find.byKey(const Key('puzzleView'))).painter, isA<MatchPainter>());
  });

  group('the host phone\'s own player (m12-host-touch rule 5)', () {
    /// The join screen with this host's own player: the phone app overrides
    /// [ownPlayerIdProvider] with its own player's ID.
    Future<FakeHostService> openOwnJoin(WidgetTester tester) async {
      final fake = await pumpHost(
        tester,
        screen: const StubHome(),
        overrides: [ownPlayerIdProvider.overrideWithValue('p1')],
      );
      // "Play on this phone" shares the view; only then does the own player play.
      fake.shareView = true;
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      return fake;
    }

    testWidgets('the own player is on the left on entry, marked, and Start begins the match', (tester) async {
      await openOwnJoin(tester);
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);
      expect(sideText('right', 'P1 iPhone 3F1C (you)'), findsNothing);
      expect(find.byKey(const Key('notJoined')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('1 player'));
      // The hint is the host phone's: tapping is the way in, and a phone that
      // joins uses A (rule 5).
      expect(find.text('Tap a side to play; press A on a phone to join.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('joinStart')));
      await navigated(tester);
      expect(find.byType(PuzzleScreen), findsOneWidget);
    });

    testWidgets('a tap on a side moves only the own player there, and the format follows', (tester) async {
      final fake = await pumpHost(
        tester,
        screen: const StubHome(),
        overrides: [ownPlayerIdProvider.overrideWithValue('p1')],
      );
      // "Play on this phone" shares the view; only then does the own player play.
      fake.shareView = true;
      fake.state = withController(fake.state, phoneInfo('p3', 2));
      fake.emit();
      await neutral(tester, fake, ['p1', 'p3']);
      await openJoin(tester);
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);

      // The other phone joins the right side with A: one against one.
      await press(tester, fake, 'p3', GamepadButton.a);
      expect(sideText('right', 'P2 Phone 2'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('1 vs 1'));

      // A tap on the right moves the own player alone: the phone that joined
      // with A stays, and the two on one side make a team.
      await tester.tap(find.byKey(const Key('side-right')));
      await tester.pump();
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsNothing);
      expect(sideText('right', 'P1 iPhone 3F1C (you)'), findsOneWidget);
      expect(sideText('right', 'P2 Phone 2'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('A team of 2 on one board'));
    });

    testWidgets('a full side refuses the own player\'s tap', (tester) async {
      final fake = await pumpHost(
        tester,
        screen: const StubHome(),
        overrides: [ownPlayerIdProvider.overrideWithValue('p1')],
      );
      // "Play on this phone" shares the view; only then does the own player play.
      fake.shareView = true;
      fake.state = withController(fake.state, phoneInfo('p3', 2));
      fake.state = withController(fake.state, phoneInfo('p4', 3));
      fake.state = withController(fake.state, phoneInfo('p5', 4));
      fake.emit();
      await neutral(tester, fake, ['p1', 'p3', 'p4', 'p5']);
      await openJoin(tester);
      // The own player is on the left; the other three join (right, left,
      // right) and fill both sides.
      await press(tester, fake, 'p3', GamepadButton.a);
      await press(tester, fake, 'p4', GamepadButton.a);
      await press(tester, fake, 'p5', GamepadButton.a);
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);
      expect(sideText('left', 'P3 Phone 3'), findsOneWidget);
      expect(sideText('right', 'P2 Phone 2'), findsOneWidget);
      expect(sideText('right', 'P4 Phone 4'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('2 vs 2'));

      await tester.tap(find.byKey(const Key('side-right')));
      await tester.pump();
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);
      expect(sideText('right', 'P1 iPhone 3F1C (you)'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('2 vs 2'));
    });

    testWidgets('"Show on this device": the own player never takes a side', (tester) async {
      final fake = await pumpHost(
        tester,
        screen: const StubHome(),
        overrides: [ownPlayerIdProvider.overrideWithValue('p1')],
      );
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsNothing);
      expect(find.text('Nobody has joined yet.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('side-left')));
      await tester.pump();
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsNothing, reason: 'the phone is the screen, not a player');
    });

    testWidgets('without an own player the sides are not tappable and the hint is unchanged', (tester) async {
      final fake = await pumpHost(tester, screen: const StubHome());
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      await press(tester, fake, 'p1', GamepadButton.a);
      expect(sideText('left', 'P1 iPhone 3F1C'), findsOneWidget);
      expect(
        find.text('Press A on your phone to join, then left or right to pick a side. Then A or Start begins.'),
        findsOneWidget,
      );

      // A TV has nobody to move: a tap on a side does nothing.
      await tester.tap(find.byKey(const Key('side-right')));
      await tester.pump();
      expect(sideText('left', 'P1 iPhone 3F1C'), findsOneWidget);
      expect(sideText('right', 'P1 iPhone 3F1C'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('joinFormat'))).data, startsWith('1 player'));
    });

    testWidgets('the own player back from away joins a side again', (tester) async {
      final fake = await openOwnJoin(tester);
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);

      // Away: the join screen drops its side (m12 bug 1107d).
      fake.gameHost.setAway('p1', isAway: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsNothing);
      expect(find.text('Nobody has joined yet.'), findsOneWidget);

      // Back: it takes a side by itself again.
      fake.gameHost.setAway('p1', isAway: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);
    });
  });

  // m12 bug 1108c: the owner read "press A or start to begin" on a phone that
  // has no pad. The line says what begins the match on this host.
  group('the status line says what begins the match (m12 bug 1108c)', () {
    String formatLine(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('joinFormat'))).data!;

    testWidgets('a TV host keeps "Press A or Start to begin"', (tester) async {
      final fake = await pumpHost(tester, screen: const StubHome());
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      await press(tester, fake, 'p1', GamepadButton.a);
      expect(formatLine(tester), '1 player. Press A or Start to begin.');
    });

    testWidgets('a touch-first host that plays here says "Tap Start to begin"', (tester) async {
      final fake = await pumpHost(
        tester,
        screen: const StubHome(),
        overrides: [ownPlayerIdProvider.overrideWithValue('p1'), hostTouchFirstProvider.overrideWithValue(true)],
      );
      // "Play on this phone" shares the view, so the own player is in the match.
      fake.shareView = true;
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      expect(sideText('left', 'P1 iPhone 3F1C (you)'), findsOneWidget);
      expect(formatLine(tester), '1 player. Tap Start to begin.');
    });

    testWidgets('a touch-first host that only shows the game says "Tap Start, or press A on a phone"', (tester) async {
      final fake = await pumpHost(
        tester,
        screen: const StubHome(),
        overrides: [hostTouchFirstProvider.overrideWithValue(true)],
      );
      await neutral(tester, fake, ['p1']);
      await openJoin(tester);
      // A joined phone takes a side; this screen has no player of its own.
      await press(tester, fake, 'p1', GamepadButton.a);
      expect(sideText('left', 'P1 iPhone 3F1C'), findsOneWidget);
      expect(formatLine(tester), '1 player. Tap Start, or press A on a phone, to begin.');
    });
  });

  // m11.1 device test: P1 joined, P2 hadn't, and P2's Start began a match for
  // P1 alone, which then paused.
  testWidgets('only a player who joined begins the match; someone watching can\'t pause; '
      'the Start that began the match doesn\'t pause it', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await press(tester, fake, 'p1', GamepadButton.a);
    // P2 hasn't joined: Start does nothing, and the phone still says Join.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsNothing);
    expect(fake.gameHost.layouts['p2']!.labels[ControllerButton.a], 'Join');

    // P1 begins with Start and keeps pressing it at once: no pause yet.
    await phone(tester, fake, 'p1', {GamepadButton.start});
    await tester.pump();
    expect(find.byType(PuzzleScreen), findsOneWidget);
    await phone(tester, fake, 'p1', {});
    await press(tester, fake, 'p1', GamepadButton.start);
    await tester.pump();
    expect(find.byKey(const Key('pauseMenu')), findsNothing, reason: 'Start in the first half second');
    await navigated(tester);
    // P2 is only watching: Start doesn't pause.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing, reason: 'P2 is watching');
    // P1, in the game, can.
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
  });
}
