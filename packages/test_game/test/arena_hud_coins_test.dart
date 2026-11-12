import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/bumper.dart';
import 'support/look.dart';
import 'support/maps.dart';

/// The players these tests draw: two phones, and four with a name too long for
/// a phone's bar.
const two = {'a': (number: 1, name: 'Ada'), 'b': (number: 2, name: 'Bo')};
const one = {'a': (number: 1, name: 'Ada')};
const four = {
  'a': (number: 1, name: 'Ada'),
  'b': (number: 2, name: 'Bo'),
  'c': (number: 3, name: 'Cleo'),
  'd': (number: 4, name: 'Alexanderthegreat'),
};

/// A Bumper Round's frame: a marble per [roster] entry, the round's counters
/// on them, [coins] in their pockets and [timeLeftMs] left on its clock.
ArenaSnapshot bumperFrame(ArenaRoster roster, {Map<String, int> coins = const {}, int timeLeftMs = 16600}) =>
    ArenaSnapshot(
      round: 1,
      roundTimeS: 43.4,
      phase: ArenaPhase.playing,
      walls: const [],
      goal: Rect.zero,
      hazards: const [],
      players: [
        for (final MapEntry(key: id, value: player) in roster.entries)
          ArenaPlayerView(
            id: id,
            x: 0.15 + 0.15 * player.number,
            y: 0.5,
            wins: 2,
            hits: 5,
            dashes: 1,
            coins: coins[id] ?? 0,
          ),
      ],
      mapId: 'test',
      mode: ArenaMode.bumper,
      timeLeftMs: timeLeftMs,
    );

/// The race's frame, with the counters its bar has always shown.
ArenaSnapshot raceFrame(ArenaRoster roster) => ArenaSnapshot(
  round: 1,
  roundTimeS: 12.4,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: const Rect.fromLTRB(0.86, 0.38, 0.97, 0.62),
  hazards: const [],
  players: [
    for (final MapEntry(key: id, value: player) in roster.entries)
      ArenaPlayerView(id: id, x: 0.15 + 0.15 * player.number, y: 0.5, wins: 2, hits: 5, dashes: 1),
  ],
  mapId: 'test',
);

/// The board drawn in [look] in a box of [box].
Future<void> pumpBoard(
  WidgetTester tester,
  ArenaSnapshot snapshot, {
  required ArenaRoster roster,
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
          body: ArenaBoard(snapshot: snapshot, roster: roster),
        ),
        look: look ?? sunny,
      ),
    ),
  );
}

