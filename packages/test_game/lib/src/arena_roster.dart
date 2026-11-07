import 'package:connection/connection.dart';

/// The players the arena draws, by player ID: their number and name (m12 §3).
/// A frame carries the same map, so the TV and a viewer draw the same sprites.
/// The colour comes from the number (`playerColor`), never from the name.
typedef ArenaRoster = Map<String, ({int number, String name})>;

/// The roster of the host's live [players], in the form a frame carries.
ArenaRoster arenaRosterOf(List<GamePlayer> players) => {
  for (final p in players) p.id: (number: p.number, name: p.nickname ?? ''),
};
