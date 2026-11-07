import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show playerColor;

import 'game.dart';
import 'puzzle.dart';
import 'snapshot.dart';
import 'split_layout.dart';

part 'match_painter.dart';
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
/// side's board and tray in its own half, the trays at the outer edges.
class MatchView extends StatelessWidget {
  const MatchView({super.key, required this.puzzle, required this.snapshot, this.timeLimitS});

  final Puzzle puzzle;
  final MatchSnapshot snapshot;
  final int? timeLimitS;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('puzzleView'),
    size: Size.infinite,
    painter: snapshot.split
        ? MatchPainter(puzzle, snapshot, timeLimitS: timeLimitS)
        : PuzzlePainter(puzzle, snapshot.boards.single, timeLimitS: timeLimitS),
  );
}

/// The field of size [field] in [box]: the scale and the offset of its top
/// left.
({double scale, Offset origin}) fieldIn(Size box, [Size field = fieldSize]) {
  final scale = min(box.width / field.width, box.height / field.height);
  final origin = Offset((box.width - field.width * scale) / 2, (box.height - field.height * scale) / 2);
  return (scale: scale, origin: origin);
}

const _background = Color(0xFF14181F);
const _wrong = Color(0xFFE53935);
