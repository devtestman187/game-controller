import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/bumper.dart';
import 'support/maps.dart';

/// The coin nearest [at], in pixels.
ArenaCoin nearestCoin(ArenaGame g, Offset at) =>
    g.coins.reduce((a, b) => (a.position - at).distance <= (b.position - at).distance ? a : b);

void main() {
  group('contacts', () {
    test('two marbles that touch push each other apart, and neither is knocked out', () {
      final g = bumper(
        ids: ['a', 'b'],
        starts: const [Offset(0.30, 0.5), Offset(0.46, 0.5), Offset(0.88, 0.20), Offset(0.88, 0.80)],
      );
      final b0 = g.player('b')!.position;
      final events = <GameEvent>[];
      for (var i = 0; i < 120 && g.player('b')!.position.dx == b0.dx; i++) {
        events.addAll(g.update(1 / 60, {'a': right, 'b': GameInput.none}));
      }

      // The marble that was walked into is pushed away, and both feel it.
      expect(g.player('b')!.position.dx, greaterThan(b0.dx), reason: 'the still marble is pushed');
      expect(g.players.map((p) => p.bumps), [1, 1], reason: 'one contact, felt by both');
      final shoves = events.where((e) => e.cause == GameEventCause.bump).toList();
      expect(shoves.map((e) => e.playerId), ['a', 'b']);
      expect(shoves.map((e) => e.event), [HapticEvent.hit, HapticEvent.hit]);
      expect(shoves.map((e) => e.sound), [ArenaSounds.bump, ArenaSounds.bump]);
      // Neither is out: the round plays on and the two are still two.
      expect(g.phase, ArenaPhase.playing);
      expect(g.players, hasLength(2));
      final gap = g.player('b')!.position.dx - g.player('a')!.position.dx;
      expect(gap, greaterThan(2 * g.playerRadiusPx - 1));
    });

    test('a dash into a marble shoves it hard, and the round still plays on', () {
      final g = bumper(
        ids: ['a', 'b'],
        starts: const [Offset(0.30, 0.5), Offset(0.42, 0.5), Offset(0.88, 0.20), Offset(0.88, 0.80)],
      );
      final b0 = g.player('b')!.position;
      final events = <GameEvent>[];
      for (var i = 0; i < 120 && g.player('a')!.shoves == 0; i++) {
        events.addAll(g.update(1 / 60, {'a': const GameInput(move: Offset(1, 0), dash: true), 'b': GameInput.none}));
      }
      expect(g.player('a')!.shoves, 1);
      expect(events.where((e) => e.cause == GameEventCause.bump).map((e) => e.sound), contains(ArenaSounds.bumpBig));
      // The shove moves the marble on the step after the touch.
      step(g, 1 / 60);
      expect(g.player('b')!.position.dx - b0.dx, greaterThan(20), reason: 'a dash shoves further than a walk');
    });

    test('resting against another marble does not buzz every frame', () {
      final g = bumper(
        ids: ['a', 'b'],
        starts: const [Offset(0.30, 0.5), Offset(0.34, 0.5), Offset(0.88, 0.20), Offset(0.88, 0.80)],
      );
      final events = run(g, 1, right);
      expect(events.where((e) => e.cause == GameEventCause.bump).length, lessThanOrEqualTo(3));
    });
  });

  group('coins', () {
    test('three coins come out at once, all of them in the map coin zones', () {
      final g = bumper(ids: const ['a'], zones: const [Rect.fromLTRB(0.60, 0.10, 0.80, 0.30)]);
      final events = step(g, 1 / 60);
      expect(g.coins, hasLength(ArenaCoin.coinsOut));
      for (final coin in g.coins) {
        expect(coin.position.dx, inInclusiveRange(0.60, 0.80));
        expect(coin.position.dy, inInclusiveRange(0.10, 0.30));
      }
      final appear = events.where((e) => e.cause == GameEventCause.coinAppear).single;
      expect(appear.playerId, isNull, reason: 'the field caused it, not a player');
      expect(appear.event, isNull);
      expect(appear.sound, ArenaSounds.coinAppear);
    });

    test('a coin taken scores one point and a new one appears in a zone', () {
      final g = bumper(ids: const ['a'], starts: const [Offset(0.20, 0.5), ...fourStarts]);
      step(g, 1 / 60);
      expect(g.coins, hasLength(ArenaCoin.coinsOut));
      final me = g.player('a')!;
      final events = <GameEvent>[];
      for (var i = 0; i < 600 && me.coins == 0; i++) {
        final delta = g.pixelOf(nearestCoin(g, me.position).position) - me.position;
        final input = delta.distance < 1 ? GameInput.none : GameInput(move: delta / delta.distance);
        events.addAll(g.update(1 / 60, {'a': input}));
      }

      expect(me.coins, 1);
      expect(g.coins, hasLength(ArenaCoin.coinsOut), reason: 'one taken, one replaced');
      for (final coin in g.coins) {
        expect(centerZone.contains(coin.position), isTrue, reason: '$coin');
      }
      final score = events.where((e) => e.cause == GameEventCause.coin).single;
      expect(score.playerId, 'a');
      expect(score.event, HapticEvent.tick);
      expect(score.sound, ArenaSounds.coin);
    });

    test('no coin appears under a marble, and every coin is clear of the walls', () {
      // A marble in the middle of the zone, and a wall beside it.
      final g = bumper(
        ids: const ['a'],
        starts: const [Offset(0.50, 0.50), ...fourStarts],
        walls: const [WallSpec(Offset(0.42, 0.44), Offset(0.42, 0.56))],
      );
      step(g, 1 / 60);
      expect(g.coins, isNotEmpty);
      final grid = MapGrid(map: g.map);
      final p = g.player('a')!;
      for (final coin in g.coins) {
        final reach = g.playerRadiusPx + ArenaCoin.radius * g.size.shortestSide;
        expect((coin.position - p.position).distance, greaterThanOrEqualTo(reach), reason: '$coin under the marble');
        expect(grid.isFree(coin.position), isTrue, reason: '$coin on a wall');
      }
    });

    test('the Playroom keeps every coin in a zone and off its walls for a whole round', () {
      final map = ArenaMap.playroom;
      final g = ArenaGame(map: map, mode: ArenaMode.bumper, size: mapFieldSize);
      run(g, 10);
      final grid = MapGrid(map: map);
      for (final coin in g.coins) {
        expect(map.bumper!.coins.any((zone) => zone.contains(coin.position)), isTrue, reason: '$coin');
        expect(grid.isFree(coin.position), isTrue, reason: '$coin');
      }
    });
  });

  group('the clock', () {
    test('the round ends when the clock runs out at 60 s, and then the clock stands still', () {
      final g = bumper(ids: const ['a']);
      final early = run(g, 59.9);
      expect(early.where((e) => e.cause == GameEventCause.timeUp), isEmpty);
      expect(g.phase, ArenaPhase.playing);
      expect(g.timeLeftS, closeTo(0.1, 1e-6));

      final late = run(g, 1);
      final up = late.where((e) => e.cause == GameEventCause.timeUp).single;
      expect(up.sound, ArenaSounds.timeUp);
      expect(up.playerId, isNull, reason: 'time is up for everyone');
      expect(g.phase, ArenaPhase.over);
      expect(g.roundTime, closeTo(60, 1e-6));
      expect(g.timeLeftS, 0);

      run(g, 3, right);
      expect(g.roundTime, closeTo(60, 1e-6), reason: 'the clock stands still once the round is over');
      expect(g.phase, ArenaPhase.over);
    });
  });

  group('results', () {
    test('most coins wins; the result carries coins as points and the counters', () {
      final g = bumper();
      g.player('a')!.coins = 2;
      g.player('b')!.coins = 1;
      run(g, 60.1);

      expect(g.phase, ArenaPhase.over);
      expect([g.winnerId, g.draw], ['a', false]);
      final result = g.roundResult!;
      expect(result.game, arenaGame);
      expect(result.winners, {'a'});
      // Coins, and the winner's bonus (party-night section 7, N3).
      expect(result.points, {'a': 2 + bumperWinBonus, 'b': 1, 'c': 0, 'd': 0});
      expect(result.lines['a']!.outcome, RoundOutcome.win);
      expect(result.lines['b']!.outcome, RoundOutcome.loss);
      expect(result.lines['a']!.count, 2);
      expect(result.lines['a']!.countOf, RoundCount.coins);
      expect(result.stats['a'], {'coins': 2, 'bumps': 0, 'bumpsGiven': 0, 'goldCoins': 0, 'coinsDropped': 0});
    });

    test('a night\'s last round doubles the points, bonus and coins alike', () {
      final g = bumper(pointsScale: 2);
      g.player('a')!.coins = 2;
      g.player('b')!.coins = 1;
      run(g, 60.1);

      expect(g.roundResult!.points, {'a': (2 + bumperWinBonus) * 2, 'b': 2, 'c': 0, 'd': 0});
      expect(g.roundResult!.lines['a']!.count, 2, reason: 'the card counts the coins as they were won');
    });

    test('a tie shares the win, and nobody scoring is a draw with no winners', () {
      final tie = bumper();
      tie.player('a')!.coins = 1;
      tie.player('c')!.coins = 1;
      run(tie, 60.1);
      expect([tie.winnerId, tie.draw], [null, true]);
      expect(tie.roundResult!.winners, {'a', 'c'});
      expect(tie.roundResult!.lines['a']!.outcome, RoundOutcome.draw);
      expect(tie.roundResult!.lines['b']!.outcome, RoundOutcome.loss);

      final none = bumper();
      run(none, 60.1);
      expect([none.winnerId, none.draw], [null, true]);
      expect(none.roundResult!.winners, isEmpty);
      expect(none.roundResult!.lines.values.map((l) => l.outcome), everyElement(RoundOutcome.draw));
    });
  });

  group('snapshot', () {
    test('version 2 names the map, mode and clock, and carries coins and scores', () {
      final g = bumper();
      step(g, 1 / 60);
      g.player('a')!.coins = 3;
      final s = g.snapshot();
      expect(ArenaSnapshot.version, 2);
      expect([s.mapId, s.mode], ['test', ArenaMode.bumper]);
      expect(s.coins, hasLength(ArenaCoin.coinsOut));
      expect(s.player('a')!.coins, 3);
      expect(s.timeLeftMs, closeTo(60 * 1000, 20));
      expect(s.goal, Rect.zero, reason: 'a Bumper Round has no goal pad');
      final again = ArenaSnapshot.decode(s.encode());
      expect(again.encode(), s.encode(), reason: 'a v2 frame round-trips');
    });

    test('four marbles and three coins fit the 2048-byte frame on the Playroom', () {
      final g = ArenaGame(map: ArenaMap.playroom, mode: ArenaMode.bumper, size: mapFieldSize);
      for (final id in ['a', 'b', 'c', 'd']) {
        g.join(id);
      }
      step(g, 1 / 60);
      expect(g.coins, hasLength(ArenaCoin.coinsOut));
      expect(g.snapshot().encode().length, lessThan(arenaSnapshotBudgetBytes));
    });

    test('the race keeps its frame and carries no coins or clock', () {
      final g = ArenaGame(map: testMap(), size: const Size(1000, 500))..join('a');
      final s = g.snapshot();
      expect([s.mapId, s.mode, s.coins, s.timeLeftMs], [testMap().id, ArenaMode.race, isEmpty, null]);
      expect(s.goal, isNot(Rect.zero));
      expect(ArenaSnapshot.decode(s.encode()).encode(), s.encode());
    });
  });

  test('a game with no mode is the race it has always been', () {
    final g = ArenaGame();
    expect([g.mode, g.timeLeftS, g.coins, g.roundResult, g.draw], [ArenaMode.race, null, isEmpty, null, false]);
    expect(g.phase, ArenaPhase.playing);
  });
}
