import 'package:protocol/protocol.dart';

import 'match.dart';
import 'puzzle.dart';

/// The phone's panel for [id] (PRD v2 P6): the held piece turning as it
/// turns, the time left and its warning while the match runs, or how the
/// round ended. Someone who didn't join a side only watches.
StatusMessage puzzleStatusFor(PuzzleMatch match, Puzzle puzzle, String id) {
  final game = match.gameFor(id);
  if (game == null) return StatusMessage(text: 'Watching');
  final limit = game.settings.timeLimitS;
  final progress = limit == 0 ? null : game.timeLeftS / limit;
  final warning = game.timeLeftS < game.settings.warningS;
  final left = game.timeLeftS.ceil();
  final result = match.result;
  final side = match.sideOf(id)!;
  final text = result == null
      ? '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')} left'
      : !result.format.split
      ? (result.sides.values.first.finished ? 'Done!' : 'Time\'s up')
      : switch (result.outcomeFor(side)) {
          'win' => 'You won!',
          'loss' => 'They won',
          _ => 'Draw',
        };
  final held = game.player(id)?.held;
  if (held == null) return StatusMessage(text: text, progress: progress, warning: warning);
  final spec = puzzle.pieces[held];
  final r = spec.shape.radius;
  final shape = spec.shape.circle
      ? StatusShape.circle(color: spec.color)
      : StatusShape.polygon(
          [for (final pt in spec.shape.points) (pt.dx / r, pt.dy / r)],
          color: spec.color,
          angle: game.pieces[held].angle,
        );
  return StatusMessage(text: text, shape: shape, progress: progress, warning: warning);
}
