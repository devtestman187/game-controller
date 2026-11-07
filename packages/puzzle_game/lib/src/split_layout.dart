import 'dart:math';
import 'dart:ui';

import 'puzzle.dart';
import 'start_angles.dart';
import 'tray.dart';

/// Which world a match lays its sides out in (m12 §0.4): the TV's split
/// screen, or one side per phone. The host picks it when the round starts
/// and puts it in the view's setup, so the rules and every viewer build the
/// same world.
enum LayoutTarget {
  /// The split screen (PRD v2 "Modes and layout"): two 16:9 halves, the
  /// clock along the top, the board drawn as big as a half allows.
  screen,

  /// A phone showing its own side (m12 §1): the tray along the top with the
  /// clock at its right end, the picture's crop below it, the world sized to
  /// its content because a phone's height is what limits the scale.
  phones,
}

/// Where everything goes for one puzzle (PRD v2 "Modes and layout"): the
/// split screen's two halves, or the world each phone draws in a
/// [LayoutTarget.phones] match. In field units of the whole screen
/// ([fieldSize], 160 x 90) for [LayoutTarget.screen]; a `phones` world is in
/// units of its own, which a viewer fits to the box it is given (m12 §1).
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
    this.hud,
  });

  /// The left side's world. Both sides are the same world on phones, where a
  /// phone shows only its own side.
  final PuzzleField left;

  /// The right side's world. Both sides are the same world on phones, where a
  /// phone shows only its own side.
  final PuzzleField right;

  /// The start angles the tray was sized for: both sides start with the same
  /// ones, so the race is fair.
  final Map<int, double> angles;

  /// The clock's area at the right end of a `phones` side's tray row, in
  /// world units (the same on both sides): the clock, the two sides' counts
  /// and the time bar share it with no separate band (m12 §1). Screen-only
  /// layouts have no such area, because their clock is [hudStrip]'s.
  final Rect? hud;

  /// Screen-only: where the left world is drawn on the screen (exactly the
  /// world's aspect). On phones the viewer fits the world to its box.
  final Rect leftBox;

  /// Screen-only: where the right world is drawn on the screen (exactly the
  /// world's aspect). On phones the viewer fits the world to its box.
  final Rect rightBox;

  /// Screen-only: true when the clock and counts are in a strip along the
  /// top; false when they are in the gap between the boards. On phones they
  /// are in [hud].
  final bool hudStrip;

  /// Screen-only: true when the tray is below the board; false when it is
  /// beside it, at the outer edge. On phones the tray is always on top.
  final bool trayBelow;

  /// Screen-only: screen units per world unit (the board's size compared
  /// with the one-board layout, where it's 1). On phones the world is the
  /// screen's own size and the viewer scales it.
  final double scale;

  /// The margin around each world and between its panels; the tray's packing
  /// has its own gap at the edges and between boxes.
  static const margin = 2.0;
  static const _boardTrayGap = 4.0;

  /// The room the clock, the two sides' counts and the time bar take at the
  /// right end of a `phones` side's tray row, in world units (m12 §1), so no
  /// separate strip band is needed.
  static const hudWidth = 40.0;

  /// The widest a `phones` side may be, against its height: 2.2:1 is wider
  /// than any landscape phone. Past it the tray packs in two rows instead,
  /// so the world stays closer to a phone's shape (m12 §1).
  static const phoneMaxAspect = 2.2;

  /// Where the players' dots start along the board's edge, in world units.
  static const _dotInset = 6.0;

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

  /// One layout per puzzle, seed and [LayoutTarget], so the painter can ask
  /// every frame. Kept with the puzzle object itself, not its id: two puzzles
  /// may share an id (tests, an edited file) and must not share a layout.
  static final _layouts = Expando<Map<(int, LayoutTarget), SplitLayout>>('SplitLayout');

  /// The layout for [puzzle] with [seed] in [target], computed once and
  /// kept. Every match has its own seed, so only the last few are kept per
  /// puzzle.
  static SplitLayout of(Puzzle puzzle, int seed, {LayoutTarget target = LayoutTarget.screen}) {
    final kept = _layouts[puzzle] ??= {};
    final layout = kept[(seed, target)] ??= switch (target) {
      LayoutTarget.screen => _computeScreen(puzzle, seed),
      LayoutTarget.phones => _computePhones(puzzle, seed),
    };
    while (kept.length > _keep) {
      kept.remove(kept.keys.first);
    }
    return layout;
  }

  static const _keep = 8;

  /// The split screen's layout (PRD v2 "Modes and layout"): the tray below or
  /// beside each board, whichever draws the board bigger.
  static SplitLayout _computeScreen(Puzzle puzzle, int seed) {
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
                width: margin + max(crop.width, trayWidth) + margin,
                height: margin + crop.height + _boardTrayGap + trayHeight + margin,
              )
            // The tray beside the board, at the outer edge: a wide, short
            // world.
            : (
                width: margin + crop.width + _boardTrayGap + trayWidth + margin,
                height: margin + max(crop.height, trayHeight) + margin,
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
          board: Rect.fromLTWH((best.width - crop.width) / 2, margin, crop.width, crop.height),
          tray: Rect.fromLTWH(
            (best.width - best.trayWidth) / 2,
            margin + crop.height + _boardTrayGap,
            best.trayWidth,
            best.trayHeight,
          ),
        );
      }
      final boardTop = (best.height - crop.height) / 2;
      final besideTrayHeight = best.height - 2 * margin;
      return left
          ? (
              tray: Rect.fromLTWH(margin, margin, best.trayWidth, besideTrayHeight),
              board: Rect.fromLTWH(margin + best.trayWidth + _boardTrayGap, boardTop, crop.width, crop.height),
            )
          : (
              board: Rect.fromLTWH(margin, boardTop, crop.width, crop.height),
              tray: Rect.fromLTWH(margin + crop.width + _boardTrayGap, margin, best.trayWidth, besideTrayHeight),
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
        startX: left ? p.board.left + _dotInset : p.board.right - _dotInset,
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

  /// The `phones` world (m12 §1): each side sized to its own content, because
  /// a phone's height is what limits the scale. The tray runs along the top,
  /// packed as [_trayScale] pieces with [_trayOverlap], at the angles that
  /// make it flat; [hudWidth] at its right end holds the clock; the picture's
  /// crop sits below, centred. Both sides are the same world and angles.
  static SplitLayout _computePhones(Puzzle puzzle, int seed) {
    final crop = _crop(puzzle);
    final angles = Map<int, double>.unmodifiable(compactStartAngles(puzzle, Random(seed), flat: true));
    var tray = _phoneTray(puzzle, angles);
    var world = _phoneWorld(crop, tray.width, tray.height);
    if (world.width > phoneMaxAspect * world.height) {
      // Wider than any landscape phone: pack the tray in two rows instead.
      tray = _twoRowTray(puzzle, angles, tray.width);
      world = _phoneWorld(crop, tray.width, tray.height);
    }
    final board = Rect.fromLTWH((world.width - crop.width) / 2, margin + tray.height + margin, crop.width, crop.height);
    final field = PuzzleField(
      size: world,
      board: board,
      tray: Rect.fromLTWH(margin, margin, tray.width, tray.height),
      origin: board.topLeft - crop.topLeft,
      // The dots stay below the tray, on the board.
      top: margin + tray.height,
      startX: board.left + _dotInset,
      trayOverlap: _trayOverlap,
      trayScale: _trayScale,
    );
    return SplitLayout._(
      left: field,
      right: field,
      leftBox: Offset.zero & world,
      rightBox: Offset.zero & world,
      angles: angles,
      hudStrip: true,
      trayBelow: false,
      scale: 1,
      hud: Rect.fromLTWH(world.width - margin - hudWidth, margin, hudWidth, tray.height),
    );
  }

  /// A `phones` side's world for a tray [trayWidth] by [trayHeight] above the
  /// picture's [crop]: the margins around and between, and [hudWidth] beside
  /// the tray.
  static Size _phoneWorld(Rect crop, double trayWidth, double trayHeight) => Size(
    max(crop.width + 2 * margin, trayWidth + hudWidth + 2 * margin),
    margin + trayHeight + margin + crop.height + margin,
  );

  /// A `phones` side's tray in one row, as wide as the row of pieces needs: no
  /// tray width can break the row, so it is packed without a limit.
  static ({double width, double height, int rows}) _phoneTray(Puzzle puzzle, Map<int, double> angles) =>
      _packedTray(puzzle, angles, double.infinity);

  /// The narrowest tray that still packs the pieces in two rows, found from
  /// the widest piece's box upward; the one-row tray if none is narrower.
  static ({double width, double height, int rows}) _twoRowTray(
    Puzzle puzzle,
    Map<int, double> angles,
    double oneRowWidth,
  ) {
    final widest = [for (final (i, spec) in puzzle.pieces.indexed) spec.shape.bounds(angles[i]!).width * _trayScale]
        .reduce(max);
    for (var width = widest + trayGap; width < oneRowWidth; width += 1) {
      final tray = _packedTray(puzzle, angles, width);
      if (tray.rows <= 2) return tray;
    }
    return _phoneTray(puzzle, angles);
  }

  /// The pieces packed at [width], as the rules will pack them: the tray's
  /// size with [trayGap] at both edges, and how many rows that makes. A
  /// [width] the packing fits in is kept, so the rules pack it the same way
  /// again; no limit means the tray is as wide as the one row needs.
  static ({double width, double height, int rows}) _packedTray(Puzzle puzzle, Map<int, double> angles, double width) {
    final packed = packTray(puzzle, angles, width, overlap: _trayOverlap, scale: _trayScale);
    // Each box's width as the rules scale it, so a width worked out here is
    // the width the rules compare against, down to the last bit.
    final widths = <double>[];
    for (final (i, spec) in puzzle.pieces.indexed) {
      final box = spec.shape.bounds(angles[i]!);
      widths.add(box.right * _trayScale - box.left * _trayScale);
    }
    var right = 0.0;
    for (final (n, i) in packed.order.indexed) {
      // A piece starts its row at its full overlap and steps back only when
      // the row would hide another piece, so the first try is the rightmost
      // place it can take.
      var start = packed.at[i]!.dx;
      if (n > 0) {
        final prev = packed.order[n - 1];
        if (packed.at[i]!.dy == packed.at[prev]!.dy) {
          start = max(start, packed.at[prev]!.dx + widths[prev] * (1 - _trayOverlap));
        }
      }
      right = max(right, start + widths[i]);
    }
    return (
      width: width.isFinite ? max(width, right + trayGap) : right + trayGap,
      height: packed.height,
      rows: {for (final at in packed.at.values) at.dy}.length,
    );
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
