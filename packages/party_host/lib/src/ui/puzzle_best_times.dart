import 'package:connection/connection.dart' show GamePlayer;
import 'package:puzzle_game/puzzle_game.dart';

import '../best_times.dart';
import '../text/night_text.dart';

/// One second in milliseconds: what a finished side's `timeS` is turned into
/// for the best times (T15, design section 9 N14).
const _msPerS = 1000;

/// The players on [side]'s board (design 3a): a race's own side, or everyone on
/// a one-board game, whose one side holds them all.
List<GamePlayer> playersOn(
  PuzzleSide side,
  MatchFormat format,
  Map<String, PuzzleSide> teams,
  List<GamePlayer> players,
) => [
  for (final p in players)
    if (teams[p.id] == side || (!format.split && teams.containsKey(p.id))) p,
];

/// Saves each finished side's time on the host (T15, design section 9 N14),
/// with the names of the players on that board: the first time, or a faster
/// one, is a new record. A board that ran out of time sets none.
Map<PuzzleSide, BestTimeResult> recordBestTimes({
  required MatchResult result,
  required Puzzle? puzzle,
  required Map<String, PuzzleSide> teams,
  required List<GamePlayer> players,
  required BestTimesNotifier times,
}) {
  if (puzzle == null) return const {};
  final boards = <PuzzleSide, BestTimeResult>{};
  for (final side in result.sides.keys) {
    final board = result.sides[side];
    final timeS = board?.timeS;
    if (board == null || !board.finished || timeS == null) continue;
    final onSide = playersOn(side, result.format, teams, players);
    boards[side] = times.record(
      puzzleId: puzzle.id,
      team: onSide.length > 1,
      timeMs: (timeS * _msPerS).round(),
      names: [for (final p in onSide) NightText.playerName(p.nickname, p.number)],
    );
  }
  return boards;
}
