import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show playerColors;
import 'package:puzzle_game/puzzle_game.dart';

import 'frames.dart';

Puzzle load(String id) => Puzzle.parse(File('puzzles/$id.json').readAsStringSync());

/// The iPhone's px per mm, as `controller_app`'s `layout.dart` has it.
const pxPerMm = 160 / 25.4;

/// The owner's iPhone, the iPhone 15 and the smallest 16:9 phone
/// (m12-phone-layout §0.2), as the safe area a shown game fills.
const iphone = Size(852, 393);
const phone15 = Size(734, 370);
const phone169 = Size(667, 375);

/// The orange the mirror marks the other side with (m12-opponent-mirror rule
/// 4), as the protocol's palette has player 2.
final them = playerColors[1] & 0xFFFFFF;

/// The board's panel, the dark behind the mirror's dot (`view.dart`'s
/// `_board`), which a dot's ink differs from.
const boardPanel = 0x242B36;

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
MirrorPlacement? mirrorOf(
  Puzzle puzzle,
  Size box, {
  PuzzleCamera camera = sideLeft,
  List<Rect> padRects = const [],
  double mm = pxPerMm,
}) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  return PuzzleCamera.mirrorPlace(
    puzzle,
    layout,
    camera,
    box,
    split: true,
    text: raceText(puzzle),
    pxPerMm: mm,
    padRects: padRects,
  );
}

/// A made-up puzzle whose board is [aspect] wide to its height and whose
/// pieces are [side] units square: four at its corners, so the picture's box —
/// which a phones world crops to — is exactly [aspect] to 1 (m12-opponent-
/// mirror rule 7: the mirror is sized from the board and its pieces, never
/// from a puzzle's ID).
///
/// A piece is measured by [PieceShape.size], the diameter of the circle it
/// turns in: [side] * sqrt2 for these squares, not [side] itself.
Puzzle madeUpPuzzle({required double aspect, required double side, String id = 'made-up'}) {
  // The crop's box before its margin: [SplitLayout] takes the pieces' boxes
  // and adds 4 each side, so 64 high gives a 72-high board and a crop of
  // [aspect] * 72 wide is [aspect] * 72 - 8 units of pieces.
  const height = 64.0;
  final width = aspect * (height + 8) - 8;
  final s = side;
  return Puzzle(
    id: id,
    name: 'Made up',
    level: Level.easy,
    pieces: [
      for (final (i, at) in [
        Offset(s / 2, s / 2),
        Offset(width - s / 2, s / 2),
        Offset(s / 2, height - s / 2),
        Offset(width - s / 2, height - s / 2),
      ].indexed)
        PieceSpec(id: 'p$i', shape: PieceShape.rect(s, s), color: 0xFF888888, target: at),
    ],
  );
}

/// The px in the box where the mirror draws a dot or a piece at [world]: the
/// board's own place for it, at the mirror's scale.
Offset mirrorPoint(SplitLayout layout, Rect rect, double scale, Offset world) =>
    rect.topLeft + (world - layout.left.board.topLeft) * scale;

/// Whether the mirror's orange frame is drawn along [rect]'s top edge.
bool hasFrame(Uint8List bytes, int width, Rect rect, {int colour = 0xFFA040}) {
  for (var y = rect.top.round() - 2; y <= rect.top.round() + 2; y++) {
    for (var x = rect.left.round() + 4; x <= rect.right.round() - 4; x++) {
      if (pixel(bytes, width, x, y) == colour) return true;
    }
  }
  return false;
}

/// How far apart two colours are, as their widest channel's difference.
int colourGap(int a, int b) {
  var gap = 0;
  for (final shift in [16, 8, 0]) {
    final d = (((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)).abs();
    if (d > gap) gap = d;
  }
  return gap;
}

/// Whether [colour] is nearer to the dot's [ink] than to the board behind it:
/// where the antialiased edge is half ink and half board, which is the edge a
/// person sees the dot reach.
bool nearerInk(int colour, int ink) => colourGap(colour, ink) < colourGap(colour, boardPanel);

/// The width in px the dot centred on [at] (in the box's px) is drawn at in a
/// frame captured at [pixelRatio] image px per box px: the longer of the runs
/// of its ink — its orange, its white ring, their antialiased edges — along the
/// row and the column through [at].
int dotRun(Uint8List bytes, int width, int height, Offset at, {double pixelRatio = 2}) {
  final cx = (at.dx * pixelRatio).round();
  final cy = (at.dy * pixelRatio).round();
  bool isDot(int x, int y) {
    final colour = pixel(bytes, width, x, y);
    return nearerInk(colour, them) || nearerInk(colour, 0xFFFFFF);
  }

  /// How far the dot reaches from its centre in ([dx], [dy]), its centre's own
  /// pixel included.
  int reach(int dx, int dy) {
    var n = 1;
    for (var x = cx + dx, y = cy + dy; x >= 0 && x < width && y >= 0 && y < height && isDot(x, y); x += dx, y += dy) {
      n++;
    }
    return n;
  }

  return max(reach(-1, 0) + reach(1, 0), reach(0, -1) + reach(0, 1)) - 1;
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
