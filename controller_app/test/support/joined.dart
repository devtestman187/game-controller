import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'pump_app.dart';

/// The Arena a test's frames carry: one player in the middle of the field,
/// nothing in its way.
final arena = ArenaSnapshot(
  round: 1,
  roundTimeS: 30,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: const Rect.fromLTRB(0.9, 0.4, 1, 0.6),
  hazards: const [],
  players: const [ArenaPlayerView(id: 'phone-1', x: 0.5, y: 0.5)],
);

/// The start the host sends for [arena], at 60 frames a second.
ViewStartMessage arenaStart() =>
    ViewStartMessage(game: arenaModule.id, snapshotVersion: arenaModule.snapshotVersion, setup: arenaSetup, hz: 60);

/// Step [n] of [arena] at host time [atMs], with the sounds it fired.
FrameMessage arenaFrame(int n, {int atMs = 1000, List<String> sounds = const []}) =>
    FrameMessage(n: n, atMs: atMs, snapshot: arena.toJson(), sounds: sounds);

/// The opacity the controls are drawn with, over the game behind them.
double layerOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.ancestor(of: find.byKey(const Key('faceButtons')), matching: find.byType(Opacity)).first)
    .opacity;

/// The app connected to a host that shows the Arena, with a status panel up
/// and the first frame drawn.
Future<TestApp> joined(
  WidgetTester tester, {
  Size screen = const Size(852, 393),
  FakeViewPadding padding = const FakeViewPadding(),
}) async {
  final app = await pumpApp(tester, paired: true, screen: screen, padding: padding);
  app.client.emit(connected);
  app.client.setStatus(StatusMessage(text: 'Left 3/6'));
  await settle(tester);
  app.client.nowMs = 1000;
  app.client.viewStart(arenaStart());
  await settle(tester);
  app.client.viewFrame(arenaFrame(0));
  await settle(tester);
  return app;
}
