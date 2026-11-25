import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/look.dart';

/// The players these tests draw: two phones, numbered in the order they joined.
const two = {'a': (number: 1, name: 'Ada'), 'b': (number: 2, name: 'Bo')};

/// The frame at [round] in [mode], with [timeLeftMs] left on its clock
/// (null for a race, which has none).
ArenaSnapshot bumperFrame({required int round, int? timeLeftMs, ArenaMode mode = ArenaMode.bumper}) => ArenaSnapshot(
  round: round,
  roundTimeS: 43.4,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: Rect.zero,
  hazards: const [],
  players: [
    for (final MapEntry(key: id, value: player) in two.entries)
      ArenaPlayerView(id: id, x: 0.15 + 0.15 * player.number, y: 0.5),
  ],
  mapId: 'test',
  mode: mode,
  timeLeftMs: timeLeftMs,
);

/// The TV's look: Sunny drawn for the big screen, beside the phone's [sunny].
final tvLook = ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// The HUD drawn in [look] in a box of 960 by 540 (the TV's size), with the
/// round's [round] and [rounds] when the match names them.
Future<void> pumpHud(
  WidgetTester tester,
  ArenaSnapshot snapshot, {
  required ToyLook look,
  int? round,
  int? rounds,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Scaffold(
          body: ArenaHud(snapshot: snapshot, roster: two, round: round, rounds: rounds),
        ),
        look: look,
      ),
    ),
  );
}

/// The colour of the round's clock text.
Color? clockColor(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('roundTime'))).style?.color;

/// The colour of the round's best-time text, which starts with "Best".
Color? bestColor(WidgetTester tester) => tester.widget<Text>(find.textContaining('Best')).style?.color;

void main() {
  testWidgets('the round reads Round N of M when the match names its rounds, on both looks', (tester) async {
    for (final look in [sunny, tvLook]) {
      await pumpHud(tester, bumperFrame(round: 2, timeLeftMs: 30000), look: look, round: 2, rounds: 3);
      expect(find.text('Round 2 of 3'), findsOneWidget, reason: 'the night\'s second of three');
      expect(find.text('Round 2'), findsNothing, reason: 'the bare form is for a match with no count');
    }
  });

  testWidgets('with no rounds named the round reads Round N, as it does today', (tester) async {
    for (final look in [sunny, tvLook]) {
      await pumpHud(tester, bumperFrame(round: 2, timeLeftMs: 30000), look: look);
      expect(find.text('Round 2'), findsOneWidget);
      expect(find.textContaining(' of '), findsNothing, reason: 'no count is shown without a count');
    }
  });

  testWidgets('the clock is bad in its last 15 s and ink above it, on both looks', (tester) async {
    // Each case: the time left in ms and the colour the look gives that clock.
    for (final look in [sunny, tvLook]) {
      expect(look.colors.bad, isNot(look.colors.ink), reason: 'the warning must be a colour the look differs on');
      final cases = {15000: look.colors.bad, 15001: look.colors.ink, 1: look.colors.bad, 0: look.colors.ink};
      for (final MapEntry(key: leftMs, value: colour) in cases.entries) {
        await pumpHud(tester, bumperFrame(round: 1, timeLeftMs: leftMs), look: look);
        expect(clockColor(tester), colour, reason: 'at $leftMs ms left');
      }
    }
  });

  testWidgets('only the clock turns bad in its last 15 s; Best stays ink, on both looks', (tester) async {
    for (final look in [sunny, tvLook]) {
      await pumpHud(tester, bumperFrame(round: 1, timeLeftMs: 10000), look: look);
      expect(clockColor(tester), look.colors.bad, reason: 'at 10000 ms left the clock warns');
      expect(bestColor(tester), look.colors.ink, reason: 'the best time is not a warning');
    }
  });

  testWidgets('a race has no clock to warn about, so its time run keeps the ink, on both looks', (tester) async {
    for (final look in [sunny, tvLook]) {
      await pumpHud(tester, bumperFrame(round: 1, mode: ArenaMode.race), look: look);
      expect(clockColor(tester), look.colors.ink, reason: 'a race shows the time it has run');
    }
  });
}
