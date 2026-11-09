import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// A big crate and a small ball: the ball's dot is its middle, the crate's
/// grab holds the dot inside it, which is what tells a worker its side.
Puzzle fixture() => Puzzle.parse('''
{"id": "work", "name": "Work", "level": "easy", "pieces": [
  {"id": "crate", "shape": {"rect": [10, 10]}, "color": "#AA7744", "at": [100, 40], "big": true},
  {"id": "ball", "shape": {"circle": 5}, "color": "#00FF00", "at": [30, 20]}
]}''');

/// The crate at ([x], [y]), carried by [holders] (nobody by default), calling
/// the teammate if [calling].
PieceView crate(
  double x,
  double y, {
  PieceState state = PieceState.held,
  List<int> holders = const [1],
  bool calling = false,
  double angle = 0,
}) => PieceView(x: x, y: y, angle: angle, state: state, holders: holders, calling: calling);

/// The ball at ([x], [y]) in its tray, held by [holders], still.
PieceView ball(double x, double y, {PieceState state = PieceState.tray, List<int> holders = const []}) =>
    PieceView(x: x, y: y, angle: 0, state: state, holders: holders);

/// A player at ([x], [y]) holding piece [held].
PlayerView player(double x, double y, {int number = 1, int? held}) =>
    PlayerView(number: number, x: x, y: y, held: held);

/// One board of the fixture, with [pieces] and [players] as given.
PuzzleSnapshot board(List<PieceView> pieces, List<PlayerView> players, {PuzzlePhase phase = PuzzlePhase.playing}) =>
    PuzzleSnapshot(puzzleId: 'work', timeLeftMs: 60000, phase: phase, pieces: pieces, players: players);

MatchSnapshot boardOnly(PuzzleSnapshot b) => MatchSnapshot(boards: [b]);

/// Moments that have seen [first] at [firstAtMs], and nothing before it.
WorkerMoments watching(PuzzleSnapshot first, {int firstAtMs = 1000}) =>
    WorkerMoments(fixture())..observe(boardOnly(first), firstAtMs);

