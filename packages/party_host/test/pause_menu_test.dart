import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('the round waits while a phone is away, and goes on from where it stopped', (tester) async {
    final fake = await openRace(tester);
    final host = fake.gameHost;
    await holdSlot(tester, fake, 'p2');
    expect(find.byKey(const Key('awayCard')), findsOneWidget);
    final stopped = timeLeftMs(tester);

    // A second of real frames: the clock stands still for everyone.
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), stopped);

    host.setAway('p2', isAway: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final went = stopped - timeLeftMs(tester);
    expect(went, greaterThan(0), reason: 'the clock goes on when the phone is back');
    expect(went, lessThan(200), reason: 'it goes on from where it stopped, without catching the pause up');
    expect(find.byKey(const Key('awayCard')), findsNothing);
  });

  testWidgets('the round goes on at once when the away phone\'s grace runs out', (tester) async {
    final fake = await openRace(tester);
    await holdSlot(tester, fake, 'p2');
    final stopped = timeLeftMs(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), stopped);

    // The host's grace timer ends the slot: the phone leaves the roster.
    fake.removeController('p2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('awayCard')), findsNothing);
    expect(timeLeftMs(tester), lessThan(stopped), reason: 'the round goes on without them, with no press');
  });

  testWidgets('the Arena waits for an away phone too', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final host = fake.gameHost;
    // A viewer would get the round's frames: none come while it waits.
    host.hasViewers = true;
    await neutral(tester, fake, ['p1']);
    await openArena(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(host.frames, isNotEmpty, reason: 'the round sends frames while it runs');

    host.setAway('p1', isAway: true);
    await tester.pump();
    await tester.pump();
    final sent = host.frames.length;
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(host.frames, hasLength(sent), reason: 'nothing steps while the round waits');

    host.setAway('p1', isAway: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(host.frames.length, greaterThan(sent));
  });

  testWidgets('Start opens no menu while the round waits for an away phone', (tester) async {
    final fake = await openRace(tester);
    await holdSlot(tester, fake, 'p2');

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(find.byKey(const Key('awayCard')), findsOneWidget);
  });

  testWidgets('an away phone gets no menu and cannot work one', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(find.byType(GamesScreen), findsOneWidget);

    fake.gameHost.setAway('p1', isAway: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // A on the phone that is away presses nothing: the menus skip it.
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(ShapeRaceScreen), findsNothing);
  });

  testWidgets('the host going away and a phone away pause the round once', (tester) async {
    final appAway = ValueNotifier(false);
    final log = LogBuffer();
    final fake = await openRace(
      tester,
      overrides: [hostAwayProvider.overrideWithValue(appAway), logProvider.overrideWithValue(log)],
    );
    await holdSlot(tester, fake, 'p2');
    final stopped = timeLeftMs(tester);
    expect(find.byKey(const Key('awayCard')), findsOneWidget);

    appAway.value = true;
    await tester.pump();
    expect(find.byKey(const Key('awayCard')), findsNothing, reason: 'the host\'s own pause wins while the app is away');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), stopped);

    appAway.value = false;
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('awayCard')), findsOneWidget, reason: 'a phone is still away');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), stopped);

    // One pause, described by the host's own line; the away line is once.
    final lines = [for (final line in log.lines) line.message];
    expect(lines.where((l) => l.startsWith('Round paused:')), ['Round paused: the host went away']);
    expect(lines.where((l) => l == 'P2 away: the round waits for them'), hasLength(1));
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

  testWidgets('the round\'s phase is none on the menus and playing in a round, and after Resume', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final container = ProviderScope.containerOf(tester.element(find.byType(StubHome)));
    RoundPhase phase() => container.read(roundPhaseProvider).value;

    // No round is on: the home screen, the game picker and the join screen.
    expect(phase(), RoundPhase.none);
    await neutral(tester, fake, ['p1']);
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(phase(), RoundPhase.none, reason: 'the picker is no round');
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(phase(), RoundPhase.none, reason: 'the join screen is no round');

    // The round runs, and a pause menu stands it still.
    await startRound(tester, fake);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(phase(), RoundPhase.playing);
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(phase(), RoundPhase.none, reason: 'the menu is no round');
    await press(tester, fake, 'p1', GamepadButton.a);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(phase(), RoundPhase.playing, reason: 'Resume starts the round again');

    // The results end it.
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Done!'), findsOneWidget);
    expect(phase(), RoundPhase.none, reason: 'the results are no round');

    // Play again replaces the screen before the results are disposed (M10):
    // the new round's phase is the one that stands.
    await tester.tap(find.byKey(const Key('playAgain')));
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(phase(), RoundPhase.playing, reason: 'the new round runs');
  });

  testWidgets('a round that waits for a phone away or for the host is none', (tester) async {
    final appAway = ValueNotifier(false);
    final fake = await openRace(tester, overrides: [hostAwayProvider.overrideWithValue(appAway)]);
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleScreen)));
    RoundPhase phase() => container.read(roundPhaseProvider).value;
    expect(phase(), RoundPhase.playing);

    // The away card stands the round still (m12 bug 1107d).
    await holdSlot(tester, fake, 'p2');
    expect(find.byKey(const Key('awayCard')), findsOneWidget);
    expect(phase(), RoundPhase.none);
    fake.gameHost.setAway('p2', isAway: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(phase(), RoundPhase.playing, reason: 'the phone is back and the round goes on');

    // So does the host app going away (m12 §2.10).
    appAway.value = true;
    await tester.pump();
    expect(phase(), RoundPhase.none);
    appAway.value = false;
    await tester.pump();
    await tester.pump();
    expect(phase(), RoundPhase.playing);
  });
}
