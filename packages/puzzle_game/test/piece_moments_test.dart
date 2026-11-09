import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A board whose pieces are in [states], one after another along the board.
PuzzleSnapshot board(List<PieceState> states, {String puzzleId = 'house'}) => PuzzleSnapshot(
  puzzleId: puzzleId,
  timeLeftMs: 60000,
  phase: PuzzlePhase.playing,
  pieces: [for (final (i, state) in states.indexed) PieceView(x: 10.0 * (i + 1), y: 20, angle: 0, state: state)],
  players: const [],
);

/// One board, or two when [right] is given: a race.
MatchSnapshot match(List<PieceState> left, [List<PieceState>? right]) =>
    MatchSnapshot(boards: [board(left), if (right != null) board(right)]);

/// A board of three loose pieces, so a state at each index can move on its own.
const loose = [PieceState.tray, PieceState.tray, PieceState.tray];

void main() {
  test('a piece that turns locked or wrong is noted with the time it was seen', () {
    final moments = PieceMoments()..observe(match(loose), 1000);
    expect(moments.ageMs(0, 1, 1000), isNull, reason: 'nothing has happened yet');
    moments.observe(match([PieceState.tray, PieceState.locked, PieceState.tray]), 1150);
    expect(moments.ageMs(0, 1, 1150), 0);
    expect(moments.ageMs(0, 0, 1150), isNull, reason: 'the pieces that did not move');
    moments.observe(match([PieceState.tray, PieceState.wrong, PieceState.tray]), 1400);
    expect(moments.ageMs(0, 1, 1400), 0, reason: 'a wrong drop is noted too');
  });

  test('a piece already locked in the first snapshot a view sees is not noted', () {
    final moments = PieceMoments()..observe(match([PieceState.locked, PieceState.wrong, PieceState.tray]), 0);
    expect(moments.ageMs(0, 0, 0), isNull);
    expect(moments.ageMs(0, 1, 90), isNull, reason: 'the view was built mid-round');
  });

  test('the age grows with the clock, and a piece that moves again starts it afresh', () {
    final moments = PieceMoments()..observe(match(loose), 0);
    moments.observe(match([PieceState.tray, PieceState.tray, PieceState.locked]), 200);
    expect(moments.ageMs(0, 2, 200), 0);
    expect(moments.ageMs(0, 2, 275), 75);
    expect(moments.ageMs(0, 2, 900), 700);
    moments.observe(match([PieceState.tray, PieceState.tray, PieceState.locked]), 950);
    expect(moments.ageMs(0, 2, 1000), 800, reason: 'still locked: it is the same lock');
    moments.observe(match([PieceState.tray, PieceState.tray, PieceState.wrong]), 1000);
    expect(moments.ageMs(0, 2, 1000), 0);
  });

  test('a race notes each board\'s pieces apart', () {
    final moments = PieceMoments()..observe(match(loose, loose), 0);
    moments.observe(match(loose, [PieceState.tray, PieceState.tray, PieceState.locked]), 300);
    expect(moments.ageMs(1, 2, 300), 0);
    expect(moments.ageMs(0, 2, 300), isNull);
  });

  test('a new round on a board starts its notes again', () {
    final moments = PieceMoments()..observe(match(loose), 0);
    moments.observe(match([PieceState.tray, PieceState.locked, PieceState.tray]), 100);
    expect(moments.ageMs(0, 1, 100), 0);
    moments.observe(
      MatchSnapshot(
        boards: [
          board([PieceState.tray, PieceState.locked, PieceState.tray], puzzleId: 'rocket'),
        ],
      ),
      500,
    );
    expect(moments.ageMs(0, 1, 500), isNull, reason: 'the next round\'s pieces start afresh');
    moments.observe(
      MatchSnapshot(
        boards: [
          board([PieceState.tray, PieceState.wrong, PieceState.tray], puzzleId: 'rocket'),
        ],
      ),
      600,
    );
    expect(moments.ageMs(0, 1, 600), 0);
  });

  test('a board a view has not drawn yet, and a piece past its end, have no age', () {
    final moments = PieceMoments()..observe(match(loose), 0);
    expect(moments.ageMs(1, 0, 0), isNull);
    expect(moments.ageMs(0, 3, 0), isNull);
  });

  test('the boing grows to 1.12 half way and is done at 150 ms', () {
    expect(PieceMoments.boingScale(0), closeTo(1.0, 0.01));
    expect(PieceMoments.boingScale(75), closeTo(1.12, 0.01));
    expect(PieceMoments.boingScale(150), closeTo(1.0, 0.01));
    expect(PieceMoments.boingScale(37), closeTo(1.0592, 0.01));
    expect(PieceMoments.boingScale(149), greaterThan(1.0));
  });

  test('the wobble turns +3, -3 and back to 0 in three equal parts of 120 ms', () {
    expect(PieceMoments.wobbleDeg(0), 3);
    expect(PieceMoments.wobbleDeg(30), 3);
    expect(PieceMoments.wobbleDeg(60), -3);
    expect(PieceMoments.wobbleDeg(90), 0);
    expect(PieceMoments.wobbleDeg(120), 0);
  });

  test('the sparkle grows and fades over 400 ms', () {
    expect(PieceMoments.sparkleGrow(0), 0);
    expect(PieceMoments.sparkleGrow(200), closeTo(0.3, 1e-9));
    expect(PieceMoments.sparkleLeft(0), 1);
    expect(PieceMoments.sparkleLeft(200), closeTo(0.5, 1e-9));
    expect(PieceMoments.sparkleLeft(400), 0);
  });

  test('with the effects off none of it moves', () {
    for (final age in [0, 37, 75, 150, 200]) {
      expect(PieceMoments.boingScale(age, effects: false), 1, reason: '$age ms');
      expect(PieceMoments.wobbleDeg(age, effects: false), 0, reason: '$age ms');
      expect(PieceMoments.sparkleGrow(age, effects: false), 0, reason: '$age ms');
      expect(PieceMoments.sparkleLeft(age, effects: false), 0, reason: '$age ms');
    }
  });
}
