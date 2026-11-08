import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/frames.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// The iPhone's px per mm, as `controller_app`'s `layout.dart` has it.
const pxPerMm = 160 / 25.4;

/// The owner's iPhone, and the smallest 16:9 phone (m12-phone-layout §0.2).
const iphone = Size(852, 393);
const phone169 = Size(667, 375);

/// The camera a phone plays the left side with.
const sideLeft = PuzzleCamera.side(PuzzleSide.left);

/// A race's HUD on a phone with nothing placed, which is what decides whether
/// the box has the room for the mirror: the clock is measured for "10:00" and
/// the counts for the puzzle's pieces, as [PuzzleCamera.hudPlace] measures them.
({String score, List<String> short}) raceText(Puzzle puzzle) {
  final n = puzzle.pieces.length;
  return (score: 'You 0/$n · Right 0/$n', short: ['You 0/$n', 'Right 0/$n']);
}

/// The mirror [box] draws for [puzzle]'s race, or null.
({Rect rect, double scale})? mirrorOf(Puzzle puzzle, Size box, {PuzzleCamera camera = sideLeft}) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  return PuzzleCamera.mirrorPlace(layout, camera, box, split: true, text: raceText(puzzle));
}

/// The px in the box where the mirror draws a dot or a piece at [world]: the
/// board's own place for it, at the mirror's scale.
Offset mirrorPoint(SplitLayout layout, Rect rect, double scale, Offset world) =>
    rect.topLeft + (world - layout.left.board.topLeft) * scale;

/// Whether the mirror's orange frame is drawn along [rect]'s top edge.
bool hasFrame(Uint8List bytes, int width, Rect rect) {
  for (var y = rect.top.round() - 2; y <= rect.top.round() + 2; y++) {
    for (var x = rect.left.round() + 4; x <= rect.right.round() - 4; x++) {
      if (pixel(bytes, width, x, y) == 0xFFA040) return true;
    }
  }
  return false;
}

/// A race of [puzzle] with both sides' boards given: the left one starts with
/// every piece in its tray, the right one is [theirs].
MatchSnapshot raceOf(Puzzle puzzle, {required List<PieceView> theirs, required List<PlayerView> them}) {
  const timeLeftMs = 65000;
  PuzzleSnapshot board(List<PieceView> pieces, List<PlayerView> players) => PuzzleSnapshot(
    puzzleId: puzzle.id,
    timeLeftMs: timeLeftMs,
    phase: PuzzlePhase.playing,
    pieces: pieces,
    players: players,
  );
  return MatchSnapshot(
    seed: 1,
    boards: [
      board(
        [
          for (var i = 0; i < puzzle.pieces.length; i++)
            const PieceView(x: 10, y: 10, angle: 0, state: PieceState.tray),
        ],
        const [PlayerView(number: 1, x: 30, y: 60)],
      ),
      board(theirs, them),
    ],
  );
}

/// Their board of [puzzle]: every piece in their tray at [trayAt].
List<PieceView> trayOf(Puzzle puzzle, {Offset trayAt = const Offset(10, 10)}) => [
  for (var i = 0; i < puzzle.pieces.length; i++)
    PieceView(x: trayAt.dx, y: trayAt.dy, angle: 0, state: PieceState.tray),
];

