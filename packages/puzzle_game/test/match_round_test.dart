import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// `MatchResult.round` (M14 design section 2 N1, a1): the match hands the
/// party night one `RoundResult` — its winners and draw as `MatchResult`
/// decides them today, each player's side's points credited in full, their
/// counters, and their line for the results card.
void main() {
  test('a 1v1 won by the left side: its winners, points, counters and lines', () {
    final m = begin(twoSquares(), const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    place(m, m.gameOf(PuzzleSide.left), 'p1', 0);
    place(m, m.gameOf(PuzzleSide.left), 'p1', 1);
    final round = m.result!.round;
    expect(round.game, 'puzzle');
    expect(round.winners, {'p1'});
    expect(round.draw, isFalse);
    expect(round.points, {'p1': 2 * PuzzlePoints.snap + PuzzlePoints.finish, 'p2': 0});
    expect(round.stats['p1'], {'snaps': 2, 'wrongDrops': 0, 'carries': 0, 'catsShooed': 0, 'tryAgains': 0});
    expect(round.stats['p2'], {'snaps': 0, 'wrongDrops': 0, 'carries': 0, 'catsShooed': 0, 'tryAgains': 0});
    expect(round.lines['p1'], const RoundLine(outcome: RoundOutcome.win, count: 2, countOf: RoundCount.pieces));
    expect(round.lines['p2'], const RoundLine(outcome: RoundOutcome.loss, count: 0, countOf: RoundCount.pieces));
  });

  test('a 1v1 that ran out of time even is a draw: no winners, and both lines say draw', () {
    final m = begin(twoSquares(), const {
      'p1': PuzzleSide.left,
      'p2': PuzzleSide.right,
    }, settings: const PuzzleSettings(timeLimitS: 1));
    drive(m, const {'p1': none, 'p2': none}, frames: 20, dt: 0.05);
    final round = m.result!.round;
    expect(round.draw, isTrue);
    expect(round.winners, isEmpty);
    expect(round.lines['p1'], const RoundLine(outcome: RoundOutcome.draw, count: 0, countOf: RoundCount.pieces));
    expect(round.lines['p2'], const RoundLine(outcome: RoundOutcome.draw, count: 0, countOf: RoundCount.pieces));
  });

  test('a 2v2 won by the left side credits both of its players in full', () {
    final m = begin(twoSquares(), const {
      'p1': PuzzleSide.left,
      'p2': PuzzleSide.left,
      'p3': PuzzleSide.right,
      'p4': PuzzleSide.right,
    });
    place(m, m.gameOf(PuzzleSide.left), 'p1', 0);
    place(m, m.gameOf(PuzzleSide.left), 'p1', 1);
    final round = m.result!.round;
    expect(round.winners, {'p1', 'p2'});
    expect(round.points, {
      'p1': 2 * PuzzlePoints.snap + PuzzlePoints.finish,
      'p2': 2 * PuzzlePoints.snap + PuzzlePoints.finish,
      'p3': 0,
      'p4': 0,
    });
    expect(round.lines['p2'], const RoundLine(outcome: RoundOutcome.win, count: 2, countOf: RoundCount.pieces));
    expect(round.lines['p4'], const RoundLine(outcome: RoundOutcome.loss, count: 0, countOf: RoundCount.pieces));
  });

  test('one board finished alone: a done line with the time, and nobody to win against', () {
    final m = begin(onePiece(), const {'p1': PuzzleSide.left});
    place(m, m.gameOf(PuzzleSide.left), 'p1', 0);
    final round = m.result!.round;
    expect(round.winners, isEmpty);
    expect(round.draw, isFalse);
    expect(round.points, {'p1': PuzzlePoints.snap + PuzzlePoints.finish});
    expect(round.lines['p1']!.outcome, RoundOutcome.done);
    expect(round.lines['p1']!.timeS, m.gameOf(PuzzleSide.left).finishTimeS);
    expect(round.lines['p1']!.count, isNull, reason: 'a board alone shows its time, not its pieces');
  });

  test('one board that ran out of time: a done line with the time played', () {
    final m = begin(twoSquares(), const {'p1': PuzzleSide.left}, settings: const PuzzleSettings(timeLimitS: 1));
    drive(m, const {'p1': none}, frames: 20, dt: 0.05);
    final game = m.gameOf(PuzzleSide.left);
    final round = m.result!.round;
    expect(round.lines['p1']!.outcome, RoundOutcome.done);
    expect(round.lines['p1']!.timeS, game.elapsedS);
    expect(round.points, {'p1': 0});
  });

  test('a result is a value: the night may keep it after the match moves on', () {
    final m = begin(twoSquares(), const {'p1': PuzzleSide.left});
    place(m, m.gameOf(PuzzleSide.left), 'p1', 0);
    place(m, m.gameOf(PuzzleSide.left), 'p1', 1);
    final round = m.result!.round;
    final kept = round.points;
    expect(() {
      kept['p2'] = 1;
    }, throwsUnsupportedError);
    expect(round.points, {'p1': 2 * PuzzlePoints.snap + PuzzlePoints.finish});
  });
}
