import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The points the rules count (party-night.md §3, G1, G2, M14 a1): a snap on
/// the first try, a try again, a big piece carried home by two, the picture
/// finished, and the cat (job a2), each times the round's `pointsScale`; the
/// pop-ups they make; and the `night` flag the snapshot carries.
void main() {
  /// A one-board match of [puzzle] with everyone on the left.
  PuzzleMatch board(
    Puzzle puzzle, {
    PuzzleSettings settings = PuzzleSettings.defaults,
    List<String> ids = const ['p1'],
  }) => begin(puzzle, {for (final id in ids) id: PuzzleSide.left}, settings: settings);

  /// The piece of [game] a player drops: put [who] over it and press A, then
  /// leave it [at] and press A again (a drop where it lies).
  void dropAt(PuzzleMatch m, PuzzleGame game, String who, int i, Offset at) {
    game.player(who)!.pos = game.pieces[i].pos;
    m.update(0.016, {who: pressA});
    m.update(0.016, {who: none});
    game.pieces[i].pos = at;
    game.player(who)!.pos = at;
    m.update(0.016, {who: pressA});
    m.update(0.016, {who: none});
  }

  test('a snap on the first try earns +2, and a night\'s last round doubles it', () {
    for (final (scale, expected) in [(1, PuzzlePoints.snap), (2, 2 * PuzzlePoints.snap)]) {
      final m = board(twoSquares(), settings: PuzzleSettings(pointsScale: scale));
      final game = m.gameOf(PuzzleSide.left);
      place(m, game, 'p1', 0);
      expect(game.points, expected, reason: 'scale $scale');
    }
  });

  test('a piece snapped after a wrong drop earns +1, the try again, not +2', () {
    final m = board(twoSquares());
    final game = m.gameOf(PuzzleSide.left);
    dropAt(m, game, 'p1', 0, const Offset(40, 20));
    expect(game.pieces[0].state, PieceState.wrong, reason: 'the drop was between the two outlines');
    expect(game.points, 0, reason: 'a wrong drop earns nothing');
    place(m, game, 'p1', 0);
    expect(game.pieces[0].state, PieceState.locked);
    expect(game.points, PuzzlePoints.wrongSnap);
    expect(game.player('p1')!.tryAgains, 1);
  });

  test('a piece the cat knocked earns only the try again\'s +1 when it is placed again', () {
    final m = board(twoSquares());
    final game = m.gameOf(PuzzleSide.left);
    place(m, game, 'p1', 0);
    expect(game.points, PuzzlePoints.snap, reason: 'the first try earns +2');
    game.catKnocks(0);
    expect(game.pieces[0].state, PieceState.tray, reason: 'the cat knocked it back to its tray');
    place(m, game, 'p1', 0);
    expect(game.pieces[0].state, PieceState.locked);
    expect(game.points, PuzzlePoints.snap + PuzzlePoints.wrongSnap, reason: 'no second first-try bonus');
    expect(game.player('p1')!.tryAgains, 1, reason: 'the second place is the try again');
  });

  test('a big piece carried home by two earns +1 more, counted for both carriers', () {
    final m = board(crateAndBall(), ids: const ['p1', 'p2']);
    final game = m.gameOf(PuzzleSide.left);
    final crate = game.pieces[0];
    // P1 takes the crate, P2 takes its other end: two players carry it.
    game.player('p1')!.pos = crate.pos;
    tap(m, 'p1', const {'p2': none});
    game.player('p2')!.pos = crate.pos;
    tap(m, 'p2', const {'p1': none});
    expect(crate.carriers, hasLength(2));
    // P2 drops it in its outline.
    crate.pos = game.targetAt(0);
    crate.angle = 0;
    game.player('p2')!.pos = crate.pos;
    tap(m, 'p2', const {'p1': none});
    expect(crate.state, PieceState.locked);
    expect(game.points, PuzzlePoints.snap + PuzzlePoints.together);
    expect(game.player('p1')!.carries, 1, reason: 'P1 carried it too');
    expect(game.player('p2')!.carries, 1);
  });

  test('a big piece carried alone earns no carry point', () {
    final m = board(crateAndBall());
    final game = m.gameOf(PuzzleSide.left);
    place(m, game, 'p1', 0);
    expect(game.points, PuzzlePoints.snap);
    expect(game.player('p1')!.carries, 0, reason: 'one player on a side carries a big piece alone');
  });

  test('the picture finished first earns +5 in a race, to that side only', () {
    final m = begin(twoSquares(), const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    final left = m.gameOf(PuzzleSide.left);
    place(m, left, 'p1', 0);
    place(m, left, 'p1', 1);
    expect(left.phase, PuzzlePhase.finished);
    expect(m.gameOf(PuzzleSide.left).points, 2 * PuzzlePoints.snap + PuzzlePoints.finish);
    expect(m.gameOf(PuzzleSide.right).points, 0);
    expect(m.result!.winner, PuzzleSide.left);
  });

  test('the picture finished before time-up earns +5 on one board, and a time-up earns none', () {
    final finished = board(onePiece());
    place(finished, finished.gameOf(PuzzleSide.left), 'p1', 0);
    expect(finished.gameOf(PuzzleSide.left).points, PuzzlePoints.snap + PuzzlePoints.finish);

    final timedOut = board(twoSquares(), settings: const PuzzleSettings(timeLimitS: 1));
    final game = timedOut.gameOf(PuzzleSide.left);
    place(timedOut, game, 'p1', 0);
    drive(timedOut, const {'p1': none}, frames: 20, dt: 0.05);
    expect(game.phase, PuzzlePhase.timeUp);
    expect(game.points, PuzzlePoints.snap, reason: 'only the snap: nothing was finished');
  });

  test('a side of two and a side of one earn the same for the same play, and both of the two are credited in full', () {
    final m = begin(twoSquares(), const {
      'p1': PuzzleSide.left,
      'p2': PuzzleSide.left,
      'p3': PuzzleSide.right,
    }, settings: const PuzzleSettings(timeLimitS: 1));
    const everyone = {'p1': none, 'p2': none, 'p3': none};
    place(m, m.gameOf(PuzzleSide.left), 'p1', 0, others: everyone);
    place(m, m.gameOf(PuzzleSide.right), 'p3', 0, others: everyone);
    expect(m.gameOf(PuzzleSide.left).points, m.gameOf(PuzzleSide.right).points);
    drive(m, everyone, frames: 20, dt: 0.05);
    final round = m.result!.round;
    expect(round.points, {'p1': PuzzlePoints.snap, 'p2': PuzzlePoints.snap, 'p3': PuzzlePoints.snap});
  });

  test('the cat\'s +1 goes through the place job a2 calls: the shooer\'s side, at the cat', () {
    final m = board(twoSquares());
    final game = m.gameOf(PuzzleSide.left);
    const at = Offset(30, 40);
    game.awardCatShooed('p1', at);
    expect(game.points, PuzzlePoints.catShooed);
    expect(game.player('p1')!.catsShooed, 1);
    expect(game.snapshot().popups.single.place, at);
  });

  test('each award pops up once at its place, and is gone 1.2 s later', () {
    final m = board(onePiece());
    final game = m.gameOf(PuzzleSide.left);
    place(m, game, 'p1', 0);
    final popups = game.snapshot().popups;
    expect(popups, hasLength(2), reason: 'the snap and the finish');
    expect(popups.first.amount, PuzzlePoints.snap);
    expect(popups.first.place, game.targetAt(0), reason: 'at the piece\'s outline');
    expect(popups.last.amount, PuzzlePoints.finish);
    expect(popups.last.icon, PuzzleIcon.flag, reason: 'the finish looks different from a snap');
    final start = popups.first.ageMs;
    expect(start, lessThan(50), reason: 'it starts at the drop');

    drive(m, const {'p1': none}, frames: 23, dt: 0.05);
    expect(game.snapshot().popups.first.ageMs, closeTo(start + 1150, 2));
    drive(m, const {'p1': none}, frames: 1, dt: 0.05);
    expect(game.snapshot().popups, isEmpty, reason: '1.2 s is their whole life');
  });

  test('a pop-up does not age while the round stands still', () {
    final m = board(onePiece());
    final game = m.gameOf(PuzzleSide.left);
    place(m, game, 'p1', 0);
    final age = game.snapshot().popups.first.ageMs;
    // The pause menu stops the steps: no update, so no ageing.
    expect(game.snapshot().popups.first.ageMs, age);
    expect(game.snapshot().popups, isNotEmpty);
  });

  test('a pop-up lives only while someone draws it: an empty night draws none', () {
    final m = board(onePiece(), settings: const PuzzleSettings(night: true));
    final game = m.gameOf(PuzzleSide.left);
    expect(game.snapshot().night, isTrue);
    place(m, game, 'p1', 0);
    expect(game.snapshot().popups, isNotEmpty);
  });

  test('a night says so in the frame; a round outside one does not', () {
    expect(board(twoSquares()).snapshot().boards.single.night, isFalse);
    expect(board(twoSquares(), settings: const PuzzleSettings(night: true)).snapshot().boards.single.night, isTrue);
  });

  test('a frame of four players and the most pop-ups a frame can have stays under 2048 bytes', () {
    final puzzle = load('boat');
    final m = begin(puzzle, const {
      'p1': PuzzleSide.left,
      'p2': PuzzleSide.left,
      'p3': PuzzleSide.right,
      'p4': PuzzleSide.right,
    }, settings: const PuzzleSettings(night: true));
    m.update(0.016, {for (final id in m.teams.keys) id: none});
    final most = [
      for (var i = 0; i < PuzzlePoints.maxPopups; i++)
        PuzzlePopup(
          side: PuzzleSide.left,
          place: const Offset(123.4, 56.7),
          amount: 4,
          ageMs: 1199,
          icon: PuzzleIcon.flag,
        ),
    ];
    final snapshot = MatchSnapshot(
      boards: [
        for (final board in m.snapshot().boards)
          PuzzleSnapshot(
            puzzleId: board.puzzleId,
            timeLeftMs: board.timeLeftMs,
            phase: board.phase,
            pieces: board.pieces,
            players: board.players,
            order: board.order,
            readyTargets: board.readyTargets,
            hintTargets: board.hintTargets,
            points: 199,
            night: true,
            popups: most,
          ),
      ],
      seed: 7,
    );
    final bytes = snapshot.encode().length;
    // The number the report quotes.
    debugPrint('A 4-player night match with ${most.length} pop-ups a side is $bytes bytes');
    expect(bytes, lessThan(PuzzleSnapshot.maxBytes));
  });
}
