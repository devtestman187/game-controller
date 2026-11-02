import 'dart:math';
import 'dart:ui';

import 'puzzle.dart';

/// Where everything goes on the split screen for one puzzle (PRD v2 "Modes
/// and layout"), chosen to draw the board as big as possible. In field units
/// of the whole screen ([fieldSize], 160 x 90).
final class SplitLayout {
  const SplitLayout._({
    required this.left,
    required this.right,
    required this.leftBox,
    required this.rightBox,
    required this.hudStrip,
    required this.trayBelow,
    required this.scale,
  });

  /// The left side's world.
  final PuzzleField left;

  /// The right side's world.
  final PuzzleField right;

  /// Where the left world is drawn on the screen (exactly the world's aspect).
  final Rect leftBox;

  /// Where the right world is drawn on the screen (exactly the world's
  /// aspect).
  final Rect rightBox;

  /// True: the clock and counts in a strip along the top; false: in the gap
  /// between the boards.
  final bool hudStrip;

  /// True: the tray is below the board; false: beside it, at the outer edge.
  final bool trayBelow;

  /// Screen units per world unit (the board's size compared with the
  /// one-board layout, where it's 1).
  final double scale;

  /// The margin around each world and the gap between the board and the
  /// tray; the tray's packing has its own gap at the edges and between boxes.
  static const _margin = 2.0;
  static const _boardTrayGap = 4.0;
  static const _trayGap = 2.0;

  /// The widest tray tried, and the middle kept free for the clock when it
  /// goes between the boards.
  static const _widestTray = 120.0;
  static const _clockGap = 24.0;

  /// One layout per puzzle, so the painter can ask every frame. Kept with the
  /// puzzle object itself, not its id: two puzzles may share an id (tests,
  /// an edited file) and must not share a layout.
  static final _layouts = Expando<SplitLayout>('SplitLayout');

  /// The layout for [puzzle], computed once and kept.
  static SplitLayout of(Puzzle puzzle) => _layouts[puzzle] ??= _compute(puzzle);

  static SplitLayout _compute(Puzzle puzzle) {
    final crop = _crop(puzzle);
    final boxes = [for (final spec in puzzle.pieces) _pieceBox(spec)];
    final widest = boxes.map((b) => b.width).reduce(max);

    // The best candidate so far; scale 0 lets the first one win.
    var best = (width: 0.0, height: 0.0, trayWidth: 0.0, trayHeight: 0.0, scale: 0.0, hudStrip: true, trayBelow: false);
    for (var trayWidth = widest + _boardTrayGap; trayWidth <= _widestTray; trayWidth += 1) {
      final trayHeight = _trayHeight(boxes, trayWidth);
      // The tray beside the board, at the outer edge: a wide, short world.
      final beside = (
        width: _margin + crop.width + _boardTrayGap + trayWidth + _margin,
        height: _margin + max(crop.height, trayHeight) + _margin,
      );
      // The tray below the board: a narrow, tall world.
      final below = (
        width: _margin + max(crop.width, trayWidth) + _margin,
        height: _margin + crop.height + _boardTrayGap + trayHeight + _margin,
      );
      for (final (world, trayBelow) in [(beside, false), (below, true)]) {
        final fit = _fit(world.width, world.height);
        if (fit.scale <= best.scale) continue;
        best = (
          width: world.width,
          height: world.height,
          trayWidth: trayWidth,
          trayHeight: trayHeight,
          scale: fit.scale,
          hudStrip: fit.hudStrip,
          trayBelow: trayBelow,
        );
      }
    }

    final world = Size(best.width, best.height);
    ({Rect board, Rect tray}) panels(bool left) {
      if (best.trayBelow) {
        return (
          board: Rect.fromLTWH((best.width - crop.width) / 2, _margin, crop.width, crop.height),
          tray: Rect.fromLTWH(
            (best.width - best.trayWidth) / 2,
            _margin + crop.height + _boardTrayGap,
            best.trayWidth,
            best.trayHeight,
          ),
        );
      }
      final boardTop = (best.height - crop.height) / 2;
      final besideTrayHeight = best.height - 2 * _margin;
      return left
          ? (
              tray: Rect.fromLTWH(_margin, _margin, best.trayWidth, besideTrayHeight),
              board: Rect.fromLTWH(_margin + best.trayWidth + _boardTrayGap, boardTop, crop.width, crop.height),
            )
          : (
              board: Rect.fromLTWH(_margin, boardTop, crop.width, crop.height),
              tray: Rect.fromLTWH(_margin + crop.width + _boardTrayGap, _margin, best.trayWidth, besideTrayHeight),
            );
    }

    PuzzleField side(bool left) {
      final p = panels(left);
      return PuzzleField(
        size: world,
        board: p.board,
        tray: p.tray,
        origin: p.board.topLeft - crop.topLeft,
        top: 0,
        startX: left ? p.board.left + 6 : p.board.right - 6,
      );
    }

    final onScreen = Size(world.width * best.scale, world.height * best.scale);
    final leftEdge = best.hudStrip ? (fieldSize.width / 2 - onScreen.width) / 2 : 0.0;
    final rightEdge = best.hudStrip ? fieldSize.width / 2 + leftEdge : fieldSize.width - onScreen.width;
    final top = best.hudStrip
        ? hudHeight + (fieldSize.height - hudHeight - onScreen.height) / 2
        : (fieldSize.height - onScreen.height) / 2;
    return SplitLayout._(
      left: side(true),
      right: side(false),
      leftBox: Rect.fromLTWH(leftEdge, top, onScreen.width, onScreen.height),
      rightBox: Rect.fromLTWH(rightEdge, top, onScreen.width, onScreen.height),
      hudStrip: best.hudStrip,
      trayBelow: best.trayBelow,
      scale: best.scale,
    );
  }

