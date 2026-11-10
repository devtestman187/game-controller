import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/cat_run.dart';
import 'support/match_helpers.dart';

/// What the cat adds to the frames and the settings (M14 a2): its `cat` key
/// while it is out, each board's side (`sd`), the points line a phone's panel
/// gets in a night, and the Chaos and points-scale settings. The cat's own
/// rules are `cat_test.dart`.
void main() {
  /// A board of [puzzle] with every piece in its tray, for a hand-built frame.
  PuzzleSnapshot board(Puzzle puzzle, {int points = 0, bool night = false, PuzzleSide? side}) => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: 60000,
    phase: PuzzlePhase.playing,
    pieces: [
      for (var i = 0; i < puzzle.pieces.length; i++) const PieceView(x: 120, y: 25, angle: 0, state: PieceState.tray),
    ],
    players: const [],
    points: points,
    night: night,
    side: side,
  );

  test('the cat rides in the frame while it is out, and a frame without it means no cat', () {
    final w = Watch(catRace(flatWorld(), chaos: Chaos.little));
    expect(w.match.snapshot().cat, isNull);
    expect(w.match.snapshot().toJson().containsKey('cat'), isFalse);
    expect(w.catComes(), isTrue);
    final frame = w.match.snapshot();
    final cat = frame.cat!;
    expect(cat.state, CatState.warning);
    expect(cat.side, w.starts.single.side);
    expect(cat.target, isNotNull);
    expect(cat.warningMs, 2000);
    final back = MatchSnapshot.decode(frame.encode()).cat;
    expect(back, isNotNull);
    expect(back!.toJson(), cat.toJson(), reason: 'the cat comes back as it went out');
    expect(back.state, cat.state);
    expect(back.side, cat.side);
    expect(back.target, cat.target);
    expect(back.warningMs, cat.warningMs);
    expect(back.at.dx, closeTo(cat.at.dx, 0.1));
    expect(back.at.dy, closeTo(cat.at.dy, 0.1));
  });

  test('a frame of four players, the most pop-ups and the cat stays under 2048 bytes', () {
    final puzzle = load('boat');
    final m = begin(puzzle, const {
      'p1': PuzzleSide.left,
      'p2': PuzzleSide.left,
      'p3': PuzzleSide.right,
      'p4': PuzzleSide.right,
    }, settings: const PuzzleSettings(night: true));
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
        for (final b in m.snapshot().boards)
          PuzzleSnapshot(
            puzzleId: b.puzzleId,
            timeLeftMs: b.timeLeftMs,
            phase: b.phase,
            pieces: b.pieces,
            players: b.players,
            order: b.order,
            readyTargets: b.readyTargets,
            hintTargets: b.hintTargets,
            points: 199,
            night: true,
            side: b.side,
            popups: most,
          ),
      ],
      seed: 7,
      cat: const CatView(
        state: CatState.walk,
        side: PuzzleSide.right,
        at: Offset(123.4, 56.7),
        target: 5,
        warningMs: 0,
      ),
    );
    final bytes = snapshot.encode().length;
    // The number the report quotes.
    debugPrint('A 4-player night match with ${most.length} pop-ups a side and the cat is $bytes bytes');
    expect(bytes, lessThan(PuzzleSnapshot.maxBytes));
  });

  test('each board says its side, and the match\'s points read them', () {
    final official = MatchSnapshot(
      boards: [
        board(load('house'), points: 3, side: PuzzleSide.right),
        board(load('house'), points: 5, side: PuzzleSide.left),
      ],
      seed: 7,
    );
    expect(official.points, {PuzzleSide.right: 3, PuzzleSide.left: 5}, reason: 'the sides, not the boards\' order');
    final back = MatchSnapshot.decode(official.encode());
    expect(back.boards.map((b) => b.side), [PuzzleSide.right, PuzzleSide.left]);
    expect(back.points, {PuzzleSide.right: 3, PuzzleSide.left: 5});
    // A board built before a2 has no side: it is the side of its place.
    final bare = MatchSnapshot(boards: [board(load('house'), points: 3), board(load('house'), points: 5)], seed: 7);
    expect(bare.points, {PuzzleSide.left: 3, PuzzleSide.right: 5});
  });

  test('a one-board round that plays for the right says so in its board', () {
    final m = begin(twoSquares(), const {'p1': PuzzleSide.right});
    final snap = m.snapshot();
    expect(snap.boards.single.side, PuzzleSide.right);
    expect(snap.points, {PuzzleSide.right: 0});
    expect(MatchSnapshot.decode(snap.encode()).boards.single.side, PuzzleSide.right);
    final race = begin(twoSquares(), const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    expect(race.snapshot().boards.map((b) => b.side), [PuzzleSide.left, PuzzleSide.right]);
  });

  test('an out-of-range pointsScale is refused like the clock is', () {
    expect(PuzzleSettings.fromJson({'pointsScale': 9}).pointsScale, 4);
    expect(PuzzleSettings.fromJson({'pointsScale': 0}).pointsScale, 1);
    expect(PuzzleSettings.fromJson({'pointsScale': 2}).pointsScale, 2);
    expect(PuzzleSettings.defaults.withValue('pointsScale', 9).pointsScale, 4);
  });

  test('the Chaos setting travels as its name, and a name this build doesn\'t know is Off', () {
    for (final chaos in Chaos.values) {
      expect(PuzzleSettings.fromJson(PuzzleSettings(chaos: chaos).toJson()).chaos, chaos);
    }
    expect(PuzzleSettings.defaults.chaos, Chaos.off, reason: 'a build without a host saves plays without the cat');
    expect(PuzzleSettings.fromJson({'chaos': 'wild'}).chaos, Chaos.off);
  });

  test('the phone panel shows the points line only in a night, and the camera reserves it', () {
    const box = Size(667, 375);
    final puzzle = load('house');
    final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
    final m = PuzzleMatch(
      puzzle,
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      random: Random(1),
      target: LayoutTarget.phones,
    );
    MatchSnapshot at({required bool night, int points = 0}) => MatchSnapshot(
      boards: [
        for (final (i, b) in m.snapshot().boards.indexed)
          PuzzleSnapshot(
            puzzleId: b.puzzleId,
            timeLeftMs: b.timeLeftMs,
            phase: b.phase,
            pieces: b.pieces,
            players: b.players,
            order: b.order,
            points: i == 0 ? points : 0,
            night: night,
            side: b.side,
          ),
      ],
      seed: m.seed,
    );

    final plain = at(night: false, points: 7);
    expect(phoneHud(plain, PuzzleSide.left).score, isNot(contains('pts')));
    expect(phoneHud(plain, PuzzleSide.left).short.any((line) => line.contains('pts')), isFalse);
    final night = at(night: true, points: 7);
    final hud = phoneHud(night, PuzzleSide.left);
    expect(hud.short.last, '7 pts', reason: 'one line more for the short form');
    expect(hud.score, endsWith(' · 7 pts'));
    expect(phoneHud(night, null).short.last, '7 · 0 pts', reason: 'the whole match names both sides');

    const camera = PuzzleCamera.side(PuzzleSide.left);
    ({String score, List<String> short}) text(MatchSnapshot s) {
      final shown = phoneHud(s, PuzzleSide.left);
      return (score: shown.score, short: shown.short);
    }

    final laid = PuzzleCamera.hudPlace(layout, camera, box, text(night));
    final tall = PuzzleCamera.hudPlace(layout, camera, box, text(plain));
    expect(laid.form, HudForm.short);
    expect(tall.form, HudForm.short);
    final line = PuzzleCamera.hudUnit(box) * (PuzzleCamera.hudScoreFraction + PuzzleCamera.hudLineGapFraction);
    expect(laid.rect.height - tall.rect.height, closeTo(line, 0.5), reason: 'the reserved line is the points\'');
  });
}
