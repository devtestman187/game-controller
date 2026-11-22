import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import 'arena_robo.dart';
import 'arena_snapshot.dart';

/// The players the arena draws, by player ID: their number and name (m12 §3).
/// A frame carries the same map, so the TV and a viewer draw the same sprites.
/// The colour comes from the number when the player chose none, never from the
/// name.
typedef ArenaRoster = Map<String, ({int number, String name})>;

/// The character each player chose, by player ID (M16 identity): the host's
/// players choose, and a frame carries the same map as its `chars`. A player
/// missing here wears the default their number gives, so a seat with no choice
/// (Robo, a local player) still has a character.
typedef ArenaCharacters = Map<String, PlayerCharacter>;

/// The roster of the host's live [players], in the form a frame carries.
ArenaRoster arenaRosterOf(List<GamePlayer> players) => {
  for (final p in players) p.id: (number: p.number, name: p.nickname ?? ''),
};

/// The characters the host's live [players] chose, in the form a frame's
/// `chars` carries: only the players who chose one, so a player with no choice
/// keeps their number's default.
ArenaCharacters arenaCharactersOf(List<GamePlayer> players) => {for (final p in players) p.id: ?p.character};

/// [roster] with Robo in it when [snapshot] has Robo's marble (party-night
/// §7a, M14 b3): Robo is a seat of the round but never a player of the host,
/// so every viewer gives it the next free player's number and the name. Robo
/// chooses no character, so the number gives its colour, and Robo wears the
/// next free player's colour and its antenna, as the design asks.
ArenaRoster arenaRosterFor(ArenaSnapshot snapshot, ArenaRoster roster) {
  if (!snapshot.players.any((p) => p.id == roboPlayerId)) return roster;
  final number = roboNumberFor(roster.values.map((p) => p.number));
  return {...roster, roboPlayerId: (number: number, name: roboName)};
}
