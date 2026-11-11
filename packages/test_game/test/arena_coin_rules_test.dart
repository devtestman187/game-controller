import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/bumper.dart';
import 'support/maps.dart';

void main() {
  // M14 f1 (r5 finding 2): the coin rules of party-night section 7 beyond
  // "take one, bring one".
  group('the coin rules', () {
    /// [who] stands on [coin]'s spot, so the next step takes it if it can.
    void standOn(ArenaGame g, ArenaPlayer who, ArenaCoin coin) => who.place(g.pixelOf(coin.position));

    /// [who] stands back at the first start, clear of the coin zones.
    void offTheCoins(ArenaGame g, ArenaPlayer who) => who.place(g.pixelOf(const Offset(0.20, 0.50)));

    /// Whether [coin]'s place still holds a coin: a list holds the coin aged
    /// each step, so a coin is found by its place.
    bool stillThere(ArenaGame g, ArenaCoin coin) => g.coins.any((c) => c.position == coin.position);

    /// Walks [who] right until it has felt [hits] hazard hits, and returns the
    /// events on the way.
    List<GameEvent> walkIntoHazard(ArenaGame g, ArenaPlayer who, int hits) {
      final events = <GameEvent>[];
      for (var i = 0; i < 240 && who.hits < hits; i++) {
        events.addAll(g.update(1 / 60, {who.id: right}));
      }
      return events;
    }

    test('a coin that just came out sparkles for a second and can\'t be taken', () {
      final g = bumper(ids: const ['a'], starts: const [Offset(0.20, 0.50), ...fourStarts]);
      step(g, 1 / 60);
      final me = g.player('a')!;
      final coin = g.coins.first;
      expect(coin.sparkling, isTrue, reason: 'it came out this frame');
      standOn(g, me, coin);
      step(g, 1 / 60);
      expect(me.coins, 0, reason: 'a sparkling coin can\'t be taken yet');
      expect(stillThere(g, coin), isTrue);

      // Off it while its second passes, then back: it is takable.
      offTheCoins(g, me);
      run(g, ArenaCoin.sparkleS);
      standOn(g, me, coin);
      final events = step(g, 1 / 60);
      expect(me.coins, 1);
      expect(stillThere(g, coin), isFalse);
      expect(events.where((e) => e.cause == GameEventCause.coin).single.sound, ArenaSounds.coin);
    });

    test('a hazard drops exactly one coin, and the dropper is dizzy and then safe', () {
      final g = bumper(
        ids: const ['a'],
        starts: const [Offset(0.20, 0.50), ...fourStarts],
        hazards: const [HazardSpec.still(Offset(0.50, 0.50))],
      );
      final me = g.player('a')!..coins = 3;
      final events = walkIntoHazard(g, me, 1);

      expect(me.hits, 1, reason: 'it walked into the drain');
      expect(me.coinsDropped, 1, reason: 'one hazard, one coin');
      expect(me.coins, 2);
      final lost = events.where((e) => e.cause == GameEventCause.coinLost).single;
      expect([lost.playerId, lost.event], ['a', HapticEvent.error]);
      expect(lost.sound, ArenaSounds.coinLost);
      expect(g.coins.where((c) => c.dropper == 'a').single.isFieldCoin, isFalse, reason: 'a dropped coin');
      expect(me.dizzy, isTrue, reason: 'a second in which it can\'t dash');
      expect(me.safe, isTrue, reason: 'and nothing makes it drop');

      // Dizzy, a dash press is an error.
      final dashes = me.dashes;
      g.update(1 / 60, {'a': const GameInput(dash: true)});
      expect(me.dashes, dashes);
      expect(me.failedDashes, 1);

      // Back into the drain while safe: the safe second is not spent on it.
      me.place(g.pixelOf(const Offset(0.50, 0.50)));
      g.update(1 / 60, {'a': right});
      expect(me.hits, 2);
      expect([me.coinsDropped, me.coins], [1, 2], reason: 'safe means safe');

      // Dizzy for a second, then safe for a second, then neither.
      run(g, ArenaFieldRules.dizzyS - 0.2);
      expect(me.dizzy, isTrue);
      run(g, 0.3);
      expect(me.dizzy, isFalse);
      expect(me.safe, isTrue);
      run(g, ArenaFieldRules.safeS);
      expect(me.safe, isFalse);
    });

    test('a marble with no coins drops nothing but is dizzy all the same', () {
      final g = bumper(
        ids: const ['a'],
        starts: const [Offset(0.20, 0.50), ...fourStarts],
        hazards: const [HazardSpec.still(Offset(0.50, 0.50))],
      );
      final me = g.player('a')!;
      final events = walkIntoHazard(g, me, 1);
      expect(me.coinsDropped, 0);
      expect(g.coins.where((c) => c.dropper != null), isEmpty);
      expect(events.where((e) => e.cause == GameEventCause.coinLost), isEmpty);
      expect([me.dizzy, me.safe], [true, true], reason: 'it still pays the drop');
    });

    test('a shove into a wall drops one coin, and the dropper can\'t take it back', () {
      // b starts by the field's right edge, which is the wall it is shoved into.
      final g = bumper(
        ids: const ['a', 'b'],
        starts: const [Offset(0.30, 0.50), Offset(0.90, 0.50), Offset(0.88, 0.20), Offset(0.88, 0.80)],
      );
      final b = g.player('b')!..coins = 2;
      // The shove another marble's bump leaves (party-night section 7).
      b.shove(const Offset(600, 0));
      final events = <GameEvent>[];
      for (var i = 0; i < 120 && b.coinsDropped == 0; i++) {
        events.addAll(g.update(1 / 60, {'a': GameInput.none, 'b': right}));
      }
      expect(b.coinsDropped, 1, reason: 'shoved into the wall, one coin');
      expect(events.where((e) => e.cause == GameEventCause.coinLost).single.sound, ArenaSounds.coinLost);
      final dropped = g.coins.where((c) => c.dropper == 'b').single;

      // The dropper can't take it back; anyone else takes it at once.
      standOn(g, b, dropped);
      step(g, 1 / 60);
      expect(b.coins, 1, reason: 'the dropped coin isn\'t its dropper\'s to take');
      final a = g.player('a')!;
      standOn(g, a, dropped);
      step(g, 1 / 60);
      expect(a.coins, 1);
      expect(stillThere(g, dropped), isFalse);
    });

    test('a shove that runs into no wall drops nothing', () {
      final g = bumper(
        ids: const ['a', 'b'],
        starts: const [Offset(0.30, 0.50), Offset(0.40, 0.50), Offset(0.88, 0.20), Offset(0.88, 0.80)],
      );
      final b = g.player('b')!..coins = 2;
      b.shove(const Offset(300, 0));
      run(g, 1);
      expect([b.coinsDropped, b.coins], [0, 2], reason: 'no wall, nothing to drop');
    });

    test('in the last 15 s new field coins are gold, worth two, with the gold cue', () {
      final g = bumper(ids: const ['a'], starts: const [Offset(0.20, 0.50), ...fourStarts]);
      final me = g.player('a')!;
      run(g, bumperRoundS - 15);
      expect(g.coins.where((c) => c.gold), isEmpty, reason: 'the gold rush has not started');

      // Take one coin, after its sparkle, so a new one comes out in its place.
      run(g, ArenaCoin.sparkleS);
      final taken = g.coins.first;
      standOn(g, me, taken);
      final events = step(g, 1 / 60);
      expect(me.coins, 1);
      final fresh = g.coins.where((c) => c.gold).toList();
      expect(fresh, hasLength(1), reason: 'one coin came out, and it is gold');
      expect(events.where((e) => e.cause == GameEventCause.coinAppear), isNotEmpty);

      // Gold is worth two, and plays the gold cue.
      run(g, ArenaCoin.sparkleS);
      standOn(g, me, fresh.single);
      final gold = step(g, 1 / 60);
      expect(me.coins, 1 + ArenaCoin.goldValue);
      expect(me.goldCoins, 1);
      expect(gold.where((e) => e.cause == GameEventCause.coin).single.sound, ArenaSounds.coinGold);
    });

    test('the Bumper Round\'s dash plays a cue of its own', () {
      final g = bumper(ids: const ['a']);
      final dash = step(
        g,
        1 / 60,
        const GameInput(move: Offset(1, 0), dash: true),
      ).where((e) => e.cause == GameEventCause.dash).single;
      expect(dash.sound, ArenaSounds.dash);
      expect(dash.event, HapticEvent.rumble, reason: 'the phone still feels the dash');
    });

    test('the race keeps the haptic\'s own name for its dash', () {
      final g = ArenaGame(map: testMap(), size: const Size(1000, 500))..join('a');
      final dash = step(g, 1 / 60, const GameInput(dash: true)).where((e) => e.cause == GameEventCause.dash).single;
      expect(dash.sound, isNull, reason: 'the race has played rumble since M12');
      expect(dash.soundName, HapticEvent.rumble.name);
    });

    test('the frame carries a drop\'s dizzy and safe flags and its coin\'s dropper', () {
      final g = bumper(
        ids: const ['a'],
        starts: const [Offset(0.20, 0.50), ...fourStarts],
        hazards: const [HazardSpec.still(Offset(0.50, 0.50))],
      );
      final me = g.player('a')!..coins = 1;
      walkIntoHazard(g, me, 1);
      final s = g.snapshot();
      final view = s.player('a')!;
      expect([view.dizzy, view.safe], [true, true]);
      final dropped = s.coins.where((c) => c.dropper != null).single;
      expect(dropped.dropper, 0, reason: 'the dropper\'s seat in the frame, not its id');
      expect(dropped.gold, isFalse, reason: 'a dropped coin is worth one');
      expect(ArenaSnapshot.decode(s.encode()).encode(), s.encode(), reason: 'the flags round-trip');
    });

    test('a gold coin goes into the frame, and the frame stays inside its budget', () {
      final g = bumper(ids: const ['a'], starts: const [Offset(0.20, 0.50), ...fourStarts]);
      run(g, bumperRoundS - 15);
      run(g, ArenaCoin.sparkleS);
      standOn(g, g.player('a')!, g.coins.first);
      step(g, 1 / 60);
      final s = g.snapshot();
      expect(s.coins.where((c) => c.gold), hasLength(1));
      expect(ArenaSnapshot.decode(s.encode()).encode(), s.encode(), reason: 'the gold flag round-trips');
      expect(s.encode().length, lessThan(arenaSnapshotBudgetBytes));
    });
  });
}