  /// The picture's box in board units: the union of every outline's box at
  /// its target angle, with a margin of 4.
  static Rect _crop(Puzzle puzzle) {
    var crop = puzzle.pieces.first.shape.bounds(puzzle.pieces.first.targetAngle).shift(puzzle.pieces.first.target);
    for (final spec in puzzle.pieces.skip(1)) {
      crop = crop.expandToInclude(spec.shape.bounds(spec.targetAngle).shift(spec.target));
    }
    return crop.inflate(4);
  }

  /// The biggest box a piece can need in the tray: a piece that starts turned
  /// fits at any angle in the square around its centre ([PieceShape.radius]),
  /// the others at their target angle.
  static Size _pieceBox(PieceSpec spec) => spec.rotated && spec.shape.symmetry != 0
      ? Size.square(spec.shape.radius * 2)
      : spec.shape.bounds(spec.targetAngle).size;

  /// The height the tray needs at [width], packed as the game packs it:
  /// tallest first, rows from the left with a gap at the edges and between
  /// boxes, and a new row when the next box doesn't fit.
  static double _trayHeight(List<Size> boxes, double width) {
    final sorted = [...boxes]..sort((a, b) => b.height.compareTo(a.height));
    var x = _trayGap;
    var y = _trayGap;
    var rowHeight = 0.0;
    for (final box in sorted) {
      if (x + box.width > width - _trayGap && x > _trayGap) {
        x = _trayGap;
        y += rowHeight + _trayGap;
        rowHeight = 0;
      }
      x += box.width + _trayGap;
      rowHeight = max(rowHeight, box.height);
    }
    return y + rowHeight + _trayGap;
  }

  /// The scale of a world [width] by [height] on the split screen, and the
  /// clock arrangement that goes with it: the bigger of a strip along the top
  /// (each half is 80 x 80 below it) and the gap between the boards (the full
  /// 90 high, with [_clockGap] left free in the middle).
  static ({double scale, bool hudStrip}) _fit(double width, double height) {
    final strip = min((fieldSize.width / 2) / width, (fieldSize.height - hudHeight) / height);
    final gap = min((fieldSize.width - _clockGap) / 2 / width, fieldSize.height / height);
    return gap > strip ? (scale: gap, hudStrip: false) : (scale: strip, hudStrip: true);
  }
}
