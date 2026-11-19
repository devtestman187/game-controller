import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The round's number and clock on the joined phone's top strip (M16 item 1,
/// mock-up frame 0 of docs/briefs/m16/ux-review/mockups/proposal-mockups.html).
void main() {
  /// The view a host that names its round sends: round 1 of 3 unless told
  /// otherwise.
  ViewStartMessage roundStart({int round = 1, int? rounds = 3}) => ViewStartMessage(
    game: arenaModule.id,
    snapshotVersion: arenaModule.snapshotVersion,
    setup: arenaSetup,
    hz: 60,
    round: round,
    rounds: rounds,
  );

  /// One frame of that round, with [timeLeftMs] left on its clock.
  FrameMessage roundFrame({required int timeLeftMs}) =>
      FrameMessage(n: 1, atMs: 2000, snapshot: arena.toJson(), timeLeftMs: timeLeftMs);

  testWidgets('the strip shows the round and its clock, and clears when the view ends', (tester) async {
    // The default 852 × 393 landscape phone, the size the mock-up draws (816 × 384).
    final app = await pumpApp(tester, paired: true);
    app.client.emit(connected);
    await settle(tester);
    expect(find.byKey(const Key('roundStrip')), findsNothing, reason: 'no game is shown');

    app.client.nowMs = 1000;
    app.client.viewStart(roundStart());
    await settle(tester);
    expect(find.byKey(const Key('roundStrip')), findsOneWidget);
    expect(find.text('Round 1 of 3'), findsOneWidget);
    expect(find.text('0:42'), findsNothing, reason: 'the start carries no clock: the frames do');

    app.client.viewFrame(roundFrame(timeLeftMs: 42000));
    await settle(tester);
    expect(find.text('0:42'), findsOneWidget, reason: '42 s as m:ss');

    app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
    await settle(tester);
    expect(find.byKey(const Key('roundStrip')), findsNothing);
    expect(find.text('Round 1 of 3'), findsNothing);
    expect(find.text('0:42'), findsNothing);
  });

  testWidgets('a host that names no series says just its round', (tester) async {
    final app = await pumpApp(tester, paired: true);
    app.client.emit(connected);
    await settle(tester);

    app.client.nowMs = 1000;
    app.client.viewStart(roundStart(round: 2, rounds: null));
    await settle(tester);
    expect(find.text('Round 2'), findsOneWidget);
  });
}
