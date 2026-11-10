import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/cat_run.dart';
import 'support/match_helpers.dart';

/// The cat (PRD v2 G3, M14 a2): when it comes, which side it visits and which
/// piece it is after, what it does to it, and how a shoo sends it off. The
/// frame it rides in and the phone's points line are `cat_snapshot_test.dart`
/// and `cat_paint_test.dart`.
void main() {
  /// A press of A by p1, standing on the cat, with p2 standing still.
  List<({PuzzleSide side, PuzzleEvent event})> shooIt(Watch w) {
    final m = w.match;
    m.gameOf(PuzzleSide.left).player('p1')!.pos = m.cat!.at;
    return tap(m, 'p1', const {'p2': none});
  }

  /// The left side, ahead by a piece, and the cat's visit to it: p1 put piece
  /// 0 home, so the left side leads 1–0 and the cat comes to warn p1.
  Watch visitingLeft(Chaos chaos, {int pointsScale = 1}) {
    final m = catRace(flatWorld(), chaos: chaos, pointsScale: pointsScale);
    put(m, m.gameOf(PuzzleSide.left), 'p1', 0);
    final w = Watch(m);
    expect(w.catComes(), isTrue, reason: 'the cat comes to the side ahead');
    expect(w.starts.single.side, PuzzleSide.left);
    return w;
  }

  test('the warning comes 2 s before the bat, on the piece the cat bats', () {
    final w = Watch(catRace(flatWorld(), chaos: Chaos.little));
    expect(w.catComes(), isTrue);
    expect(w.cat!.state, CatState.warning);
    expect(w.cat!.warningMs, 2000, reason: 'the whole 2 s warning is left at the meow');
    final start = w.starts.single;
    expect(w.batsOne(), isTrue);
    final bat = w.bats.single;
    expect(bat.at - start.at, greaterThanOrEqualTo(CatRules.warningS));
    expect(bat.piece, start.piece, reason: 'it bats the piece whose shadow it cast');
  });

  test('the cat goes to the side ahead in pieces placed', () {
    final m = catRace(flatWorld(), chaos: Chaos.little);
    put(m, m.gameOf(PuzzleSide.right), 'p2', 0);
    final w = Watch(m);
    expect(w.catComes(), isTrue);
    expect(w.starts.single.side, PuzzleSide.right, reason: 'p2 is a piece ahead');
  });

  test('on a draw the cat may go either way, and never the same side twice in a row', () {
    final w = Watch(catRace(flatWorld()));
    w.toTheEnd();
    expect(w.starts, hasLength(2), reason: 'Party comes twice in a 40 s round');
    expect(w.starts.map((s) => s.side).toSet(), hasLength(2), reason: 'a draw leaves both sides, and it never repeats');
  });

  test('the cat never comes in the first 20 s or the last 10 s', () {
    final w = Watch(catRace(flatWorld()));
    w.toTheEnd();
    expect(w.starts, isNotEmpty);
    for (final start in w.starts) {
      expect(start.at, greaterThanOrEqualTo(CatRules.graceS));
      expect(start.at + CatRules.visitS, lessThanOrEqualTo(40 - CatRules.tailS + Watch.dt));
    }
  });

  test('A little comes once a round, bats a loose or tray piece, and never a placed one', () {
    final m = catRace(flatWorld(), chaos: Chaos.little);
    final left = m.gameOf(PuzzleSide.left);
    put(m, left, 'p1', 0);
    final w = Watch(m);
    w.toTheEnd();
    expect(w.starts, hasLength(1), reason: 'A little comes once a round');
    expect(w.bats, hasLength(1));
    expect(w.bats.single.knocked, isFalse);
    expect(left.pieces[0].state, PieceState.locked, reason: 'a placed piece is left where it is');

    final index = m.puzzle.pieces.indexWhere((p) => p.id == w.bats.single.piece);
    final piece = left.pieces[index];
    final box = scaledBounds(m.puzzle.pieces[index].shape, piece.angle, 1.0).shift(piece.pos);
    expect(piece.state, PieceState.loose, reason: 'it came out of the tray');
    expect(piece.pos, isNot(piece.trayPos), reason: 'it went to another spot on that side');
    expect(box.left, greaterThanOrEqualTo(-0.01));
    expect(box.top, greaterThanOrEqualTo(left.field.top - 0.01));
    expect(box.right, lessThanOrEqualTo(left.field.size.width + 0.01));
    expect(box.bottom, lessThanOrEqualTo(left.field.size.height + 0.01));
    for (final spec in m.puzzle.pieces) {
      final outline = scaledBounds(spec.shape, spec.targetAngle, 1.0).shift(left.field.origin + spec.target);
      expect(box.overlaps(outline), isFalse, reason: 'a bat never drops a piece into the answer');
    }
  });

  test('Party knocks one placed piece of the side ahead back to its tray, and the side keeps its points', () {
    final m = catRace(flatWorld());
    final left = m.gameOf(PuzzleSide.left);
    put(m, left, 'p1', 0);
    put(m, left, 'p1', 1);
    final outline = left.pieces[1].lockedTarget!;
    final points = left.points;
    final w = Watch(m);
    expect(w.catComes(), isTrue);
    expect(w.starts.single.side, PuzzleSide.left);
    expect(m.cat!.target, 1, reason: 'its shadow is on the piece placed last');
    expect(w.batsOne(), isTrue);
    expect(w.bats.single.knocked, isTrue);
    expect(left.pieces[1].state, PieceState.tray, reason: 'back to its tray spot');
    expect(left.pieces[1].pos, left.pieces[1].trayPos);
    expect(left.points, points, reason: 'the side keeps the points it placed');
    expect(left.snapshot().hintTargets, contains(outline), reason: 'its outline glows in the tray');
    w.toTheEnd();
    expect(w.bats.where((b) => b.knocked), hasLength(1), reason: 'it knocks a piece loose once a round');
  });

  test('Party leaves the picture\'s last piece alone', () {
    final m = catRace(flatWorld());
    final left = m.gameOf(PuzzleSide.left);
    for (final i in [0, 1, 2]) {
      put(m, left, 'p1', i);
    }
    final w = Watch(m);
    expect(w.catComes(), isTrue);
    expect(w.cat!.target, 3, reason: 'the one piece still in the tray');
    w.toTheEnd();
    expect(left.placed, 3, reason: 'knocking one of these would take the picture from the side');
    expect(w.bats.where((b) => b.knocked), isEmpty);
  });

  test('Party takes an older placed piece and leaves one placed in the last 3 s', () {
    // The plan comes from the seed alone, so a first run finds the visit's
    // time and the second plays the same round with pieces placed around it.
    final probe = Watch(catRace(flatWorld()));
    expect(probe.catComes(), isTrue);
    final when = probe.starts.single.at;

    final m = catRace(flatWorld());
    final left = m.gameOf(PuzzleSide.left);
    final w = Watch(m);
    w.to(when - 6);
    put(m, left, 'p1', 0);
    w.to(when - 1);
    put(m, left, 'p1', 1);
    expect(w.catComes(), isTrue);
    expect(w.starts.single.side, PuzzleSide.left);
    expect(m.cat!.target, 0, reason: 'the newest piece that has settled for 3 s');
    expect(w.batsOne(), isTrue);
    expect(left.pieces[0].state, PieceState.tray);
    expect(left.pieces[1].state, PieceState.locked, reason: 'a piece placed a second ago is left alone');
  });

  test('a one-board round keeps every placed piece', () {
    final m = catSolo(flatWorld());
    final game = m.gameOf(PuzzleSide.left);
    put(m, game, 'p1', 0);
    put(m, game, 'p1', 1);
    final w = Watch(m);
    w.toTheEnd();
    expect(w.starts, isNotEmpty, reason: 'the cat visits the one board');
    expect(game.placed, 2);
    expect(w.bats.where((b) => b.knocked), isEmpty);
  });

  test('Chaos off never brings the cat', () {
    final m = catRace(twoSquares(), chaos: Chaos.off);
    final w = Watch(m);
    w.to(30);
    expect(m.cat, isNull);
    w.toTheEnd();
    expect(w.starts, isEmpty);
    expect(m.snapshot().cat, isNull);
  });

  test('a shoo during the warning always works, and the cat stays away for the round', () {
    final w = visitingLeft(Chaos.party);
    expect(w.cat!.state, CatState.warning);
    final at = w.cat!.at;
    final events = shooIt(w);
    expect(
      events.any((e) => e.event.kind == PuzzleEventKind.catShooed && e.event.playerId == 'p1'),
      isTrue,
      reason: 'the shoo is p1\'s',
    );
    expect(w.cat!.state, CatState.leave);
    expect(w.cat!.at, offsetMoreOrLessEquals(at, epsilon: 0.2), reason: 'it runs off from where it stood');
    expect(w.batsOne(), isFalse);
    expect(w.match.cat, isNull, reason: 'no visit is left to come');
    expect(w.starts, hasLength(1), reason: 'Party\'s second visit never comes');
  });

  test('a shoo during the walk works too', () {
    final w = visitingLeft(Chaos.little);
    expect(w.until(() => w.match.cat?.state == CatState.walk), isTrue);
    shooIt(w);
    expect(w.cat!.state, CatState.leave);
    expect(w.match.gameOf(PuzzleSide.left).player('p1')!.catsShooed, 1);
    expect(w.bats, isEmpty, reason: 'it went before it batted');
  });

  test('a shoo earns the shooer\'s side +1, more at a night\'s last round, with a pop-up', () {
    for (final (scale, expected) in [(1, PuzzlePoints.catShooed), (2, 2 * PuzzlePoints.catShooed)]) {
      final w = visitingLeft(Chaos.little, pointsScale: scale);
      final left = w.match.gameOf(PuzzleSide.left);
      final before = left.points;
      final at = w.cat!.at;
      shooIt(w);
      expect(left.points, before + expected, reason: 'scale $scale');
      expect(left.player('p1')!.catsShooed, 1);
      final popup = left.snapshot().popups.last;
      expect(popup.amount, expected);
      expect(popup.place, at, reason: 'it pops up where the cat was');
    }
  });

  test('the shooer\'s catsShooed counts in the round\'s stats', () {
    final w = visitingLeft(Chaos.little);
    shooIt(w);
    w.toTheEnd();
    final stats = w.match.result!.round.stats;
    expect(stats['p1']!['catsShooed'], 1);
    expect(stats['p2']!['catsShooed'], 0, reason: 'p2 never shooed it');
  });

  test('A on the cat shoos rather than picking a piece up', () {
    final w = visitingLeft(Chaos.little);
    final left = w.match.gameOf(PuzzleSide.left);
    left.player('p1')!.pos = w.cat!.at;
    left.pieces[2].pos = w.cat!.at;
    final events = tap(w.match, 'p1', const {'p2': none});
    expect(left.player('p1')!.held, isNull, reason: 'no piece came up');
    expect(left.pieces[2].state, PieceState.tray);
    expect(events.any((e) => e.event.kind == PuzzleEventKind.pickup), isFalse);
    expect(left.player('p1')!.catsShooed, 1);
  });

  test('the cat\'s clock stands still while the round does', () {
    final w = visitingLeft(Chaos.little);
    final game = w.match.gameOf(PuzzleSide.left);
    final warning = w.cat!.warningMs;
    final elapsed = game.elapsedS;
    for (var i = 0; i < 10; i++) {
      w.match.update(0, w.inputs);
    }
    expect(w.cat!.warningMs, warning);
    expect(w.cat!.state, CatState.warning);
    expect(game.elapsedS, elapsed);
    w.step();
    expect(w.cat!.warningMs, warning - 50, reason: 'a 0.05 s frame is 50 ms off its warning');
  });

  test('the same seed gives the same cat, frame for frame', () {
    final a = Watch(catRace(flatWorld()));
    final b = Watch(catRace(flatWorld()));
    a.toTheEnd();
    b.toTheEnd();
    expect(a.starts, isNotEmpty);
    expect(b.starts, a.starts);
    expect(b.bats, a.bats);
  });
}