void main() {
  final tree = load('tree');
  final layout = SplitLayout.of(tree, 1, target: LayoutTarget.phones);

  group('where the mirror goes', () {
    test('it sits at the box\'s top left, the board\'s shape at a quarter of its size, and the HUD moves to its '
        'right in the short form; the 16:9 phone has the room for the tree alone', () {
      // Seed 1, the layout the camera and size tests pin: the board's units at
      // 852 x 393 are house 4.4407, rocket 4.9434, tree 3.8529 and boat 4.8810
      // px, times 0.25882 (mirrorMinPieceMm / minPieceMm); the top is 0.14 of
      // 393 = 55.02 px.
      const expected = {
        'house': (form: HudForm.twoLines, rect: Rect.fromLTWH(8, 55.02, 68.96, 71.26)),
        'rocket': (form: HudForm.twoLines, rect: Rect.fromLTWH(8, 55.02, 51.18, 75.49)),
        'tree': (form: HudForm.oneLine, rect: Rect.fromLTWH(8, 55.02, 69.81, 70.80)),
        'boat': (form: HudForm.twoLines, rect: Rect.fromLTWH(8, 55.02, 93.49, 77.06)),
      };
      for (final MapEntry(key: id, value: e) in expected.entries) {
        final puzzle = load(id);
        final l = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final text = raceText(puzzle);
        final where = '$id at $iphone';
        expect(PuzzleCamera.hudPlace(l, sideLeft, iphone, text).form, e.form, reason: where);
        final mirror = PuzzleCamera.mirrorPlace(l, sideLeft, iphone, split: true, text: text);
        expect(mirror, isNotNull, reason: where);
        final rect = mirror!.rect;
        expect(rect.left, closeTo(e.rect.left, 0.01), reason: where);
        expect(rect.top, closeTo(e.rect.top, 0.01), reason: where);
        expect(rect.width, closeTo(e.rect.width, 0.01), reason: where);
        expect(rect.height, closeTo(e.rect.height, 0.01), reason: where);
        // Their board's own shape at the mirror's scale, never stretched.
        final place = PuzzleCamera.place(l, sideLeft, iphone, PuzzleSide.left);
        expect(mirror.scale, closeTo(place.scale * PuzzleCamera.mirrorFraction, 1e-9), reason: where);
        expect(rect.size.width, closeTo(l.left.board.width * mirror.scale, 1e-9), reason: where);
        // The clock area is to its right, in the short form, clear of the world.
        final hud = PuzzleCamera.hudPlace(l, sideLeft, iphone, text, mirror: rect);
        expect(hud.form, HudForm.short, reason: where);
        expect(hud.rect.left, closeTo(rect.right + PuzzleCamera.hudMirrorGapPx, 1e-9), reason: where);
        expect(hud.rect.right, lessThanOrEqualTo(place.origin.dx - PuzzleCamera.hudWorldGapPx + 1e-9), reason: where);
      }

      // 667 x 375: the house, rocket and boat HUDs are already in their short
      // form at that width, so those phones keep today's HUD; the tree's
      // two-line HUD has the room, and the mirror is 70 x 71 board units at
      // 3.6765 x 0.25882 = 0.9516 px, 66.61 x 67.56 px, at 0.14 of 375 = 52.5.
      for (final id in ['house', 'rocket', 'boat']) {
        expect(
          PuzzleCamera.hudPlace(
            SplitLayout.of(load(id), 1, target: LayoutTarget.phones),
            sideLeft,
            phone169,
            raceText(load(id)),
          ).form,
          HudForm.short,
          reason: id,
        );
        expect(mirrorOf(load(id), phone169), isNull, reason: id);
      }
      final small = mirrorOf(tree, phone169)!;
      expect(small.rect.left, 8);
      expect(small.rect.top, closeTo(52.5, 0.01));
      expect(small.rect.width, closeTo(66.61, 0.01));
      expect(small.rect.height, closeTo(67.56, 0.01));
    });

    test('no mirror on a one-board match, the whole match, the screen, or a box too narrow for it', () {
      final text = raceText(tree);
      final l = SplitLayout.of(tree, 1, target: LayoutTarget.phones);
      // Solo and a team play on one board: nothing to mirror.
      expect(PuzzleCamera.mirrorPlace(l, sideLeft, iphone, split: false, text: text), isNull);
      // A tablet draws the whole match.
      expect(
        PuzzleCamera.mirrorPlace(l, const PuzzleCamera.whole(), const Size(1024, 768), split: true, text: text),
        isNull,
      );
      // The TV and the split screen keep today's picture.
      final screen = SplitLayout.of(tree, 1);
      expect(PuzzleCamera.mirrorPlace(screen, sideLeft, const Size(960, 540), split: true, text: text), isNull);
      // A narrow box leaves the HUD its corner: no room for a mirror either.
      expect(PuzzleCamera.mirrorPlace(l, sideLeft, const Size(380, 375), split: true, text: text), isNull);
      // The boat at 667 x 375: its world starts at 120.8 px, so the 89.2 px
      // mirror and its 8 px gap would leave the 75 px count 16 px.
      final boat = load('boat');
      final boatLayout = SplitLayout.of(boat, 1, target: LayoutTarget.phones);
      final boatText = raceText(boat);
      expect(PuzzleCamera.hudPlace(boatLayout, sideLeft, phone169, boatText).form, HudForm.short);
      expect(PuzzleCamera.mirrorPlace(boatLayout, sideLeft, phone169, split: true, text: boatText), isNull);
    });

    test('every piece the mirror draws is at least mirrorMinPieceMm, on both phones', () {
      // The smallest piece of each puzzle in board units: house sun 14.0,
      // rocket window 12.0, tree sun 16.0, boat flag 12.65.
      const cases = [
        ('house', iphone, 2.55),
        ('rocket', iphone, 2.44),
        ('tree', iphone, 2.53),
        ('boat', iphone, 2.81),
        ('tree', phone169, 2.42),
      ];
      for (final (id, box, mm) in cases) {
        final puzzle = load(id);
        final mirror = mirrorOf(puzzle, box);
        expect(mirror, isNotNull, reason: '$id at $box');
        final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
        final drawn = mirror!.scale * smallest / pxPerMm;
        expect(drawn, closeTo(mm, 0.01), reason: '$id at $box');
        expect(drawn, greaterThanOrEqualTo(mirrorMinPieceMm), reason: '$id at $box');
      }
    });

    test('the count beside the mirror names the other side "Them"', () {
      final match = PuzzleMatch(
        tree,
        teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
        random: Random(1),
        target: LayoutTarget.phones,
      );
      final s = match.snapshot();
      expect(phoneHud(s, PuzzleSide.left, mirrored: true).short, ['You 0/4', 'Them 0/4']);
      expect(phoneHud(s, PuzzleSide.left, mirrored: true).score, 'You 0/4 · Them 0/4');
      // Without a mirror it is still the side's name, as before.
      expect(phoneHud(s, PuzzleSide.left).short, ['You 0/4', 'Right 0/4']);
    });
  });

  group('what the mirror draws', () {
    late ({Rect rect, double scale}) mirror;
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
      // The parts of their board with nothing in them show the panel.
      final empty = at(const Offset(18, 22));
      expect(pixel(bytes, width, empty.dx.round(), empty.dy.round()), 0x242B36);
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
      expect(pixel(bytes, width, dot.dx.round(), dot.dy.round()), 0xFFA040);
      // 10 board units away it is the board, not the dot.
      final away = at(const Offset(36, 40));
      expect(pixel(bytes, width, away.dx.round(), away.dy.round()), isNot(0xFFA040));
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
      // right of the board's left, and 2.6 (the dot's radius) below its top, so
      // the whole dot is on the mirror's top edge.
      final pinned = mirrorPoint(layout, mirror.rect, mirror.scale, Offset(above.dx, board.top + PuzzleGame.dotRadius));
      expect(pixel(bytes, width, pinned.dx.round(), pinned.dy.round()), 0xFFA040);
      // Its place across the board is its own: 10 units along is the board.
      final along = Offset(pinned.dx + 10, pinned.dy);
      expect(pixel(bytes, width, along.dx.round(), along.dy.round()), isNot(0xFFA040));
      // Nothing is drawn at its real place, above the mirror.
      expect(pixel(bytes, width, pinned.dx.round(), (mirror.rect.top - 3).round()), isNot(0xFFA040));
      // And it is not 10 board units lower, where an unpinned dot would be.
      final lower = Offset(pinned.dx, pinned.dy + 15);
      expect(pixel(bytes, width, lower.dx.round(), lower.dy.round()), isNot(0xFFA040));
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
      // inside it upright and outside it on its side.
      expect(await probe(0, const Offset(40, 47)), 0x8E5B3A, reason: 'upright: 7 down is still trunk');
      expect(await probe(0, const Offset(47, 40)), isNot(0x8E5B3A), reason: 'upright: 7 across is past it');
      expect(await probe(90, const Offset(47, 40)), 0x8E5B3A, reason: 'turned: 7 across is trunk');
      expect(await probe(90, const Offset(40, 47)), isNot(0x8E5B3A), reason: 'turned: 7 down is past it');
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
        expect(pixel(bytes, width, where.dx.round(), where.dy.round()), 0xFFA040, reason: '$boardUnit');
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
