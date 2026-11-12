import 'dart:math';
import 'dart:ui' show FragmentProgram;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'camera.dart';
import 'cat_view.dart';
import 'celebration.dart';
import 'game.dart';
import 'piece_moments.dart';
import 'piece_size.dart';
import 'points.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'snapshot.dart';
import 'split_layout.dart';
import 'worker_moments.dart';

part 'board_hud.dart';
part 'cat_paint.dart';
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
  const PuzzleView({super.key, required this.puzzle, required this.snapshot, this.timeLimitS, this.clock});

  final Puzzle puzzle;
  final PuzzleSnapshot snapshot;

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
  late final _workers = WorkerMoments(widget.puzzle);
  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  /// The one board as the match the moments see it: they are kept per board,
  /// as a match keeps its left and right.
  MatchSnapshot get _match => MatchSnapshot(boards: [widget.snapshot]);

  int get _nowMs => _clock.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _note(_match);
  }

  @override
  void didUpdateWidget(PuzzleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) _note(_match);
  }

  void _note(MatchSnapshot match) {
    _moments.observe(match, _nowMs);
    _workers.observe(match, _nowMs);
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
      workers: _workers,
      nowMs: _nowMs,
      timeLimitS: widget.timeLimitS,
      // The screen's sky shows round the board and the tray where a
      // `ToyBackground` is behind the view (design section 5, decided at
      // device test 3); drawn alone, as the pictures are, the painter fills.
      fillsBackground: !toyStillSkyAbove(context),
    ),
  );
}

/// Draws a whole match (S8): one board as [PuzzleView] does, or the split
/// screen, with the clock and both sides' counts along the top and each
/// side's board and tray in its own half, the trays at the outer edges. On
/// phones it draws through [camera] (m12-phone-layout §2): one side's world,
/// or the whole match, with the clock area beside the tray. It draws in the
/// look of the [ToyLookScope] above it, as [PuzzleView] does.
class MatchView extends StatefulWidget {
  const MatchView({
    super.key,
    required this.puzzle,
    required this.snapshot,
    this.timeLimitS,
    this.target = LayoutTarget.screen,
    this.camera = const PuzzleCamera.whole(),
    this.padRects = const [],
    this.pxPerMm = phonePxPerMm,
    this.clock,
  });

  final Puzzle puzzle;
  final MatchSnapshot snapshot;
  final int? timeLimitS;

  /// The world the match plays in, from the setup (m12 §0.4).
  final LayoutTarget target;

  /// What the box shows, for a phone (m12-phone-layout §2). The screen always
  /// draws the whole match.
  final PuzzleCamera camera;

  /// Where the app draws this phone's pad, in the box's px, which the other
  /// side's mirror keeps clear of (m12-opponent-mirror rule 3, code-health
  /// N4): the pad is the app's, so the game is told where it is rather than
  /// knowing it (rule 6). Empty where nothing is drawn over the game (the TV,
  /// a tablet, "Show on this device").
  final List<Rect> padRects;

  /// This phone's px per millimetre, which the mirror keeps its marks above
  /// (m12-opponent-mirror rule 7): the app's own reading, as [padRects] is its
  /// own geometry.
  final double pxPerMm;

  /// Where the view reads the time for the pieces' motion, in milliseconds.
  /// Null: a [Stopwatch] started when the view is built.
  final Stopwatch? clock;

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> {
  final _moments = PieceMoments();
  late final _workers = WorkerMoments(widget.puzzle);
  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  int get _nowMs => _clock.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _note();
  }

  @override
  void didUpdateWidget(MatchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) _note();
  }

  void _note() {
    _moments.observe(widget.snapshot, _nowMs);
    _workers.observe(widget.snapshot, _nowMs);
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final snapshot = widget.snapshot;
    // As [PuzzleView] does: the sky shows round the boards where there is one.
    final fills = !toyStillSkyAbove(context);
    return CustomPaint(
      key: const Key('puzzleView'),
      size: Size.infinite,
      painter: snapshot.split || widget.target == LayoutTarget.phones
          ? MatchPainter(
              widget.puzzle,
              snapshot,
              look: look,
              moments: _moments,
              workers: _workers,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              target: widget.target,
              camera: widget.camera,
              padRects: widget.padRects,
              pxPerMm: widget.pxPerMm,
              fillsBackground: fills,
            )
          : PuzzlePainter(
              widget.puzzle,
              snapshot.boards.single,
              look: look,
              moments: _moments,
              workers: _workers,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              cat: snapshot.cat,
              fillsBackground: fills,
            ),
    );
  }
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
