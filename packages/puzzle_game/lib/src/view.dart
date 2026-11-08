import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show playerColor, playerColors;

import 'camera.dart';
import 'game.dart';
import 'match.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'snapshot.dart';
import 'split_layout.dart';

part 'match_painter.dart';
part 'mirror_painter.dart';
part 'puzzle_painter.dart';

/// Draws a puzzle from a [PuzzleSnapshot] (PRD v2 S8) into the box it's
/// given, keeping the field's 16:9 shape and centring it (S4). It never
/// reads the screen size, so the same view works on a TV, in a window, or
/// drawn off-screen for a stream.
class PuzzleView extends StatelessWidget {
  const PuzzleView({super.key, required this.puzzle, required this.snapshot, this.timeLimitS});

  final Puzzle puzzle;
  final PuzzleSnapshot snapshot;

  /// For the clock's bar. Null: no bar.
  final int? timeLimitS;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('puzzleView'),
    size: Size.infinite,
    painter: PuzzlePainter(puzzle, snapshot, timeLimitS: timeLimitS),
  );
}

/// Draws a whole match (S8): one board as [PuzzleView] does, or the split
/// screen, with the clock and both sides' counts along the top and each
/// side's board and tray in its own half, the trays at the outer edges. On
/// phones it draws through [camera] (m12-phone-layout §2): one side's world,
/// or the whole match, with the clock area beside the tray.
class MatchView extends StatelessWidget {
  const MatchView({
    super.key,
    required this.puzzle,
    required this.snapshot,
    this.timeLimitS,
    this.target = LayoutTarget.screen,
    this.camera = const PuzzleCamera.whole(),
    this.padRects = const [],
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

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('puzzleView'),
    size: Size.infinite,
    painter: snapshot.split || target == LayoutTarget.phones
        ? MatchPainter(puzzle, snapshot, timeLimitS: timeLimitS, target: target, camera: camera, padRects: padRects)
        : PuzzlePainter(puzzle, snapshot.boards.single, timeLimitS: timeLimitS),
  );
}

const _background = Color(0xFF14181F);
const _wrong = Color(0xFFE53935);

/// A right answer's mark, and the phone HUD's time bar while the clock has
/// time left (m12-phone-layout §0.7c).
const _right = Color(0xFF43D17A);

/// The panel a phone's HUD sits on when it has no room beside the world, over
/// the board's top-left corner (m12-phone-layout §0.7c): 55% black, so the
/// board stays visible behind the texts.
const _hudPanel = Color(0x8C000000);

/// The board's panel, on the split screen and in the other side's mirror
/// (m12-opponent-mirror rule 1).
const _board = Color(0xFF242B36);

/// The orange that marks the other side (m12-opponent-mirror rule 4): the
/// mirror's frame, their dot and their count. Player 2's colour from the
/// protocol's palette — [playerColors]' second entry — so a re-skin moves the
/// mirror with the pads' badges, as the look-and-sound milestone will
/// (code-health, the look row).
final _them = Color(playerColors[1]);
