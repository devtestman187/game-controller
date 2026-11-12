import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The Bumper Round the host sends this phone: its own player holds 4 coins,
/// the other player 2, with 42 s left.
final bumper = ArenaSnapshot(
  round: 1,
  roundTimeS: 18,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: const [
    ArenaPlayerView(id: 'test', x: 0.4, y: 0.5, coins: 4),
    ArenaPlayerView(id: 'other', x: 0.6, y: 0.5, coins: 2),
  ],
  mapId: 'test',
  mode: ArenaMode.bumper,
  timeLeftMs: 42000,
);

/// A frame of [bumper] at frame [n], with the roster the viewer draws: the
/// phone's clock is 1000 ms, as the joined harness sets it, so it draws at
/// once.
FrameMessage frame(int n) => FrameMessage(
  n: n,
  atMs: 1000,
  snapshot: bumper.toJson(),
  roster: const {'test': (number: 1, name: 'Ada'), 'other': (number: 2, name: 'Bo')},
);

void main() {
  // Claude's design for M14 b2: a joined phone shows its own player's coins in
  // its arena view, in the bar the phone already draws.
  testWidgets("a joined phone shows its own player's coin count in the arena's bar", (tester) async {
    // The joined harness's view starts on the race: start the Bumper Round's
    // own view, then the first frame the phone draws.
    final app = await joined(tester);
    app.client.nowMs = 1000;
    app.client.viewStart(arenaStart());
    await settle(tester);
    app.client.viewFrame(frame(0));
    await settle(tester);

    expect(find.byKey(const Key('coins-test')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('coins-test'))).data, '4');
    expect(tester.widget<Text>(find.byKey(const Key('coins-other'))).data, '2');
    final own = tester.getRect(find.byKey(const Key('coins-test')));
    expect(own.left, greaterThanOrEqualTo(0));
    expect(own.right, lessThanOrEqualTo(852), reason: "the phone's own count is on its screen");
    expect(tester.widget<Text>(find.byKey(const Key('roundTime'))).data, '42.0 s', reason: 'the clock counts down');
  });
}
