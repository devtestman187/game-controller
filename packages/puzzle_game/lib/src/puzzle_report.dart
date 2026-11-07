import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import 'match.dart';

/// The end of a match as analytics (PRD v2 "Puzzle results"): each player's
/// puzzle metrics, the round's result and the frame counts, plus the winners'
/// success haptic and the success sound.
final class PuzzleReport {
  const PuzzleReport({required this.host, required this.match, required this.game, required this.sound});

  final GameHost host;
  final PuzzleMatch match;

  /// The game's name in analytics records.
  final String game;

  final void Function(String name) sound;

  /// Writes the match's records once, on the step it [result] ended:
  /// a `player_result` per player, then `round_end` and `frames`, for the
  /// [players] here now.
  void write(MatchResult result, {required List<GamePlayer> players, required int frames, required int late}) {
    final winners = <String>[];
    for (final s in match.sides) {
      final outcome = result.outcomeFor(s.side);
      final sideResult = result.sides[s.side]!;
      for (final p in s.game.players) {
        if (outcome == 'win') winners.add(p.id);
        _record(
          'player_result',
          playerId: p.id,
          data: {
            'pickups': p.pickups,
            'snaps': p.snaps,
            'wrongDrops': p.wrongDrops,
            'rotatingS': (p.rotatingS * 10).round() / 10,
            'overshoots': p.overshoots,
            'placed': sideResult.placed,
            'completionS': ?sideResult.timeS,
            if (s.game.team) ...{
              'helpCalls': p.helpCalls,
              'soloBigCarries': p.soloBigCarries,
              'soloBigS': (p.soloBigS * 10).round() / 10,
            },
            'win': outcome == 'win' ? 1 : 0,
            if (result.format.split) 'draw': outcome == 'draw' ? 1 : 0,
          },
        );
      }
    }
    for (final id in winners) {
      host.haptic(id, HapticEventMessage(event: HapticEvent.success));
    }
    if (winners.isNotEmpty) sound('success');
    final first = match.sides.first.game;
    _record(
      'round_end',
      data: {
        'timeS': first.finishTimeS ?? first.elapsedS,
        'puzzle': match.puzzle.id,
        'format': result.format.label,
        'modes': {
          for (final p in players)
            if (match.teams.containsKey(p.id)) p.id: host.gamepad(p.id).mode.name,
        },
        'winners': winners,
        if (result.draw) 'draw': true,
      },
    );
    _record('frames', data: {'drawn': frames, 'late': late});
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      host.record(GameRecord(game: game, name: name, playerId: playerId, data: data));
}
