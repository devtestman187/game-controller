import 'dart:math';
import 'dart:ui' show FragmentProgram, Picture, PictureRecorder;

import 'package:flutter/foundation.dart' show listEquals, mapEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'camera.dart';
import 'cat_moments.dart';
import 'cat_pose.dart';
import 'cat_view.dart';
import 'celebration.dart';
import 'game.dart';
import 'piece_moments.dart';
import 'piece_size.dart';
import 'points.dart';
import 'present.dart';
import 'present_painter.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'snapshot.dart';
import 'split_layout.dart';
import 'worker_moments.dart';

part 'board_cache.dart';
part 'board_hud.dart';
part 'cat_head.dart';
part 'cat_paint.dart';
part 'cat_paw.dart';
part 'celebration_paint.dart';
part 'match_hud.dart';
part 'match_painter.dart';
part 'mirror_painter.dart';
part 'phone_hud.dart';
part 'points_paint.dart';
part 'puzzle_painter.dart';
part 'slot_paint.dart';
part 'text_paint.dart';
part 'worker_painter.dart';

/// Draws a puzzle from a [PuzzleSnapshot] (PRD v2 S8) into the box it's
/// given, keeping the field's 16:9 shape and centring it (S4). It never
/// reads the screen size, so the same view works on a TV, in a window, or
/// drawn off-screen for a stream. It draws in the look of the [ToyLookScope]
/// above it (M13), and the pieces' boing and wobble come from the snapshots
/// it is given.
class PuzzleView extends StatefulWidget {
  const PuzzleView({super.key, required this.puzzle, required this.snapshot, this.cat, this.timeLimitS, this.clock});

  final Puzzle puzzle;
  final PuzzleSnapshot snapshot;

  /// The cat, while it visits this board (M14 a2); null when it is away. The
  /// view times its motion itself, so this one-board widget draws the cat as
  /// the match view does (M14 bugs2 3).
  final CatView? cat;

  /// For the clock's bar. Null: no bar.
  final int? timeLimitS;

  /// Where the view reads the time for the pieces' motion, in milliseconds.
  /// Null: a [Stopwatch] started when the view is built. The game sends a
  /// snapshot every frame, so the view needs no ticker of its own.
  final Stopwatch? clock;

  @override
  State<PuzzleView> createState() => _PuzzleViewState();
}

class _PuzzleViewState extends State<PuzzleView> {
  final _moments = PieceMoments();
  final _catMoments = CatMoments();
  late final _workers = WorkerMoments(widget.puzzle);

  /// What the board draws the same way from frame to frame (M14 bugs3 B-016).
  final _cache = BoardCache();

  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  /// The one board as the match the moments see it: they are kept per board,
  /// as a match keeps its left and right.
  MatchSnapshot get _match => MatchSnapshot(boards: [widget.snapshot], cat: widget.cat);

  int get _nowMs => _clock.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _note(_match);
  }

  @override
  void didUpdateWidget(PuzzleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another puzzle's board has other slots and pieces: the cache's pictures
    // are this one's (M14 bugs3's still-key finding).
    if (!identical(oldWidget.puzzle, widget.puzzle)) _cache.clear();
    if (!identical(oldWidget.snapshot, widget.snapshot) || oldWidget.cat != widget.cat) _note(_match);
  }

  void _note(MatchSnapshot match) {
    _moments.observe(match, _nowMs);
    _workers.observe(match, _nowMs);
    _catMoments.observe(match.cat, _nowMs);
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('puzzleView'),
    size: Size.infinite,
    painter: PuzzlePainter(
      widget.puzzle,
      widget.snapshot,
      look: ToyLookScope.of(context),
      moments: _moments,
      catMoments: _catMoments,
      workers: _workers,
      cache: _cache,
      nowMs: _nowMs,
      timeLimitS: widget.timeLimitS,
      cat: widget.cat,
      // The screen's sky shows round the board and the tray where a
      // `ToyBackground` is behind the view (design section 5, decided at
      // device test 3); drawn alone, as the pictures are, the painter fills.
      fillsBackground: !toyStillSkyAbove(context),
    ),
  );
}

/// The field of size [field] in [box]: the scale and the offset of its top
/// left. The painters fit the 160 x 90 picture with it, and
/// [PuzzleCamera.scale] measures a screen box by it.
({double scale, Offset origin}) fieldIn(Size box, [Size field = fieldSize]) {
  final scale = min(box.width / field.width, box.height / field.height);
  final origin = Offset((box.width - field.width * scale) / 2, (box.height - field.height * scale) / 2);
  return (scale: scale, origin: origin);
}