void main() {
  group('the moment table', () {
    test('a right drop: a grin for half a second', () {
      final m = watching(board([crate(60, 45), ball(10, 10)], [player(60, 45, held: 0)]));
      final dropped = board(
        [crate(60, 45, state: PieceState.locked, holders: const []), ball(10, 10)],
        [player(60, 45)],
      );
      m.observe(boardOnly(dropped), 1200);
      expect(m.poseOf(0, 1, 1200).face, WorkerFace.happy);
      expect(m.poseOf(0, 1, 1200 + happyMomentMs - 1).face, WorkerFace.happy, reason: 'still inside the moment');
      expect(m.poseOf(0, 1, 1200 + happyMomentMs).face, isNot(WorkerFace.happy), reason: 'the moment is over');
    });

    test('a wrong drop: a wince for 600 ms', () {
      final m = watching(board([crate(60, 45), ball(10, 10)], [player(60, 45, held: 0)]));
      final dropped = board(
        [crate(60, 45, state: PieceState.wrong, holders: const []), ball(10, 10)],
        [player(60, 45)],
      );
      m.observe(boardOnly(dropped), 1200);
      expect(m.poseOf(0, 1, 1200).face, WorkerFace.oops);
      expect(m.poseOf(0, 1, 1200).sweat, isTrue, reason: 'a sweat drop');
      expect(m.poseOf(0, 1, 1200 + oopsMomentMs - 1).face, WorkerFace.oops);
      expect(m.poseOf(0, 1, 1200 + oopsMomentMs).face, isNot(WorkerFace.oops));
    });

    test('the round won: a cheer that keeps hopping', () {
      final m = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45)], phase: PuzzlePhase.finished));
      // A quarter of the hop's cycle after the clock's zero: as high as it goes.
      final pose = m.poseOf(0, 1, 250);
      expect(pose.face, WorkerFace.happy);
      expect(pose.motion.dy, lessThan(0), reason: 'up in the air');
      expect(m.poseOf(0, 1, 0).motion.dy, closeTo(0, 1e-9), reason: 'and down again at the start of a hop');
    });

    test('the round lost: a shrug, whether the time ran out or the other side finished first', () {
      for (final phase in [PuzzlePhase.timeUp, PuzzlePhase.stopped]) {
        final m = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45)], phase: phase));
        expect(m.poseOf(0, 1, 2000).face, WorkerFace.oops, reason: phase.name);
      }
    });

    test('calling a teammate to a big piece it holds alone: an open mouth and a wave', () {
      final m = watching(board([crate(60, 45, calling: true), ball(10, 10)], [player(55, 45, held: 0)]));
      final pose = m.poseOf(0, 1, 3000);
      expect(pose.face, WorkerFace.call);
      expect(pose.hands.right.dy, lessThan(0), reason: 'the waving hand is up');
      expect(pose.look.dx, greaterThan(0), reason: 'looking at the piece on its right');
    });

    test('turning the piece it holds: eyes screwed shut in effort', () {
      final m = watching(board([crate(60, 45), ball(10, 10)], [player(55, 45, held: 0)]));
      m.observe(boardOnly(board([crate(60, 45, angle: 30), ball(10, 10)], [player(55, 45, held: 0)])), 1200);
      final pose = m.poseOf(0, 1, 1200);
      expect(pose.face, WorkerFace.effort);
      expect(pose.look.dx, greaterThan(0), reason: 'looking at the piece it turns');
    });

    test('a big piece carried alone and moving: a strain, with a shiver and a sweat drop', () {
      final m = watching(board([crate(60, 45, calling: true), ball(10, 10)], [player(55, 45, held: 0)]));
      m.observe(boardOnly(board([crate(62, 45, calling: true), ball(10, 10)], [player(57, 45, held: 0)])), 1100);
      final pose = m.poseOf(0, 1, 1100);
      expect(pose.face, WorkerFace.effort);
      expect(pose.sweat, isTrue);
      expect(pose.squash.x, greaterThan(1), reason: 'squashed wide by the weight');
      expect(pose.motion.dx, isNot(0), reason: 'shivering');
    });

    test('a big piece carried with a teammate: a smile with both hands on it', () {
      final m = watching(
        board(
          [
            crate(60, 45, holders: const [1, 2]),
            ball(10, 10),
          ],
          [player(55, 45, held: 0), player(60, 45, number: 2, held: 0)],
        ),
      );
      m.observe(
        boardOnly(
          board(
            [
              crate(62, 45, holders: const [1, 2]),
              ball(10, 10),
            ],
            [player(57, 45, held: 0), player(62, 45, number: 2, held: 0)],
          ),
        ),
        1100,
      );
      final pose = m.poseOf(0, 1, 1100);
      expect(pose.face, WorkerFace.smile);
      expect(pose.hands.left.dx, greaterThan(0), reason: 'the left hand on the piece on its right');
      expect(pose.hands.right.dx, greaterThan(0), reason: 'the right hand too');
    });

    test('pushing: walking into the piece, leaning into it', () {
      final m = watching(board([crate(60, 45), ball(10, 10)], [player(55, 45, held: 0)]));
      m.observe(boardOnly(board([crate(62, 45), ball(10, 10)], [player(57, 45, held: 0)])), 1100);
      final pose = m.poseOf(0, 1, 1100);
      expect(pose.face, WorkerFace.effort);
      expect(pose.leanDeg, greaterThan(0), reason: 'leaning toward the piece on its right');
    });

    test('pulling: walking away with the piece, leaning back from it', () {
      final m = watching(board([crate(60, 45), ball(10, 10)], [player(55, 45, held: 0)]));
      m.observe(boardOnly(board([crate(58, 45), ball(10, 10)], [player(53, 45, held: 0)])), 1100);
      final pose = m.poseOf(0, 1, 1100);
      expect(pose.face, WorkerFace.effort);
      expect(pose.leanDeg, lessThan(0), reason: 'leaning away from the piece it drags');
    });

    test('a sideways shuffle inside the dead zone is carrying, not pushing or pulling', () {
      // The piece is 5 to the right of the dot, so its side is (-1, 0): travel
      // at [deg] to the piece's side is a pull once past sideDeadZoneDeg.
      for (final (deg, effort) in [(19.0, false), (21.0, true)]) {
        final away = Offset(-sin(deg * pi / 180), cos(deg * pi / 180)) * 2;
        final m = watching(board([crate(60, 45), ball(10, 10)], [player(55, 45, held: 0)]));
        m.observe(
          boardOnly(
            board([crate(60 + away.dx, 45 + away.dy), ball(10, 10)], [player(55 + away.dx, 45 + away.dy, held: 0)]),
          ),
          1100,
        );
        final pose = m.poseOf(0, 1, 1100);
        expect(pose.face, effort ? WorkerFace.effort : WorkerFace.smile, reason: '$deg° from sideways');
        expect(pose.leanDeg, effort ? lessThan(0) : 0, reason: '$deg° from sideways');
      }
    });

    test('carrying still: a smile with both hands on the piece', () {
      final m = watching(board([crate(60, 45), ball(10, 10)], [player(55, 45, held: 0)]));
      final pose = m.poseOf(0, 1, 3000);
      expect(pose.face, WorkerFace.smile);
      expect(pose.onDot, isFalse, reason: 'it is not empty-handed');
      expect(pose.hands.left.dx, greaterThan(0), reason: 'its hands are on the piece');
    });

    test('walking empty-handed: a smile and swinging arms', () {
      final m = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45)]));
      m.observe(boardOnly(board([ball(10, 10), ball(20, 10)], [player(43, 45)])), 1100);
      final walking = m.poseOf(0, 1, 1100);
      final standing = watching(board([ball(10, 10), ball(20, 10)], [player(43, 45)])).poseOf(0, 1, 1100);
      expect(walking.face, WorkerFace.smile);
      expect(walking.onDot, isTrue, reason: 'empty-handed, on its grab point');
      expect(walking.leanDeg, walkLeanDeg, reason: 'leaning into the walk, to its right');
      expect(walking.hands, isNot(standing.hands), reason: 'the arms swing');
    });

    test('standing empty-handed: a smile, and a blink every few seconds from the clock and the number', () {
      final m = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45), player(60, 45, number: 2)]));
      WorkerFace face(int number, int nowMs) => m.poseOf(0, number, nowMs).face;
      expect(face(1, 0), WorkerFace.smile);
      // Player 1's blink: (nowMs + 1 * blinkStaggerMs) % blinkPeriodMs < 150.
      expect(face(1, 2800), WorkerFace.blink, reason: '2800 + 700 is a whole period');
      expect(face(1, 3000), WorkerFace.smile, reason: '200 ms into the period');
      // Player 2's is one stagger later: (nowMs + 1400) % 3500 < 150.
      expect(face(2, 2100), WorkerFace.blink, reason: '2100 + 1400 is a whole period');
      expect(face(2, 2800), WorkerFace.smile);
      // The same board and clock give the same blink on a second view: it is
      // worked out from the numbers, never from Random.
      final again = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45), player(60, 45, number: 2)]));
      expect(again.poseOf(0, 1, 2800).face, WorkerFace.blink);
    });
  });

  group('the moments in order', () {
    test('a right drop beats carrying', () {
      // Piece 0 is dropped right while the player already holds piece 1.
      final m = watching(board([crate(60, 45), ball(30, 20)], [player(60, 45, held: 0)]));
      m.observe(
        boardOnly(
          board(
            [
              crate(60, 45, state: PieceState.locked, holders: const []),
              ball(30, 20, state: PieceState.held, holders: const [1]),
            ],
            [player(30, 20, held: 1)],
          ),
        ),
        1200,
      );
      expect(m.poseOf(0, 1, 1200).face, WorkerFace.happy, reason: 'the drop it just made, not the piece in its hands');
    });

    test('a view built mid-round fires no moment on its first snapshot', () {
      // The piece is already locked when the view is first built: no grin, just
      // the pose of a player standing there empty-handed.
      final m = watching(
        board([crate(60, 45, state: PieceState.locked, holders: const []), ball(10, 10)], [player(60, 45)]),
      );
      expect(m.poseOf(0, 1, 1000).face, isNot(WorkerFace.happy));
      expect(m.poseOf(0, 1, 1000).face, isNot(WorkerFace.oops));
    });
  });

  group('where the body sits', () {
    test('empty-handed: on the grab point, with the body above it so the ring shows', () {
      final pose = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45)])).poseOf(0, 1, 1000);
      expect(pose.at, const Offset(40, 45));
      expect(pose.away, const Offset(0, -1));
      expect(pose.onDot, isTrue);
    });

    test('carrying: on the piece\'s edge, on the ray from its middle through the dot', () {
      // The crate is 10 x 10 about (60, 45) and the dot is 3 from its middle,
      // so the body stands on its left edge.
      final pose = watching(board([crate(60, 45), ball(10, 10)], [player(57, 45, held: 0)])).poseOf(0, 1, 1000);
      expect(pose.onDot, isFalse);
      expect(pose.at, const Offset(55, 45));
      expect(pose.away, const Offset(-1, 0));
    });

    test('carrying a small piece: its dot is its middle, so the worker stands on the edge it set off from', () {
      final m = watching(
        board(
          [
            crate(0, 0, state: PieceState.tray, holders: const []),
            ball(40, 45, state: PieceState.held, holders: const [1]),
          ],
          [player(40, 45, held: 1)],
        ),
      );
      m.observe(
        boardOnly(
          board(
            [
              crate(0, 0, state: PieceState.tray, holders: const []),
              ball(43, 45, state: PieceState.held, holders: const [1]),
            ],
            [player(43, 45, held: 1)],
          ),
        ),
        1100,
      );
      final pose = m.poseOf(0, 1, 1100);
      expect(pose.at, const Offset(38, 45), reason: 'the ball is 5 in radius, and the worker walked right');
      expect(pose.away, const Offset(-1, 0));
    });
  });

  test('with the effects off nothing hops, shakes, blinks or leans', () {
    final m = watching(board([crate(60, 45), ball(10, 10)], [player(55, 45, held: 0)]));
    m.observe(boardOnly(board([crate(62, 45), ball(10, 10)], [player(57, 45, held: 0)])), 1100);
    final pushing = m.poseOf(0, 1, 1100, effects: false);
    expect(pushing.face, WorkerFace.effort, reason: 'the pose still says what the worker is doing');
    expect(pushing.leanDeg, 0);
    expect(pushing.motion, Offset.zero);

    final dropped = watching(board([crate(60, 45), ball(10, 10)], [player(60, 45, held: 0)]));
    dropped.observe(
      boardOnly(board([crate(60, 45, state: PieceState.locked, holders: const []), ball(10, 10)], [player(60, 45)])),
      1200,
    );
    final happy = dropped.poseOf(0, 1, 1200, effects: false);
    expect(happy.face, WorkerFace.happy, reason: 'the grin stays');
    expect(happy.motion, Offset.zero, reason: 'the hop does not');

    final still = watching(board([ball(10, 10), ball(20, 10)], [player(40, 45)]));
    expect(still.poseOf(0, 1, 2800, effects: false).face, WorkerFace.smile, reason: 'no blink');
  });
}
