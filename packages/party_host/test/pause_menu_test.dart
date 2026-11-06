import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('Start pauses for everyone; only the player who paused or Player 1 can resume; Quit goes to the '
      'game picker', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    // P1 on the left, P2 on the right, then Start on P1's phone.
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p2', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(find.byType(JoinScreen), findsNothing);

    // P2 pauses: the menu shows, and the phones offer Resume.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(host.layouts['p2']!.labels[ControllerButton.start], 'Resume');
    expect(find.text('P2 or P1 can resume, with Start or Resume.'), findsOneWidget);

    // The clock stops for everyone.
    int timeLeft() => tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).snapshot.boards.first.timeLeftMs;
    final before = timeLeft();
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeft(), before);

    // A phone that hasn't joined can't work the menu.
    fake.state = withController(fake.state, phoneInfo('p3', 3));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['p3']);
    await press(tester, fake, 'p3', GamepadButton.start);
    await press(tester, fake, 'p3', GamepadButton.a);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    // The player who paused resumes with Start.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);

    // P2 pauses again, and P1 resumes with A on Resume.
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);

    // P1 pauses: now P2 can't resume any more.
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(find.text('P1 can resume, with Start or Resume.'), findsOneWidget);
    await press(tester, fake, 'p2', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);

    // Left to Quit, and A quits to the game picker.
    await press(tester, fake, 'p1', GamepadButton.dpadLeft);
    expect(focused(tester, 'pauseQuit'), isTrue);
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsNothing);
  });

  testWidgets('the Arena pauses with Start too', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
    await neutral(tester, fake, ['p1']);
    await openArena(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.start], 'Pause');

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(host.layouts['p1']!.labels[ControllerButton.start], 'Resume');

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(host.layouts['p1']!.labels[ControllerButton.start], 'Pause');
  });
}
