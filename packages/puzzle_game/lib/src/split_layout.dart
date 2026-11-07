import 'dart:math';
import 'dart:ui';

import 'puzzle.dart';
import 'start_angles.dart';
import 'tray.dart';

/// Where everything goes on the split screen for one puzzle (PRD v2 "Modes
/// and layout"), chosen to draw the board as big as possible. In field units
/// of the whole screen ([fieldSize], 160 x 90).
final class SplitLayout {
  const SplitLayout._({
    required this.left,
    required this.right,
    required this.leftBox,
    required this.rightBox,
    required this.angles,
    required this.hudStrip,
    required this.trayBelow,
    required this.scale,
  });

  /// The left side's world.
  final PuzzleField left;

  /// The right side's world.
  final PuzzleField right;

  /// The start angles the tray was sized for: both sides start with the same
  /// ones, so the race is fair.
  final Map<int, double> angles;

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

  /// The widest tray tried.
  static const _widestTray = 120.0;

  /// The clock's strip along the top (with the counts), and the room the
  /// clock needs between the boards when it goes there instead.
  static const stripHeight = 6.0;
  static const clockGap = 12.0;

  /// How far apart the boards sit in the middle under the strip: just enough
  /// for the divider.
  static const _stripGap = 2.0;

  /// How much the pieces in a tray row overlap, and how much smaller a piece
  /// still in the tray is drawn on the split screen, so a pile fits where
  /// rows of separate full-size boxes wouldn't.
  static const _trayOverlap = 0.5;
  static const _trayScale = 0.75;

  /// One layout per puzzle and seed, so the painter can ask every frame. Kept
  /// with the puzzle object itself, not its id: two puzzles may share an id
  /// (tests, an edited file) and must not share a layout.
  static final _layouts = Expando<Map<int, SplitLayout>>('SplitLayout');

  /// The layout for [puzzle] with [seed], computed once and kept. Every
  /// match has its own seed, so only the last few are kept per puzzle.
  static SplitLayout of(Puzzle puzzle, int seed) {
    final kept = _layouts[puzzle] ??= {};
    final layout = kept[seed] ??= _compute(puzzle, seed);
    while (kept.length > _keep) {
      kept.remove(kept.keys.first);
    }
    return layout;
  }

  static const _keep = 8;

  static SplitLayout _compute(Puzzle puzzle, int seed) {
    final crop = _crop(puzzle);
    // Two trays: one for a board with the tray below it, one beside it. Each
    // starts at the angles that pack smallest along its tray.
    final below = Map<int, double>.unmodifiable(compactStartAngles(puzzle, Random(seed), flat: true));
    final beside = Map<int, double>.unmodifiable(compactStartAngles(puzzle, Random(seed), flat: false));

    // The best candidate so far; scale 0 lets the first one win.
    var best = (
      width: 0.0,
      height: 0.0,
      trayWidth: 0.0,
      trayHeight: 0.0,
      scale: 0.0,
      hudStrip: true,
      trayBelow: false,
      angles: below,
    );

    void consider(Map<int, double> angles, bool trayBelow) {
      // The tray holds pieces at [_trayScale], so it is sized for those.
      final widest = [for (final (i, spec) in puzzle.pieces.indexed) spec.shape.bounds(angles[i]!).width * _trayScale]
          .reduce(max);
      for (var trayWidth = widest + _boardTrayGap; trayWidth <= _widestTray; trayWidth += 1) {
        // The height the game's packing of this tray needs at this width.
        final trayHeight = packTray(puzzle, angles, trayWidth, overlap: _trayOverlap, scale: _trayScale).height;
        final world = trayBelow
            // The tray below the board: a narrow, tall world.
            ? (
                width: _margin + max(crop.width, trayWidth) + _margin,
                height: _margin + crop.height + _boardTrayGap + trayHeight + _margin,
              )
            // The tray beside the board, at the outer edge: a wide, short
            // world.
            : (
                width: _margin + crop.width + _boardTrayGap + trayWidth + _margin,
                height: _margin + max(crop.height, trayHeight) + _margin,
              );
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
          angles: angles,
        );
      }
    }

    consider(beside, false);
    consider(below, true);

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
        trayOverlap: _trayOverlap,
        trayScale: _trayScale,
      );
    }

    // The boards together in the middle, the leftover width at the outer
    // edges: the strip above them, or the clock between them. The strip's
    // score leaves half a unit of slack each side; the board is kept on
    // screen at the room it really has.
    final middle = fieldSize.width / 2;
    final half = best.hudStrip ? _stripGap / 2 : clockGap / 2;
    final roomWidth = middle - half;
    final roomHeight = best.hudStrip ? fieldSize.height - stripHeight : fieldSize.height;
    final scale = min(best.scale, min(roomWidth / best.width, roomHeight / best.height));
    final onScreen = Size(world.width * scale, world.height * scale);
    final top = best.hudStrip
        ? stripHeight + (fieldSize.height - stripHeight - onScreen.height) / 2
        : (fieldSize.height - onScreen.height) / 2;
    return SplitLayout._(
      left: side(true),
      right: side(false),
      leftBox: Rect.fromLTWH(middle - half - onScreen.width, top, onScreen.width, onScreen.height),
      rightBox: Rect.fromLTWH(middle + half, top, onScreen.width, onScreen.height),
      angles: best.angles,
      hudStrip: best.hudStrip,
      trayBelow: best.trayBelow,
      scale: scale,
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

  /// The scale of a world [width] by [height] on the split screen, and the
  /// clock arrangement that goes with it: the bigger of a strip along the top
  /// (each half is 80 wide below it) and the gap between the boards (the full
  /// 90 high, with [clockGap] left free in the middle).
  static ({double scale, bool hudStrip}) _fit(double width, double height) {
    final strip = min((fieldSize.width / 2) / width, (fieldSize.height - stripHeight) / height);
    final gap = min((fieldSize.width - clockGap) / 2 / width, fieldSize.height / height);
    return gap > strip ? (scale: gap, hudStrip: false) : (scale: strip, hudStrip: true);
  }
}
