import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';
import 'support/look.dart' show sunny;
import 'support/mirror_helpers.dart';

void main() {
  final tree = load('tree');
  final layout = SplitLayout.of(tree, 1, target: LayoutTarget.phones);

  group('what the mirror draws', () {
    late MirrorPlacement mirror;
    late Puzzle puzzle;

    setUpAll(() {
      puzzle = tree;
      mirror = mirrorOf(tree, iphone)!;
    });

    Future<(int, Uint8List)> frame(WidgetTester tester, MatchSnapshot s) async {
      final (width, _, bytes) = await capture(
        tester,
        MatchView(puzzle: puzzle, snapshot: s, timeLimitS: 65, target: LayoutTarget.phones, camera: sideLeft),
        window: iphone,
        box: iphone,
      );
      return (width, bytes);
    }

    /// The world point of a board unit position, as the puzzle's data has it.
    Offset world(Offset boardUnit) => layout.left.origin + boardUnit;

    /// Where the mirror draws the board unit position [boardUnit].
    Offset at(Offset boardUnit) => mirrorPoint(layout, mirror.rect, mirror.scale, world(boardUnit));

    testWidgets('their placed pieces are drawn in it, in their colours', (tester) async {
      final crown = puzzle.pieces.indexWhere((p) => p.id == 'crown');
      final theirs = [
        for (final (i, spec) in puzzle.pieces.indexed)
          PieceView(
            x: i == crown ? world(spec.target).dx : 10,
            y: i == crown ? world(spec.target).dy : 10,
            angle: spec.targetAngle,
            state: i == crown ? PieceState.locked : PieceState.tray,
          ),
      ];
      final (width, bytes) = await frame(
        tester,
        raceOf(puzzle, theirs: theirs, them: const [PlayerView(number: 2, x: 10, y: 50)]),
      );
      final where = at(const Offset(26, 40));
      expect(pixel(bytes, width, where.dx.round(), where.dy.round()), 0x27AE60, reason: 'the crown they placed');
      // The parts of their board with nothing in them show the panel: below
      // their dot, which is now as big as the smallest piece (N3) and covers
      // the corner this used to read (18, 22). It is the look's board colour.
      final empty = at(const Offset(18, 60));
      expect(pixel(bytes, width, empty.dx.round(), empty.dy.round()), boardPanel);
    });

    testWidgets('their dot is drawn in it at its place on the board', (tester) async {
      final place = world(const Offset(26, 40));
      final (width, bytes) = await frame(
        tester,
        raceOf(
          puzzle,
          theirs: trayOf(puzzle),
          them: [PlayerView(number: 2, x: place.dx, y: place.dy)],
        ),
      );
      final dot = at(const Offset(26, 40));
      expect(pixel(bytes, width, dot.dx.round(), dot.dy.round()), them);
      // 10 board units away it is the board, not the dot.
      final away = at(const Offset(36, 40));
      expect(pixel(bytes, width, away.dx.round(), away.dy.round()), isNot(them));
    });

    testWidgets('their dot is drawn at least mirrorMinPieceMm across on every phone', (tester) async {
      // The floor in px on a phone is 2.2 mm x 160/25.4 = 13.86 px. At
      // PuzzleGame.dotRadius, 2.6 units, the dot is 0.8 to 1.1 mm on these
      // phones (tree at 852: 2 x 2.6 x 0.9972 = 5.19 px); the mirror draws it
      // at the smallest piece's radius instead, so it is as big as the
      // smallest piece the mirror draws — 16 units for the tree, 14 for the
      // house and the boat, 12 for the rocket — which is at or over the floor
      // by mirrorFraction's own choice, with no pxPerMm in the game.
      for (final (id, box) in const [
        ('house', iphone),
        ('rocket', iphone),
        ('tree', iphone),
        ('boat', iphone),
        ('house', phone15),
        ('rocket', phone15),
        ('tree', phone15),
        ('tree', phone169),
      ]) {
        final puzzle = load(id);
        final l = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final mirror = mirrorOf(puzzle, box);
        expect(mirror, isNotNull, reason: '$id at $box');
        // Their dot on the middle of their board: clear of the mirror's frame,
        // whose orange would otherwise join the dot's run.
        final world = l.left.board.center;
        final (width, height, bytes) = await capture(
          tester,
          MatchView(
            puzzle: puzzle,
            snapshot: raceOf(
              puzzle,
              theirs: trayOf(puzzle),
              them: [PlayerView(number: 2, x: world.dx, y: world.dy)],
            ),
            target: LayoutTarget.phones,
            camera: sideLeft,
          ),
          window: box,
          box: box,
          pixelRatio: 2,
        );
        // The dot's width in box px, through its centre: its orange, then its
        // white ring.
        final centre = mirrorPoint(l, mirror!.rect, mirror.scale, world);
        final drawn = dotRun(bytes, width, height, centre) / 2;
        final drawnMm = drawn / pxPerMm;
        final dot = 2 * mirrorDotRadius(puzzle) * mirror.scale;
        expect(drawnMm, greaterThanOrEqualTo(mirrorMinPieceMm), reason: '$id at $box: $drawn px, $drawnMm mm');
        expect(
          drawn,
          closeTo(dot, 2),
          reason: '$id at $box: as big as the smallest piece, less a pixel a side for its ring and antialiasing',
        );
      }
    });

    testWidgets('the mirror\'s orange is the palette\'s other-side colour', (tester) async {
      // Player 2's colour (protocol's playerColors): the frame, every dot and
      // the count beside it are drawn in the palette's orange itself, so a
      // re-skin moves them with the pads' badges (m12-opponent-mirror rule 4).
      final place = world(const Offset(26, 40));
      final (width, bytes) = await frame(
        tester,
        raceOf(
          puzzle,
          theirs: trayOf(puzzle),
          them: [PlayerView(number: 2, x: place.dx, y: place.dy)],
        ),
      );
      final dot = at(const Offset(26, 40));
      expect(pixel(bytes, width, dot.dx.round(), dot.dy.round()), them);
      expect(hasFrame(bytes, width, mirror.rect, colour: them), isTrue);
    });

    testWidgets('placed above the board, their dot is pinned to its top edge at its place', (tester) async {
      // In their tray row, 15 units above the board, 10 units in from its left.
      final board = layout.left.board;
      final above = Offset(board.center.dx, board.top - 15);
      final (width, bytes) = await frame(
        tester,
        raceOf(
          puzzle,
          theirs: trayOf(puzzle),
          them: [PlayerView(number: 2, x: above.dx, y: above.dy)],
        ),
      );
      // Pinned for real: the world x where their dot's centre goes is 10 units
      // right of the board's left, and the dot's radius (the tree's smallest
      // piece, 16 units, halved) below its top, so the whole dot is on the
      // mirror's top edge.
      final r = mirrorDotRadius(puzzle);
      final pinned = mirrorPoint(layout, mirror.rect, mirror.scale, Offset(above.dx, board.top + r));
      expect(pixel(bytes, width, pinned.dx.round(), pinned.dy.round()), them);
      // Its place across the board is its own: 10 units along is the board.
      final along = Offset(pinned.dx + 10, pinned.dy);
      expect(pixel(bytes, width, along.dx.round(), along.dy.round()), isNot(them));
      // Nothing is drawn at its real place, above the mirror.
      expect(pixel(bytes, width, pinned.dx.round(), (mirror.rect.top - 3).round()), isNot(them));
      // And it is not 10 board units lower, where an unpinned dot would be.
      final lower = Offset(pinned.dx, pinned.dy + 15);
      expect(pixel(bytes, width, lower.dx.round(), lower.dy.round()), isNot(them));
    });

    testWidgets('the piece they hold is drawn with their dot, turned as they turn it', (tester) async {
      final trunk = puzzle.pieces.indexWhere((p) => p.id == 'trunk');
      final held = world(const Offset(40, 40));
      Future<int> probe(double angle, Offset boardUnit) async {
        final (width, bytes) = await frame(
          tester,
          raceOf(
            puzzle,
            theirs: [
              for (final (i, spec) in puzzle.pieces.indexed)
                PieceView(
                  x: i == trunk ? held.dx : 10,
                  y: i == trunk ? held.dy : 10,
                  angle: i == trunk ? angle : 0,
                  state: i == trunk ? PieceState.held : PieceState.tray,
                ),
            ],
            them: [PlayerView(number: 2, x: held.dx, y: held.dy, held: trunk)],
          ),
        );
        final where = at(boardUnit);
        return pixel(bytes, width, where.dx.round(), where.dy.round());
      }

      // The trunk is a 8 x 18 board-unit rectangle: 7 units from its centre is
      // inside it upright and outside it on its side. The inside probes are 3
      // units out, where the piece's body is its own colour: nearer its edge is
      // the ink edge the look draws round every piece (M13 4a) and the shade
      // band the fallback body shades it with.
      expect(await probe(0, const Offset(40, 43)), 0x8E5B3A, reason: 'upright: 3 down is still trunk');
      expect(await probe(0, const Offset(47, 40)), isNot(0x8E5B3A), reason: 'upright: 7 across is past it');
      expect(await probe(90, const Offset(43, 40)), 0x8E5B3A, reason: 'turned: 3 across is trunk');
      expect(await probe(90, const Offset(40, 47)), isNot(0x8E5B3A), reason: 'turned: 7 down is past it');
    });

    testWidgets('their finished picture glows while their own board celebrates', (tester) async {
      // The crown placed, and their board seen finishing at 100 ms: the mirror
      // draws the same warm rim their own board does (design 3a item 3, M14 r5
      // 15). Its box is exactly the picture's, so the star ring and the
      // confetti, which fall outside the picture, are the one part of the
      // moment the mirror cannot show.
      final crown = puzzle.pieces.indexWhere((p) => p.id == 'crown');
      final placed = [
        for (final (i, spec) in puzzle.pieces.indexed)
          PieceView(
            x: i == crown ? world(spec.target).dx : 10,
            y: i == crown ? world(spec.target).dy : 10,
            angle: i == crown ? spec.targetAngle : 0,
            state: i == crown ? PieceState.locked : PieceState.tray,
          ),
      ];
      PuzzleSnapshot board(PuzzlePhase phase) => PuzzleSnapshot(
        puzzleId: puzzle.id,
        timeLeftMs: 65000,
        phase: phase,
        pieces: placed,
        players: const [PlayerView(number: 2, x: 30, y: 60)],
      );
      final moments = PieceMoments()
        ..observe(MatchSnapshot(seed: 1, boards: [board(PuzzlePhase.playing), board(PuzzlePhase.playing)]), 0)
        ..observe(MatchSnapshot(seed: 1, boards: [board(PuzzlePhase.playing), board(PuzzlePhase.finished)]), 100);
      Future<Uint8List> frameAt(int nowMs) async {
        final (_, _, bytes) = await capture(
          tester,
          CustomPaint(
            size: iphone,
            painter: _MirrorPaint(
              MirrorPainter(
                puzzle,
                board(PuzzlePhase.finished),
                layout.left,
                look: sunny,
                moments: moments,
                nowMs: nowMs,
                board: 1,
                rect: mirror.rect,
                scale: mirror.scale,
              ),
            ),
          ),
          window: iphone,
          box: iphone,
        );
        return bytes;
      }

      /// The pixels two frames of the same size differ in.
      int changed(Uint8List a, Uint8List b) {
        var n = 0;
        for (var i = 0; i < a.length; i += 4) {
          if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) n++;
        }
        return n;
      }

      final before = await frameAt(60);
      final celebrating = await frameAt(500);
      final over = await frameAt(100 + Celebration.totalMs + 100);
      expect(changed(before, celebrating), greaterThan(10), reason: 'a warm rim round the piece they placed');
      expect(changed(before, over), 0, reason: 'and nothing once the moment is over');
    });

    testWidgets('a 2-v-1 draws every dot of the other side', (tester) async {
      const places = [Offset(26, 40), Offset(60, 60)];
      final (width, bytes) = await frame(
        tester,
        raceOf(
          puzzle,
          theirs: trayOf(puzzle),
          them: [
            for (final (i, place) in places.indexed) PlayerView(number: 3 + i, x: world(place).dx, y: world(place).dy),
          ],
        ),
      );
      for (final boardUnit in places) {
        final where = at(boardUnit);
        expect(pixel(bytes, width, where.dx.round(), where.dy.round()), them, reason: '$boardUnit');
      }
    });
  });

  group('no mirror', () {
    testWidgets('a one-board match, a tablet\'s whole match and the TV draw no mirror', (tester) async {
      // Whether an orange frame is drawn in the box's top left corner, where a
      // phone's mirror has it.
      Future<bool> framed(Widget view, Size box) async {
        final (width, _, bytes) = await capture(tester, view, window: box, box: box);
        return hasFrame(bytes, width, Rect.fromLTWH(8, box.height * PuzzleCamera.hudTopFraction, 56, 40));
      }

      final theirs = trayOf(tree);
      final race = raceOf(tree, theirs: theirs, them: [PlayerView(number: 2, x: 30, y: 50)]);
      Widget view(MatchSnapshot s, {LayoutTarget target = LayoutTarget.phones, PuzzleCamera camera = sideLeft}) =>
          MatchView(puzzle: tree, snapshot: s, target: target, camera: camera);
      // The probe's place is the mirror's frame when the phone has one.
      expect(await framed(view(race), iphone), isTrue, reason: 'the frame');
      // A solo player's or a team's one board on a phone: today's picture.
      final oneBoard = MatchSnapshot(
        seed: 1,
        boards: [
          PuzzleSnapshot(
            puzzleId: tree.id,
            timeLeftMs: 65000,
            phase: PuzzlePhase.playing,
            pieces: theirs,
            players: const [PlayerView(number: 1, x: 30, y: 60)],
          ),
        ],
      );
      expect(await framed(view(oneBoard), iphone), isFalse, reason: 'one board');
      // A tablet's whole match, and the TV's split screen, with both boards.
      expect(
        await framed(view(race, camera: const PuzzleCamera.whole()), const Size(1024, 768)),
        isFalse,
        reason: 'tablet',
      );
      expect(
        await framed(view(race, target: LayoutTarget.screen, camera: const PuzzleCamera.whole()), const Size(960, 540)),
        isFalse,
        reason: 'TV',
      );
    });
  });
}

/// [MirrorPainter] draws into a canvas the match has placed it on, so a test
/// draws it alone through this: its box and its rect are the same [Size].
class _MirrorPaint extends CustomPainter {
  const _MirrorPaint(this.painter);

  final MirrorPainter painter;

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas);

  @override
  bool shouldRepaint(_MirrorPaint oldDelegate) => true;
}
