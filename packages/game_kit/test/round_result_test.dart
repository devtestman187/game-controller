import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

/// A round's result (M14 design section 2 N1): the value each game's screen
/// hands to its `onFinished`, which the party night reads.
void main() {
  RoundResult oneBoard() => RoundResult(
    game: 'puzzle',
    winners: {'p1'},
    points: {'p1': 7, 'p2': 3},
    stats: {
      'p1': {'snaps': 4},
      'p2': {'snaps': 2},
    },
    lines: {
      'p1': const RoundLine(outcome: RoundOutcome.win, count: 6, countOf: RoundCount.pieces),
      'p2': const RoundLine(outcome: RoundOutcome.loss, count: 5, countOf: RoundCount.pieces),
    },
  );

  test('a result\'s collections cannot be changed after it is made', () {
    final r = oneBoard();
    expect(() {
      r.winners.add('p3');
    }, throwsUnsupportedError);
    expect(() {
      r.points['p3'] = 1;
    }, throwsUnsupportedError);
    expect(() {
      r.stats['p3'] = {'snaps': 1};
    }, throwsUnsupportedError);
    expect(() {
      r.stats['p1']!['snaps'] = 9;
    }, throwsUnsupportedError);
    expect(() {
      r.lines.remove('p1');
    }, throwsUnsupportedError);
  });

  test('a result keeps the collections it was made from as they were', () {
    final points = {'p1': 7};
    final stats = {
      'p1': {'snaps': 4},
    };
    final lines = {'p1': const RoundLine(outcome: RoundOutcome.win)};
    final r = RoundResult(game: 'arena', points: points, stats: stats, lines: lines);
    points['p1'] = 0;
    stats['p1']!['snaps'] = 0;
    lines.clear();
    expect(r.points, {'p1': 7}, reason: 'the game may change its own map after handing the result over');
    expect(r.stats, {
      'p1': {'snaps': 4},
    });
    expect(r.lines, hasLength(1));
  });

  test('two results of the same round compare equal, counters included', () {
    expect(oneBoard(), equals(oneBoard()));
    expect(oneBoard().hashCode, oneBoard().hashCode);
    expect(oneBoard(), isNot(RoundResult(game: 'arena', winners: {'p1'})));
    expect(oneBoard(), isNot(RoundResult(game: 'puzzle', winners: {'p1'}, draw: true)));
    expect(
      oneBoard(),
      isNot(
        RoundResult(
          game: 'puzzle',
          winners: {'p1'},
          stats: {
            'p1': {'snaps': 5},
          },
        ),
      ),
    );
  });

  test('an id the round never had is kept: nothing checks the roster here', () {
    final r = RoundResult(
      game: 'arena',
      points: {'ghost': 3},
      stats: {
        'ghost': {'coins': 3},
      },
      lines: {'ghost': const RoundLine(outcome: RoundOutcome.win, count: 3, countOf: RoundCount.coins)},
    );
    expect(r.points['ghost'], 3);
    expect(r.stats['ghost'], {'coins': 3});
    expect(r.lines['ghost']!.countOf, RoundCount.coins);
    expect(r.winners, isEmpty, reason: 'a round nobody won says so with no winners');
  });

  test('a line says how the round went, with its time or its count', () {
    const done = RoundLine(outcome: RoundOutcome.done, timeS: 102.5);
    expect(done.outcome, RoundOutcome.done);
    expect(done.timeS, 102.5);
    expect(done.count, isNull);
    const drew = RoundLine(outcome: RoundOutcome.draw, count: 3, countOf: RoundCount.coins);
    expect(drew.count, 3);
    expect(drew.countOf, RoundCount.coins);
    expect(drew, const RoundLine(outcome: RoundOutcome.draw, count: 3, countOf: RoundCount.coins));
    expect(drew.hashCode, const RoundLine(outcome: RoundOutcome.draw, count: 3, countOf: RoundCount.coins).hashCode);
    expect(drew, isNot(const RoundLine(outcome: RoundOutcome.draw, count: 4, countOf: RoundCount.coins)));
  });

  test('a count without what it counts is refused, and so is the reverse', () {
    expect(() => RoundLine(outcome: RoundOutcome.win, count: 3), throwsAssertionError);
    expect(() => RoundLine(outcome: RoundOutcome.win, countOf: RoundCount.pieces), throwsAssertionError);
  });
}
