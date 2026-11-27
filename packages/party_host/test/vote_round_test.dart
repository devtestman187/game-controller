import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:party_host/src/night/vote_round.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart' show Level;

final _all = launchVariants((_) => Level.medium);

ChoiceOutcome _vote(Variant? variant, {bool byDefault = false}) =>
    ChoiceOutcome(cardId: variant?.id, count: variant == null ? 0 : 1, byDefault: byDefault);

Map<String, ChoiceOutcome> _votes(List<Variant?> votes) => {
  for (var i = 0; i < votes.length; i++) 'p$i': _vote(votes[i]),
};

void main() {
  group('offerFor', () {
    test('offers at most 4 whatever the pool size, all distinct', () {
      for (var seed = 0; seed < 20; seed++) {
        final offered = offerFor(pool: _all, played: const [], random: Random(seed));
        expect(offered, hasLength(maxVoteCards));
        expect(offered.toSet(), hasLength(maxVoteCards));
      }
    });

    test('never offers the last played game while another one exists', () {
      for (var seed = 0; seed < 30; seed++) {
        final offered = offerFor(pool: _all, played: [_all[0], _all[1]], random: Random(seed));
        expect(offered, isNot(contains(_all[1])));
      }
      final two = offerFor(pool: _all.take(2).toList(), played: [_all[0]], random: Random(1));
      expect(two, [_all[1]], reason: 'the other of two is all that is left');
    });

    test('a pool of 3 offers all 3, and a pool of one offers it even when it was just played', () {
      final three = offerFor(pool: _all.take(3).toList(), played: const [], random: Random(2));
      expect(three.toSet(), _all.take(3).toSet());
      final one = offerFor(pool: [_all[0]], played: [_all[0]], random: Random(2));
      expect(one, [_all[0]]);
    });

    test('different seeds give different orders', () {
      final orders = {
        for (var seed = 0; seed < 20; seed++) offerFor(pool: _all, played: const [], random: Random(seed)).join(','),
      };
      expect(orders.length, greaterThan(1));
    });
  });

  group('voteSetup', () {
    test('has no default and an old phone gets A, B, X, Y in card order with short labels', () {
      final offered = _all.take(4).toList();
      final setup = voteSetup(round: 3, offered: offered);
      expect(setup.round, 3);
      expect(setup.defaultId, isNull);
      expect(setup.currency, isNull);
      final cards = setup.cardsFor('p1');
      expect([for (final card in cards) card.id], [for (final variant in offered) variant.id]);
      expect(cards.every((card) => card.cost == null && card.maxCount == 1 && card.detail != null), isTrue);
      final buttons = oldPhoneButtons(cards);
      expect(
        [for (final b in buttons) b.button],
        [ControllerButton.a, ControllerButton.b, ControllerButton.x, ControllerButton.y],
      );
      expect([for (final b in buttons) b.cardId], [for (final variant in offered) variant.id]);
      expect(buttons.every((b) => b.label.length <= 12), isTrue);
    });
  });

  group('settleVote', () {
    final offered = _all.take(3).toList();

    test('the most votes win', () {
      final result = settleVote(
        offered: offered,
        outcomes: _votes([offered[1], offered[1], offered[0]]),
        random: Random(0),
      )!;
      expect(result.variant, offered[1]);
      expect(result.votes, 2);
      expect(result.byChance, isFalse);
    });

    test('a 2-2 tie is random among exactly the tied games', () {
      final reached = <Variant>{};
      for (var seed = 0; seed < 30; seed++) {
        final result = settleVote(
          offered: offered,
          outcomes: _votes([offered[0], offered[0], offered[2], offered[2]]),
          random: Random(seed),
        )!;
        expect(result.byChance, isTrue);
        expect(result.votes, 2);
        reached.add(result.variant);
      }
      expect(reached, {offered[0], offered[2]});
    });

    test('nobody voting and all abstaining are random among the offered, with no votes', () {
      for (final outcomes in [
        <String, ChoiceOutcome>{},
        _votes([null, null]),
      ]) {
        final reached = <Variant>{};
        for (var seed = 0; seed < 40; seed++) {
          final result = settleVote(offered: offered, outcomes: outcomes, random: Random(seed))!;
          expect(result.byChance, isTrue);
          expect(result.votes, 0);
          reached.add(result.variant);
        }
        expect(reached, offered.toSet());
      }
    });

    test('a null card is not a vote, nor is a card that was not offered', () {
      final result = settleVote(
        offered: offered,
        outcomes: _votes([null, null, _all[9], offered[0]]),
        random: Random(0),
      )!;
      expect(result.variant, offered[0]);
      expect(result.votes, 1);
      expect(result.byChance, isFalse);
    });

    test('byDefault changes nothing: a vote counts the same', () {
      final outcomes = {'p0': _vote(offered[1], byDefault: true), 'p1': _vote(offered[1])};
      final result = settleVote(offered: offered, outcomes: outcomes, random: Random(0))!;
      expect(result.variant, offered[1]);
      expect(result.votes, 2);
    });

    test('the same seed gives the same result', () {
      final outcomes = _votes([offered[0], offered[1]]);
      final a = settleVote(offered: offered, outcomes: outcomes, random: Random(7))!;
      final b = settleVote(offered: offered, outcomes: outcomes, random: Random(7))!;
      expect(a.variant, b.variant);
    });

    test('nothing offered settles to null', () {
      expect(settleVote(offered: const [], outcomes: const {}, random: Random(0)), isNull);
    });
  });
}
