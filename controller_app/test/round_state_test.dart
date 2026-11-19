import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('the strip shows this phone\'s coins and its place, from the frame', (tester) async {
    final app = await pumpApp(tester, paired: true);
    app.client.emit(connected);
    await settle(tester);

    // This phone's player, as the host names it: a Bumper Round frame where a
    // rival holds more coins, so the phone is second.
    final container = ProviderScope.containerOf(tester.element(find.byType(ControlsLayer)));
    final me = container.read(identityProvider).controllerId;
    final frame = ArenaSnapshot(
      round: 1,
      roundTimeS: 30,
      phase: ArenaPhase.playing,
      walls: const [],
      goal: Rect.zero,
      hazards: const [],
      players: [
        const ArenaPlayerView(id: 'rival', x: 0.5, y: 0.5, coins: 7),
        ArenaPlayerView(id: me, x: 0.5, y: 0.5, coins: 4),
        const ArenaPlayerView(id: 'third', x: 0.5, y: 0.5, coins: 1),
      ],
      mode: ArenaMode.bumper,
      timeLeftMs: 42000,
    );

    app.client.nowMs = 1000;
    app.client.viewStart(roundStart());
    await settle(tester);
    app.client.viewFrame(FrameMessage(n: 1, atMs: 2000, snapshot: frame.toJson(), timeLeftMs: 42000));
    await settle(tester);

    expect(find.byKey(const Key('roundCoins')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('roundCoins'))).data, '4');
    expect(find.byKey(const Key('roundPlace')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('roundPlace'))).data, '2nd');
  });
}
