import 'package:connection/connection.dart';
import 'package:toy_look/toy_look.dart';

import 'arena_robo.dart';
import 'arena_snapshot.dart';

/// The players the arena draws, by player ID: their number and name (m12 §3).
/// A frame carries the same map, so the TV and a viewer draw the same sprites.
/// The colour comes from the number (`playerColor`), never from the name.
typedef ArenaRoster = Map<String, ({int number, String name})>;

/// The roster of the host's live [players], in the form a frame carries.
ArenaRoster arenaRosterOf(List<GamePlayer> players) => {
  for (final p in players) p.id: (number: p.number, name: p.nickname ?? ''),
};

/// [roster] with Robo in it when [snapshot] has Robo's marble (party-night
/// §7a, M14 b3): Robo is a seat of the round but never a player of the host,
/// so every viewer gives it the next free player's number and the name. The
/// number is what the marble's colour comes from, so Robo wears the next free
/// player's colour and its antenna, as the design asks.
ArenaRoster arenaRosterFor(ArenaSnapshot snapshot, ArenaRoster roster) {
  if (!snapshot.players.any((p) => p.id == roboPlayerId)) return roster;
  final number = roboNumberFor(roster.values.map((p) => p.number));
  return {...roster, roboPlayerId: (number: number, name: roboName)};
}

/// The character [id]'s marble wears (design 5b): its number's colour and
/// accessory, and for Robo its number's colour with the antenna (party-night
/// §7a), so the marble and the robot badge are the same colour on every screen.
ToyCharacter arenaCharacterFor(ArenaRoster roster, String id) {
  final number = roster[id]?.number ?? 1;
  final base = ToyCharacter.forPlayer(number);
  if (id != roboPlayerId) return base;
  return ToyCharacter(colourSlot: base.colourSlot, accessory: ToyAccessory.antenna);
}