/// How far toward its corners, and how far round its radius, a placed piece's
/// ✓ moves when an empty target drawn over it covers the piece's middle (design
/// section 5, decided at device test 3).
const _checkCornerShare = 0.55;
const _checkRingShare = 0.5;

/// The ✓ and ✗ marks' sizes, in world units, and how thick their ink edge is,
/// as a share of the mark's size.
const _markSize = 5.0;
const _markSmallSize = 3.2;
const _markEdgeShare = 0.12;

/// How thick a mark's stroke is, as a share of half its size.
const _markStrokeShare = 0.45;

/// How much of a sparkle's fade the mark's own colour keeps, so it is still
/// seen at the end of the sparkle.
const _sparkleFloor = 0.2;

/// What a piece shows over the picture once it is dropped: a locked piece's ✓,
/// where it stays clear of the empty targets drawn over it, and a wrong drop's
/// ✗ (design section 5). They are kept with the views rather than in the
/// board's painter, as the HUD and the workers are.
extension _Marks on PuzzlePainter {
  /// Where a locked piece [piece]'s ✓ is drawn: its middle when nothing empty
  /// is drawn over it, else the first place on the piece clear of every empty
  /// target drawn over it — a door's slot over a wall — and its middle again
  /// when every place is covered, so a ✓ is never dropped (design section 5,
  /// decided at device test 3). Only a target later in the picture's order is
  /// drawn over the piece: one under it, as a rocket's body is under its
  /// window, never hides the ✓.
  Offset _checkPlace(int piece, Offset at, Set<int> filled) {
    final over = [
      for (final (j, spec) in puzzle.pieces.indexed)
        if (j > piece && !filled.contains(j)) _path(spec.shape, _targetAt(j), spec.targetAngle),
    ];
    bool covered(Offset place) => over.any((path) => path.contains(place));
    if (!covered(at)) return at;
    final shape = puzzle.pieces[piece].shape;
    final angle = s.pieces[piece].angle;
    for (final place in _checkPlaces(shape, at, angle)) {
      if (shape.contains(place, at, angle) && !covered(place)) return place;
    }
    return at;
  }

  /// The places a ✓ may move to, in order: the piece's middle, then points
  /// part way to each of its corners, or round half a circle's radius.
  Iterable<Offset> _checkPlaces(PieceShape shape, Offset at, double angle) sync* {
    yield at;
    if (shape.circle) {
      for (var k = 0; k < 8; k++) {
        final turn = k * pi / 4;
        yield at + Offset(cos(turn), sin(turn)) * (shape.radius * _checkRingShare);
      }
      return;
    }
    for (final corner in shape.placed(at, angle)) {
      yield at + (corner - at) * _checkCornerShare;
    }
  }

  /// A right drop's ✓ or a wrong one's ✗, drawn as strokes in [colour] over a
  /// wider ink stroke, so it never depends on a font having the glyph (Claude's
  /// 4a review: the look's fonts have neither, and a TV box may have no symbol
  /// font to fall back on). A right drop's mark grows and fades as it
  /// sparkles.
  void _mark(Canvas canvas, Offset at, Color colour, {required bool right, bool small = false, int? ageMs}) {
    final base = small ? _markSmallSize : _markSize;
    final grow = ageMs == null ? 0.0 : PieceMoments.sparkleGrow(ageMs, effects: look.effects);
    final left = ageMs == null ? 0.0 : PieceMoments.sparkleLeft(ageMs, effects: look.effects);
    final half = base * (1 + grow) / 2;
    final colourAt = left > 0 ? colour.withValues(alpha: 1 - left * (1 - _sparkleFloor)) : colour;
    final path = right
        ? (Path()
            ..moveTo(at.dx - half * 0.8, at.dy)
            ..lineTo(at.dx - half * 0.2, at.dy + half * 0.6)
            ..lineTo(at.dx + half * 0.9, at.dy - half * 0.7))
        : (Path()
            ..moveTo(at.dx - half * 0.7, at.dy - half * 0.7)
            ..lineTo(at.dx + half * 0.7, at.dy + half * 0.7)
            ..moveTo(at.dx + half * 0.7, at.dy - half * 0.7)
            ..lineTo(at.dx - half * 0.7, at.dy + half * 0.7));
    final stroke = half * _markStrokeShare;
    Paint line(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = c;
    canvas
      ..drawPath(path, line(_colours.ink.withValues(alpha: colourAt.a), stroke + half * 2 * _markEdgeShare * 2))
      ..drawPath(path, line(colourAt, stroke));
  }
}
