import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/look.dart';

/// The players these tests draw: two phones, numbered in the order they
/// joined, and a lone player with no opponent.
const two = {'a': (number: 1, name: 'Ada'), 'b': (number: 2, name: 'Bo')};
const one = {'a': (number: 1, name: 'Ada')};

/// The arena at [phase], with a marble per roster entry and [winner]'s goal
/// just scored.
ArenaSnapshot arena(ArenaPhase phase, ArenaRoster roster, {String? winner, double cooldown = 0}) => ArenaSnapshot(
  round: 1,
  roundTimeS: 12.4,
  phase: phase,
  walls: const [],
  goal: const Rect.fromLTRB(0.86, 0.38, 0.97, 0.62),
  hazards: const [],
  players: [
    for (final MapEntry(key: id, value: player) in roster.entries)
      ArenaPlayerView(id: id, x: 0.2 + 0.2 * player.number, y: 0.5, wins: winner == id ? 1 : 0, cooldown: cooldown),
  ],
  winnerId: winner,
  lastTimeS: 12.4,
  breakLeftS: 3,
);

/// The board drawn in [look] in a box of [box].
Future<void> pumpBoard(
  WidgetTester tester,
  ArenaSnapshot snapshot, {
  required ArenaRoster roster,
  String? ownId,
  Size box = const Size(960, 540),
  ToyLook? look,
}) async {
  tester.view.physicalSize = box;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Scaffold(
          body: ArenaBoard(snapshot: snapshot, roster: roster, ownId: ownId),
        ),
        look: look ?? sunny,
      ),
    ),
  );
}

void main() {
  testWidgets("the banner's header is the winner's colour", (tester) async {
    await pumpBoard(tester, arena(ArenaPhase.won, two, winner: 'a'), roster: two);
    final card = tester.widget<ToyCard>(find.byType(ToyCard));
    expect(card.header, contains('P1 wins!'));
    expect(card.headerColor, sunny.colors.player(1), reason: "the band is the winner's colour");
    expect(find.text('Next round in 3…'), findsOneWidget);
  });

  testWidgets("Robo's row is a robot head and its name, never a player number", (tester) async {
    const roster = {'a': (number: 1, name: 'Ada'), roboPlayerId: (number: 2, name: roboName)};
    await pumpBoard(tester, arena(ArenaPhase.playing, roster), roster: roster);
    final row = find.byKey(const Key('hud-robo'));
    expect(find.descendant(of: row, matching: find.text(roboName)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.byIcon(Icons.smart_toy)), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.textContaining('P2')),
      findsNothing,
      reason: 'no number',
    );
    expect(find.descendant(of: find.byKey(const Key('hud-a')), matching: find.text('P1 Ada')), findsOneWidget);
  });

  // M14 bugs2 7: a phone's bar must say which of the players is the one
  // holding it, or its owner cannot tell their counters from the rest.
  testWidgets('a joined phone marks its own player "(you)", and only on that phone', (tester) async {
    for (final box in [const Size(960, 540), const Size(667, 375)]) {
      await pumpBoard(tester, arena(ArenaPhase.playing, two), roster: two, ownId: 'b', box: box);
      expect(find.text('P2 Bo (you)'), findsOneWidget, reason: 'at $box');
      expect(find.text('P1 Ada'), findsOneWidget, reason: 'the other phone is unmarked');
      expect(find.textContaining('(you)'), findsOneWidget, reason: 'only one player is the phone\'s own');

      await pumpBoard(tester, arena(ArenaPhase.playing, two), roster: two, box: box);
      expect(find.textContaining('(you)'), findsNothing, reason: 'a TV marks nobody, at $box');
    }
  });

  testWidgets('a lone player who scores heads the banner in good', (tester) async {
    await pumpBoard(tester, arena(ArenaPhase.won, one), roster: one);
    final card = tester.widget<ToyCard>(find.byType(ToyCard));
    expect(card.header, contains('Goal!'));
    expect(card.headerColor, sunny.colors.good, reason: 'no player won, so the band is the good token');
  });

  // Claude's step 5 review: a ToyPill grew the tall bar from 88 to 107 px (127
  // on a TV), a quarter of the screen. A ready dash is a good dot with an ink
  // edge beside ink words, as the TV home's statuses are, on both bars.
  testWidgets('a dash that is ready is a good dot beside ink words, on both bars', (tester) async {
    for (final box in [const Size(960, 540), const Size(667, 375)]) {
      for (final (name, look) in [('Sunny', sunny), ('Night', night)]) {
        await pumpBoard(tester, arena(ArenaPhase.playing, two), roster: two, look: look, box: box);
        expect(find.byType(ToyPill), findsNothing, reason: '$name at $box');
        for (final id in ['a', 'b']) {
          final dot = tester.widget<DecoratedBox>(find.byKey(Key('dashReady-$id')));
          final decoration = dot.decoration as ShapeDecoration;
          expect(decoration.color, look.colors.good, reason: '$name at $box: the dot is good');
          expect((decoration.shape as CircleBorder).side.color, look.colors.ink, reason: 'with the ink edge');
        }
        for (final word in tester.widgetList<Text>(find.text('Dash ready (A)'))) {
          expect(word.style?.color, look.colors.ink, reason: 'text is ink, never good');
        }
      }
    }
  });

  testWidgets('a ready dash leaves the bar as tall as a cooling one', (tester) async {
    for (final box in [const Size(960, 540), const Size(667, 375)]) {
      await pumpBoard(tester, arena(ArenaPhase.playing, two, cooldown: 0.5), roster: two, box: box);
      final cooling = tester.getSize(find.byType(ArenaHud)).height;
      await pumpBoard(tester, arena(ArenaPhase.playing, two), roster: two, box: box);
      expect(tester.getSize(find.byType(ArenaHud)).height, cooling, reason: 'at $box');
      expect(find.byKey(const Key('dashReady-a')), findsOneWidget);
    }
  });
}
