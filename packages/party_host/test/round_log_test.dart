import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// The log's lines, oldest first.
List<String> logLines(LogBuffer log) => [for (final line in log.lines) line.message];

/// Mounts the host with a log the test reads back, and, when given, the
/// app's "this phone went away" switch.
Future<(FakeHostService, LogBuffer)> pumpLogged(WidgetTester tester, {ValueNotifier<bool>? away}) async {
  final log = LogBuffer();
  final fake = await pumpHost(
    tester,
    screen: const StubHome(),
    overrides: [logProvider.overrideWithValue(log), if (away != null) hostAwayProvider.overrideWithValue(away)],
  );
  return (fake, log);
}

/// Home → Play → Shape Race → the house puzzle → P1 joins and starts.
Future<void> openSoloRound(WidgetTester tester, FakeHostService fake) async {
  await neutral(tester, fake, ['p1']);
  await openJoin(tester);
  await startRound(tester, fake);
  expect(find.byType(PuzzleScreen), findsOneWidget);
}

void main() {
  testWidgets('a round starting and ending goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    await openSoloRound(tester, fake);
    expect(logLines(log), contains('Round started: puzzle, solo, 1 player'));

    final match = lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Done!'), findsOneWidget);
    final time = match.result!.sides[PuzzleSide.left]!.timeS!.toStringAsFixed(1);
    expect(logLines(log), contains('Round ended: Done! ($time s)'));
  });

  testWidgets('a player leaving the results by back goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    await openSoloRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);

    await tester.tap(find.byKey(const Key('resultsBack')));
    await navigated(tester);
    expect(logLines(log), contains('Results: back to the games'));
  });

  testWidgets('a player leaving the results to play again goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    await openSoloRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);

    await tester.tap(find.byKey(const Key('playAgain')));
    await navigated(tester);
    expect(logLines(log), contains('Results: Play again'));
    expect(logLines(log).where((line) => line == 'Round started: puzzle, solo, 1 player'), hasLength(2));
  });

  // m12 bug 1108e: the log says what the first results button said.
  testWidgets('an any-puzzle round leaving the results for the next puzzle goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    await neutral(tester, fake, ['p1']);
    await openShapeRace(tester);
    await tester.tap(find.byKey(const Key('random-easy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await startRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Next puzzle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nextPuzzle')));
    await navigated(tester);
    expect(logLines(log), contains('Results: Next puzzle'));
  });

  testWidgets('a race leaving the results to rematch goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p2', GamepadButton.a);
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(logLines(log), contains('Round started: puzzle, 1v1, 2 players'));

    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Left wins!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rematch')));
    await navigated(tester);
    expect(logLines(log), contains('Results: Rematch'));
  });

  testWidgets('the round pausing and resuming from the menu goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    await openSoloRound(tester, fake);

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(logLines(log), contains('Round paused: P1 pressed Start'));

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(logLines(log), contains('Round resumed: the menu closed'));
  });

  testWidgets('the round pausing for the host being away goes in the host log', (tester) async {
    final away = ValueNotifier(false);
    final (fake, log) = await pumpLogged(tester, away: away);
    await openSoloRound(tester, fake);

    away.value = true;
    await tester.pump();
    expect(logLines(log), contains('Round paused: the host went away'));

    away.value = false;
    await tester.pump();
    expect(logLines(log), contains('Round resumed: the host is back'));
  });

  // m12 bug 1108g: the round had ended, so the host leaving paused nothing.
  testWidgets('the host leaving on the results goes in the host log as a host leaving, not a pause', (tester) async {
    final away = ValueNotifier(false);
    final (fake, log) = await pumpLogged(tester, away: away);
    await openSoloRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Done!'), findsOneWidget, reason: 'the round is over');

    away.value = true;
    await tester.pump();
    expect(logLines(log), contains('The host went away'));
    expect(logLines(log), isNot(contains('Round paused: the host went away')));

    away.value = false;
    await tester.pump();
    expect(logLines(log), contains('The host is back'));
    expect(logLines(log), isNot(contains('Round resumed: the host is back')));
  });

  // A menu holds the round already: the host leaving pauses nothing new.
  testWidgets('the host leaving with the pause menu open goes in the host log as a host leaving', (tester) async {
    final away = ValueNotifier(false);
    final (fake, log) = await pumpLogged(tester, away: away);
    await openSoloRound(tester, fake);
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    final before = logLines(log).length;

    away.value = true;
    await tester.pump();
    expect(logLines(log), contains('The host went away'));
    away.value = false;
    await tester.pump();
    expect(logLines(log), contains('The host is back'));
    expect(logLines(log).where((line) => line.contains('host')), hasLength(2), reason: 'no pause lines for it');
    expect(logLines(log).length, before + 2);
  });

  testWidgets('a player who is away and back goes in the host log', (tester) async {
    final (fake, log) = await pumpLogged(tester);
    await openSoloRound(tester, fake);

    fake.gameHost.away.add('p1');
    await tester.pump(const Duration(milliseconds: 16));
    expect(logLines(log), contains('P1 away: the round waits for them'));

    fake.gameHost.away.remove('p1');
    await tester.pump(const Duration(milliseconds: 16));
    expect(logLines(log), contains('P1 back: the round goes on'));
  });

  // m12 bug 1108g rule 1: the log says when the round stopped waiting, so it
  // never reads as a longer wait than it was.
  testWidgets('a phone that stays away past the grace goes in the host log when its slot ends, and its return '
      'later is only a return', (tester) async {
    final log = LogBuffer();
    final fake = await openRace(tester, overrides: [logProvider.overrideWithValue(log)]);
    await holdSlot(tester, fake, 'p2');
    await tester.pump(const Duration(milliseconds: 16));
    expect(logLines(log), contains('P2 away: the round waits for them'));

    // The host's grace timer ends the slot 30 s on: the round goes on without it.
    fake.gameHost.graceOver('p2');
    await tester.pump();
    final grace = FakeGameHost.grace.inSeconds;
    expect(logLines(log), contains('P2 didn\'t come back in $grace s: the round goes on without them'));
    expect(logLines(log).where((line) => line.startsWith('P2')), hasLength(2), reason: 'away, then the grace out');
    expect(find.byKey(const Key('awayCard')), findsNothing);

    // The phone comes back later in the same round: the round wasn't waiting
    // for it any more, so it is only back.
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await tester.pump(const Duration(milliseconds: 16));
    expect(logLines(log), contains('P2 back'));
    expect(logLines(log), isNot(contains('P2 back: the round goes on')));
  });

  testWidgets('Go on without them goes in the host log once', (tester) async {
    final log = LogBuffer();
    final fake = await openRace(tester, overrides: [logProvider.overrideWithValue(log)]);
    await holdSlot(tester, fake, 'p2');
    await tester.pump(const Duration(milliseconds: 16));
    expect(logLines(log), contains('P2 away: the round waits for them'));

    await tester.tap(find.byKey(const Key('goOnWithout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(logLines(log), contains('Go on without P2: the round goes on'));
    expect(logLines(log).where((line) => line.startsWith('Go on without')), hasLength(1));
    expect(
      logLines(log),
      isNot(
        contains(
          'P2 didn\'t come back in ${FakeGameHost.grace.inSeconds} s: '
          'the round goes on without them',
        ),
      ),
    );
    expect(find.byKey(const Key('awayCard')), findsNothing);
  });
}
