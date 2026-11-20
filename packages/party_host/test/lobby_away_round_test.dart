import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// A round waits only for the away phones it seats (M16 item 2): a lobby slot
/// of a player the round doesn't have keeps the player's place for 30 s, but
/// pauses nothing.
void main() {
  testWidgets('a lobby away-slot of a player the round does not seat does not pause it', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);

    // P2 drops on the join screen: the host holds its slot for the grace.
    await holdSlot(tester, fake, 'p2');
    // P1 joins the left side and starts a round on its own within the grace.
    await startRound(tester, fake);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('awayCard')), findsNothing, reason: 'P2 is in no side of this round');
    final before = timeLeftMs(tester);
    // 2 s of frames: the round's clock runs, and does not wait for P2.
    for (var i = 0; i < 125; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(before - timeLeftMs(tester), 2000);
  });

  testWidgets('a player the round seats who drops mid-round still pauses it', (tester) async {
    final fake = await openRace(tester);
    // P2 is on the race's right side: its phone drops mid-round.
    await holdSlot(tester, fake, 'p2');
    expect(find.byKey(const Key('awayCard')), findsOneWidget);
    expect(find.text('Player 2 is away'), findsOneWidget);
    final stopped = timeLeftMs(tester);
    for (var i = 0; i < 125; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), stopped, reason: 'the round waits for its own player');
  });

  testWidgets('the results can be left while a lobby away-slot is held', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await holdSlot(tester, fake, 'p2');
    await startRound(tester, fake);
    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.text('Done!'), findsOneWidget);

    // Back on the results goes to the game picker: nothing waits on the round.
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsNothing);
  });
}
