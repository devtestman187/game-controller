import 'package:toy_look/toy_look.dart';

import 'arena_robo.dart';
import 'arena_roster.dart';

/// The character [id]'s marble wears (design 5b): the one the player chose
/// ([characters], M16 identity), or the default their number gives when they
/// chose none; and for Robo the next free number's colour with the antenna
/// (party-night §7a), so the marble and the robot badge are the same colour on
/// every screen.
ToyCharacter arenaCharacterFor(ArenaRoster roster, String id, {ArenaCharacters characters = const {}}) {
  final number = roster[id]?.number ?? 1;
  final base = ToyCharacter.of(characters[id], number);
  if (id != roboPlayerId) return base;
  return ToyCharacter(colourSlot: base.colourSlot, accessory: ToyAccessory.antenna);
}
