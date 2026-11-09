import 'dart:math';
import 'dart:ui' show FragmentProgram;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'camera.dart';
import 'game.dart';
import 'match.dart';
import 'piece_moments.dart';
import 'piece_size.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'snapshot.dart';
import 'split_layout.dart';

part 'board_hud.dart';
part 'match_hud.dart';
part 'match_painter.dart';
part 'mirror_painter.dart';
part 'puzzle_painter.dart';
part 'text_paint.dart';

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
  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  /// The one board as the match the moments see it: they are kept per board,
  /// as a match keeps its left and right.
  MatchSnapshot get _match => MatchSnapshot(boards: [widget.snapshot]);

  int get _nowMs => _clock.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _moments.observe(_match, _nowMs);
  }

  @override
  void didUpdateWidget(PuzzleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) _moments.observe(_match, _nowMs);
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
      nowMs: _nowMs,
      timeLimitS: widget.timeLimitS,
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
  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  int get _nowMs => _clock.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _moments.observe(widget.snapshot, _nowMs);
  }

  @override
  void didUpdateWidget(MatchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) _moments.observe(widget.snapshot, _nowMs);
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final snapshot = widget.snapshot;
    return CustomPaint(
      key: const Key('puzzleView'),
      size: Size.infinite,
      painter: snapshot.split || widget.target == LayoutTarget.phones
          ? MatchPainter(
              widget.puzzle,
              snapshot,
              look: look,
              moments: _moments,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              target: widget.target,
              camera: widget.camera,
              padRects: widget.padRects,
              pxPerMm: widget.pxPerMm,
            )
          : PuzzlePainter(
              widget.puzzle,
              snapshot.boards.single,
              look: look,
              moments: _moments,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
            ),
    );
  }
}
