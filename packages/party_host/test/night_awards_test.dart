import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  group('the awards\' catalogue', () {
    test('it is the design\'s twelve awards, each with its own picture', () {
      expect(NightAward.values, hasLength(12));
      expect({for (final award in NightAward.values) award.title}, hasLength(12));
      expect({for (final award in NightAward.values) award.picture}, hasLength(12));
      expect(NightAward.values.every((award) => award.line.isNotEmpty), isTrue);
    });

    test('five awards a losing player can still win, and two either game can earn', () {
      expect(
        {
          for (final award in NightAward.values)
            if (award.losable) award,
        },
        {
          NightAward.bestHelper,
          NightAward.catCatcher,
          NightAward.comeback,
          NightAward.tryAgain,
          NightAward.bounceHouse,
        },
      );
      expect(
        {
          for (final award in NightAward.values)
            if (award.eitherGameCanEarnIt) award,
        },
        {NightAward.comeback, NightAward.roundWinner},
      );
    });
  });

  group('drawAwards', () {
    /// Both games, as the start card offers them while a Bumper Round can
    /// be picked (design section 6).
    const both = {NightAwardGame.puzzle, NightAwardGame.bumper};

    test('three different awards, one losable and one either game\'s, for every seed', () {
      for (var seed = 0; seed < 300; seed++) {
        final drawn = drawAwards(Random(seed), games: both);
        expect(drawn, hasLength(nightAwardsPerNight), reason: 'seed $seed');
        expect(drawn.toSet(), hasLength(nightAwardsPerNight), reason: 'seed $seed');
        expect(drawn.where((award) => award.losable), isNotEmpty, reason: 'seed $seed has no losable award');
        expect(
          drawn.where((award) => award.eitherGameCanEarnIt),
          isNotEmpty,
          reason: 'seed $seed has no either-game award',
        );
      }
    });

    test('a seed fixes the three, listed in the catalogue\'s order', () {
      final drawn = drawAwards(Random(7), games: both);
      expect(drawAwards(Random(7), games: both), drawn);
      expect(drawn, [
        for (final award in NightAward.values)
          if (drawn.contains(award)) award,
      ]);
      expect(drawn.map((award) => award.title).toList(), ['Best Helper', 'Cat Catcher', 'Round Winner']);
    });

    test('another seed draws another set', () {
      final a = drawAwards(Random(1), games: both).map((award) => award.title).toList();
      final b = drawAwards(Random(2), games: both).map((award) => award.title).toList();
      expect(a, isNot(b));
    });

    // M14 f1 (r5 finding 3): an award a night's games can't earn would always
    // be revealed as "Not won tonight".
    test('only an award a night\'s own games can earn is drawn', () {
      for (var seed = 0; seed < 100; seed++) {
        for (final games in [
          {NightAwardGame.puzzle},
          {NightAwardGame.bumper},
        ]) {
          final drawn = drawAwards(Random(seed), games: games);
          final other = games.contains(NightAwardGame.puzzle) ? NightAwardGame.bumper : NightAwardGame.puzzle;
          expect(drawn, hasLength(nightAwardsPerNight), reason: 'seed $seed, $games');
          expect(
            drawn.where((award) => award.game == other),
            isEmpty,
            reason: 'seed $seed drew an award only $other can earn, with games $games',
          );
          expect(drawn.where((award) => award.losable), isNotEmpty, reason: 'seed $seed, $games');
          expect(drawn.where((award) => award.eitherGameCanEarnIt), isNotEmpty, reason: 'seed $seed, $games');
        }
      }
    });
  });
}