/// The text of the widget at [key].
String? textAt(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data;

/// [who] stands on [coin]'s spot, so the next step takes it if it can.
void standOn(ArenaGame g, ArenaPlayer who, ArenaCoin coin) => who.place(g.pixelOf(coin.position));

/// [who] walks right until it has felt one hazard hit.
void walkIntoHazard(ArenaGame g, ArenaPlayer who) {
  for (var i = 0; i < 240 && who.hits == 0; i++) {
    g.update(1 / 60, {who.id: right});
  }
}

void main() {
  // Claude's design for M14 b2: in a Bumper Round the bar shows coins before
  // the dash, and the counters of the race leave it.
  group("the Bumper Round's bar", () {
    testWidgets("shows each player's coin picture and count before the dash, and no wins, hits or dashes", (
      tester,
    ) async {
      await pumpBoard(tester, bumperFrame(two, coins: const {'a': 3, 'b': 1}), roster: two);

      expect(textAt(tester, 'coins-a'), '3');
      expect(textAt(tester, 'coins-b'), '1');
      expect(find.byKey(const Key('coin-a')), findsOneWidget, reason: 'the game\'s own coin, drawn');
      expect(find.byKey(const Key('coin-b')), findsOneWidget);
      expect(find.text('Dash ready (A)'), findsNWidgets(2));
      for (final word in ['Wins', 'Hits', 'Dashes']) {
        expect(find.textContaining(word), findsNothing, reason: '$word leaves the bar for the round');
      }
    });

    testWidgets('shows the time left on its clock', (tester) async {
      await pumpBoard(tester, bumperFrame(two, coins: const {'a': 0, 'b': 0}, timeLeftMs: 6000), roster: two);

      expect(textAt(tester, 'roundTime'), '6.0 s');
    });

    testWidgets('keeps every coin count on a phone, and cuts a long name with an ellipsis first', (tester) async {
      // A landscape phone's box: 667 × 375 is the shortest bar the app meets.
      await pumpBoard(
        tester,
        bumperFrame(four, coins: const {'a': 3, 'b': 2, 'c': 1, 'd': 0}),
        roster: four,
        box: const Size(667, 375),
      );

      expect(tester.takeException(), isNull, reason: 'nothing overflows the bar');
      for (final (id, coins) in [('a', '3'), ('b', '2'), ('c', '1'), ('d', '0')]) {
        expect(textAt(tester, 'coins-$id'), coins);
        final rect = tester.getRect(find.byKey(Key('coins-$id')));
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$id\'s count is on the screen');
        expect(rect.right, lessThanOrEqualTo(667), reason: '$id\'s count is on the screen');
      }
      final long = tester.widget<Text>(find.text('P4 Alexanderthegreat'));
      expect(long.overflow, TextOverflow.ellipsis, reason: 'the name gives way, the count stays');
      expect(long.maxLines, 1);
    });
  });

  group("the race's bar", () {
    testWidgets('keeps its counters and shows no coin count', (tester) async {
      await pumpBoard(tester, raceFrame(two), roster: two);

      expect(find.text('Wins 2'), findsNWidgets(2));
      expect(find.text('Hits 5'), findsNWidgets(2));
      expect(find.text('Dashes 1'), findsNWidgets(2));
      expect(find.byKey(const Key('coins-a')), findsNothing);
      expect(find.byKey(const Key('coin-a')), findsNothing);
      expect(textAt(tester, 'roundTime'), '12.4 s', reason: 'the race shows the time it has run');
    });
  });

  // The count is the round's own: the frame's `c` no view works out for itself.
  group("the bar's count follows the round", () {
    testWidgets('a coin picked up goes on the bar', (tester) async {
      final g = bumper(ids: const ['a'], starts: const [Offset(0.20, 0.50), ...fourStarts]);
      step(g, 1 / 60);
      final me = g.player('a')!;
      await pumpBoard(tester, g.snapshot(), roster: one);
      expect(textAt(tester, 'coins-a'), '0');

      // Off the coins while the first one sparkles, then onto it.
      me.place(g.pixelOf(const Offset(0.20, 0.50)));
      run(g, ArenaCoin.sparkleS);
      standOn(g, me, g.coins.first);
      step(g, 1 / 60);
      expect(me.coins, 1);

      await pumpBoard(tester, g.snapshot(), roster: one);
      expect(textAt(tester, 'coins-a'), '1');
    });

    testWidgets('a hazard takes one coin off the bar', (tester) async {
      final g = bumper(
        ids: const ['a'],
        starts: const [Offset(0.20, 0.50), ...fourStarts],
        hazards: const [HazardSpec.still(Offset(0.50, 0.50))],
      );
      final me = g.player('a')!..coins = 3;
      walkIntoHazard(g, me);
      expect(me.coins, 2, reason: 'one hazard drops one coin');

      await pumpBoard(tester, g.snapshot(), roster: one);
      expect(textAt(tester, 'coins-a'), '2');
    });

    testWidgets('a gold coin counts as two on the bar', (tester) async {
      final g = bumper(ids: const ['a'], starts: const [Offset(0.20, 0.50), ...fourStarts]);
      final me = g.player('a')!;
      run(g, bumperRoundS - 15);
      run(g, ArenaCoin.sparkleS);
      standOn(g, me, g.coins.first);
      step(g, 1 / 60);
      expect(me.coins, 1);

      final gold = g.coins.where((c) => c.gold).single;
      run(g, ArenaCoin.sparkleS);
      standOn(g, me, gold);
      step(g, 1 / 60);
      expect(me.coins, 1 + ArenaCoin.goldValue, reason: 'a gold coin is worth two');

      await pumpBoard(tester, g.snapshot(), roster: one);
      expect(textAt(tester, 'coins-a'), '3');
    });

    test('four marbles with their coins keep the frame inside its 2048-byte budget', () {
      final g = bumper();
      step(g, 1 / 60);
      for (final (i, p) in g.players.indexed) {
        p.coins = i + 1;
      }
      final s = g.snapshot();
      expect([for (final p in s.players) p.coins], [1, 2, 3, 4], reason: 'every count is in the frame');
      expect(ArenaSnapshot.decode(s.encode()).encode(), s.encode(), reason: 'the counts round-trip');
      expect(s.encode().length, lessThan(arenaSnapshotBudgetBytes));
    });
  });
}
