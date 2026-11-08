import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('the card names each away player and counts their grace down', (tester) async {
    final fake = await openRace(tester);
    final host = fake.gameHost;
    host.clockMs = 0;
    await holdSlot(tester, fake, 'p2');

    expect(find.byKey(const Key('awayCard')), findsOneWidget);
    expect(find.text('P2 is away'), findsOneWidget);
    expect(find.text('The game goes on if they\'re back in 30 s'), findsOneWidget);

    // Six seconds of the host's clock: 30 − 6 = 24 to go.
    host.clockMs = 6000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The game goes on if they\'re back in 24 s'), findsOneWidget);

    // The grace is over: the slot is due to end.
    host.clockMs = 30000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The game goes on without them…'), findsOneWidget);
  });

  testWidgets('two away players get a line each', (tester) async {
    final fake = await openRace(tester);
    fake.state = withController(fake.state, phoneInfo('p3', 3));
    fake.emit();
    await tester.pump();
    await neutral(tester, fake, ['p3']);

    await holdSlot(tester, fake, 'p2');
    fake.gameHost.setAway('p3', isAway: true);
    await tester.pump();
    expect(find.text('P2 is away'), findsOneWidget);
    expect(find.text('P3 is away'), findsOneWidget);
    expect(find.textContaining('back in 30 s'), findsNWidgets(2));
  });

  testWidgets('Go on without them ends every away slot and the round goes on', (tester) async {
    final fake = await openRace(tester);
    final host = fake.gameHost;
    await holdSlot(tester, fake, 'p2');
    final stopped = timeLeftMs(tester);
    expect(focused(tester, 'goOnWithout'), isTrue, reason: 'the remote\'s OK lands on Go on without them');

    // The phone the round waits for works nothing: it isn't here.
    await neutral(tester, fake, ['p2']);
    await press(tester, fake, 'p2', GamepadButton.a);
    await tester.pump();
    expect(host.goOnWithouts, isEmpty);

    // A phone that is here works the card like the remote: A presses the
    // focused button, Go on without them.
    await neutral(tester, fake, ['p1']);
    await press(tester, fake, 'p1', GamepadButton.a);
    await tester.pump();
    expect(host.goOnWithouts, ['p2']);
    expect(find.byKey(const Key('awayCard')), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), lessThan(stopped), reason: 'the round goes on without them');
  });

  testWidgets('B on a phone and the remote\'s Back leave the round where it waits', (tester) async {
    final fake = await openRace(tester);
    final host = fake.gameHost;
    await holdSlot(tester, fake, 'p2');
    final stopped = timeLeftMs(tester);
    // The card gives the phones A and the arrows, and no Back: a menu tick
    // after it claims them.
    await tester.pump(const Duration(milliseconds: 16));
    expect(host.layouts['p1']!.labels, {ControllerButton.a: 'OK'});
    expect(host.layouts['p1']!.hidden, contains(ControllerButton.b));

    // A phone that is here presses B: nothing pops the round.
    await neutral(tester, fake, ['p1']);
    await press(tester, fake, 'p1', GamepadButton.b);
    await tester.pump();
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget, reason: 'B never leaves a round that waits');
    expect(host.viewEnds, isEmpty, reason: 'and nothing ends it');

    // The remote's Back (the system back) does nothing either.
    await tester.binding.handlePopRoute();
    await navigated(tester);
    expect(find.byKey(const Key('awayCard')), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(host.viewEnds, isEmpty);
    expect(timeLeftMs(tester), stopped, reason: 'the round is still where it waited');
  });

  testWidgets('End round is the menu Quit: the game picker, the round quit', (tester) async {
    final fake = await openRace(tester);
    await holdSlot(tester, fake, 'p2');

    await tester.tap(find.byKey(const Key('awayEndRound')));
    await navigated(tester);
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsNothing);
    expect(fake.gameHost.viewEnds.last.reason, ViewEndReason.quit);
  });

  testWidgets('the results show no card: no round runs to wait for one', (tester) async {
    final fake = await openRace(tester);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Left wins!'), findsOneWidget);

    fake.gameHost.setAway('p2', isAway: true);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('awayCard')), findsNothing);
  });
}
