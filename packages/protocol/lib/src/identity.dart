part of 'messages.dart';

/// One player in a [PlayersMessage]'s `pl` list: the ID and number a frame's
/// `pl` uses, the player's nickname and the character they wear.
typedef PlayerRow = ({String id, int number, String name, PlayerCharacter character});

/// Host → controller (M16 identity, needs [Capability.identity]): what every
/// player looks like.
///
/// A frame's roster names the players; this message says which character each
/// one wears, so a phone can draw the others as they really are. The host
/// sends it after pairing and again whenever the players or their characters
/// change. A phone that has none draws the number's default
/// ([PlayerCharacter.forPlayer]), as it does with a host one build older.
final class PlayersMessage extends Message {
  const PlayersMessage({required this.players});

  static const String wireType = 'players';

  /// One row per player, in the host's own order.
  final List<PlayerRow> players;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'pl': [
      for (final p in players) {'id': p.id, 'n': p.number, 'name': p.name, 'character': p.character.toJson()},
    ],
  };

  static PlayersMessage fromPayload(Map<String, Object?> p) => PlayersMessage(players: _playerRows(p, 'pl'));
}

/// Controller → host (M16 identity, needs [Capability.identity]): the player
/// chose a character in the phone's settings, and asks for this one.
///
/// The fields are the hello's `character` object, `{"c": 4, "a": "crown"}`.
/// The host gives the player that character, or the nearest free one when
/// another player wears it, and says which in a [PlayerMessage]. A host one
/// build older ignores the message as an unknown type, and the player keeps
/// the character their hello asked for.
final class SetCharacterMessage extends Message {
  const SetCharacterMessage({required this.character});

  static const String wireType = 'set_character';

  /// The character the player asked for.
  final PlayerCharacter character;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => character.toJson();

  static SetCharacterMessage fromPayload(Map<String, Object?> p) =>
      SetCharacterMessage(character: PlayerCharacter._fromFields(p, ''));
}

/// Reads a [PlayersMessage]'s `pl` list. Missing means no players; a field of
/// a row this build doesn't know is ignored.
List<PlayerRow> _playerRows(Map<String, Object?> p, String field) {
  final value = p[field];
  if (value == null) return const [];
  if (value is! List) throw FormatException('Field "$field" must be a list, got ${value.runtimeType}');
  return List.unmodifiable(value.map((row) => _playerRow(row, field)));
}

/// Reads one row of a [PlayersMessage]'s `pl` list: `id` (the player's ID), `n`
/// (their number, from 1), `name` (their nickname, empty when they have none)
/// and `character`.
PlayerRow _playerRow(Object? row, String field) {
  if (row is! Map) throw FormatException('Field "$field" rows must be objects, got ${row.runtimeType}');
  final id = row['id'];
  if (id is! String || id.isEmpty) throw FormatException('Field "$field.id" must be a player ID, got $id');
  final number = row['n'];
  if (number is! int || number < 1) throw FormatException('Field "$field.n" must be 1 or more, got $number');
  final name = row['name'];
  if (name != null && name is! String) {
    throw FormatException('Field "$field.name" must be a string, got ${name.runtimeType}');
  }
  final character = row['character'];
  if (character is! Map) {
    throw FormatException('Field "$field.character" must be an object, got ${character.runtimeType}');
  }
  return (
    id: id,
    number: number,
    name: name is String ? name : '',
    character: PlayerCharacter._fromFields(character.cast<String, Object?>(), 'character.'),
  );
}

/// Reads a field that maps player IDs to `{"c", "a"}` characters, such as a
/// frame's `chars`. Missing means empty.
Map<String, PlayerCharacter> _characterMapField(Map<String, Object?> p, String field) {
  final value = p[field];
  if (value == null) return const {};
  if (value is! Map) throw FormatException('Field "$field" must be an object, got ${value.runtimeType}');
  final characters = <String, PlayerCharacter>{};
  for (final entry in value.entries) {
    final id = entry.key;
    final character = entry.value;
    if (id is! String) throw FormatException('Field "$field" keys must be strings, got ${id.runtimeType}');
    if (character is! Map) {
      throw FormatException('Field "$field" character for "$id" must be an object, got ${character.runtimeType}');
    }
    characters[id] = PlayerCharacter._fromFields(character.cast<String, Object?>(), '$field.$id.');
  }
  return Map.unmodifiable(characters);
}
