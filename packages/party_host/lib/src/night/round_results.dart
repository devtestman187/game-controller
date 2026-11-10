import 'package:connection/connection.dart' show GamePlayer;
import 'package:game_kit/game_kit.dart' show RoundResult;
import 'package:protocol/protocol.dart';

import 'night_state.dart';

/// Each joined phone's own result of [result]'s round (M14 design section 9),
/// keyed by player id: how the round went for them, their line, their points
/// in a night, and in a night the standings after it.
///
/// [night] is the night the round belongs to, or null outside one; [players]
/// is the roster now, for the standings' names and characters. The night is
/// projected from a copy, so the card shows the round's points before Next
/// records them.
Map<String, ViewResult> viewResultsFor({
  required RoundResult result,
  required NightState? night,
  required List<GamePlayer> players,
}) {
  final after = night?.remember(players).record(result);
  final rows = after?.rows(players) ?? const <NightRow>[];
  final rowsById = {for (final row in rows) row.id: row};
  String nameOf(String id) => _name(rowsById[id]) ?? id;
  final standings = [
    for (final row in rows)
      if (row.number > 0)
        ViewStanding(
          number: row.number,
          name: _name(row) ?? row.id,
          points: row.total,
          character: row.character ?? PlayerCharacter.forPlayer(row.number),
        ),
  ];
  return {
    for (final MapEntry(key: id, value: line) in result.lines.entries)
      id: ViewResult(
        outcome: line.outcome.name,
        timeS: line.timeS,
        count: line.count,
        countOf: line.countOf?.name,
        points: night == null ? null : (result.points[id] ?? 0),
        round: after?.round,
        of: after?.rounds,
        place: rowsById[id]?.place,
        winners: [for (final winner in result.winners) nameOf(winner)],
        standings: standings,
      ),
  };
}

/// A row's name: its nickname, or the player's label when they have none
/// (design section 9: a blank nickname falls back to P and the number).
String? _name(NightRow? row) {
  if (row == null) return null;
  if (row.nickname != null) return row.nickname;
  return row.number > 0 ? 'P${row.number}' : null;
}
