import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'camera.dart';
import 'cat_moments.dart';
import 'piece_moments.dart';
import 'piece_size.dart';
import 'puzzle.dart';
import 'snapshot.dart';
import 'split_layout.dart';
import 'view.dart';
import 'worker_moments.dart';

/// Draws a whole match (S8): one board as [PuzzleView] does, or the split
/// screen, with the clock and both sides' counts along the top and each
/// side's board and tray in its own half, the trays at the outer edges. On
/// phones it draws through [camera] (m12-phone-layout §2): one side's world,
/// or the whole match, with the clock area beside the tray. It draws in the
/// look of the [ToyLookScope] above it, as [PuzzleView] does.
///
/// It lives in its own file, so `view.dart` keeps room for the painters.
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
    this.paused = false,
    this.characters = const {},
    this.clock,
  });

  final Puzzle puzzle;
  final MatchSnapshot snapshot;
  final int? timeLimitS;

  /// Who each player is drawn as, by player number (M16 identity): the
  /// character the host gave them, a missing entry for the default their
  /// number gives. The boards' workers wear it, on the TV and the phone alike.
  final Map<int, ToyCharacter> characters;

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

  /// Whether the round is paused (the pause menu is open): its motion clock
  /// leaves the pause out, so the cat does not jump when play comes back (M14
  /// bugs2 2).
  final bool paused;

  /// Where the view reads the time for the pieces' motion, in milliseconds.
  /// Null: a [Stopwatch] started when the view is built.
  final Stopwatch? clock;

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> {
  final _moments = PieceMoments();
  final _catMoments = CatMoments();
  late final _workers = WorkerMoments(widget.puzzle);

  /// What the boards draw the same way from frame to frame (M14 bugs3 B-016).
  final _cache = BoardCache();
  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  /// How long the round has spent paused, and since when it has been paused, in
  /// ms on [_clock]: a pause leaves the clock running, so the motion clock takes
  /// the paused time out or the cat's slide-in and reach jump on the first frame
  /// back (M14 bugs2 2).
  int _pausedMs = 0;
  int _pausedFromMs = 0;

  int get _nowMs {
    final clockMs = _clock.elapsedMilliseconds;
    return clockMs - _pausedMs - (widget.paused ? clockMs - _pausedFromMs : 0);
  }

  @override
  void initState() {
    super.initState();
    _note();
  }

  @override
  void didUpdateWidget(MatchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another puzzle's board has other slots and pieces: the cache's pictures
    // are this one's (M14 bugs3's still-key finding).
    if (!identical(oldWidget.puzzle, widget.puzzle)) _cache.clear();
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        _pausedFromMs = _clock.elapsedMilliseconds;
      } else {
        _pausedMs += _clock.elapsedMilliseconds - _pausedFromMs;
      }
    }
    if (!identical(oldWidget.snapshot, widget.snapshot)) _note();
  }

  void _note() {
    _moments.observe(widget.snapshot, _nowMs);
    _workers.observe(widget.snapshot, _nowMs);
    _catMoments.observe(widget.snapshot.cat, _nowMs);
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
              catMoments: _catMoments,
              workers: _workers,
              cache: _cache,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              target: widget.target,
              camera: widget.camera,
              padRects: widget.padRects,
              pxPerMm: widget.pxPerMm,
              characters: widget.characters,
              fillsBackground: fills,
            )
          : PuzzlePainter(
              widget.puzzle,
              snapshot.boards.single,
              look: look,
              moments: _moments,
              catMoments: _catMoments,
              workers: _workers,
              cache: _cache,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              cat: snapshot.cat,
              characters: widget.characters,
              fillsBackground: fills,
            ),
    );
  }
}
