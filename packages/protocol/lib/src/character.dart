part of 'messages.dart';

/// What a player's character wears on top of its body (M14 L7): the shapes the
/// look draws, in the look's order. The wire names are the enum's own, so a
/// host one build older ignores the field and a newer one reads it.
enum PlayerAccessory { ears, antenna, bow, cap, tuft, crown }

/// The character a player asks for in the hello (M14 L7, design section 9): a
/// colour slot and an accessory. The host gives each player one that no other
/// player wears, first come first served ([nearestFreeIn]), and every screen
/// draws the host's choice.
///
/// The defaults are the look's own: [forPlayer] gives player 1 slot 1 and the
/// ears, player 2 slot 2 and the antenna, and so on. Protocol only, so a host
/// a build older can ignore it.
final class PlayerCharacter {
  /// Player [number]'s default character (M14 design section 9): their colour
  /// slot and the accessory at their place in the list, wrapping past the
  /// sixth as the colours do.
  factory PlayerCharacter.forPlayer(int number) => PlayerCharacter(
    colourSlot: (number - firstSlot) % lastSlot + firstSlot,
    accessory: PlayerAccessory.values[(number - firstSlot) % PlayerAccessory.values.length],
  );
  const PlayerCharacter({required this.colourSlot, required this.accessory})
    : assert(colourSlot >= firstSlot && colourSlot <= lastSlot, 'a character wears one of the player colours');

  /// The first and last colour slot a character may wear: the protocol's six
  /// player colours ([playerColors]).
  static const firstSlot = 1;
  static const lastSlot = 6;

  /// The colour names that start a character's [id] (M16 identity), by slot:
  /// the look's own names, Blue first and in lower case, so a character's ID
  /// and its spoken name use the same word for each colour.
  static const colourIds = ['blue', 'orange', 'purple', 'teal', 'pink', 'yellow'];

  /// Which of the player colours the body is, 1 to 6.
  final int colourSlot;

  /// The shape it wears on top of its body.
  final PlayerAccessory accessory;

  /// This character's stable ID (M16 identity), `<colour>.<accessory>` such as
  /// `blue.ears`: the same on every build and in every game, so a saved score
  /// or a spoken name finds the same character. It names the character, never
  /// the player: the number and nickname are not part of it, and all 36 are
  /// unique.
  String get id => '${colourIds[colourSlot - firstSlot]}.${accessory.name}';

  /// The character [id] names, `blue.ears`. Throws [FormatException] for
  /// anything else, such as a colour a newer build knows.
  static PlayerCharacter fromId(String id) {
    final parts = id.split('.');
    final index = parts.length == 2 ? colourIds.indexOf(parts[0]) : -1;
    final accessory = parts.length == 2 ? PlayerAccessory.values.where((a) => a.name == parts[1]).firstOrNull : null;
    if (index < 0 || accessory == null) {
      throw FormatException('Unknown character ID "$id": expected <colour>.<accessory>, e.g. blue.ears');
    }
    return PlayerCharacter(colourSlot: index + firstSlot, accessory: accessory);
  }

  /// This choice, with the nearest free colour and accessory when players
  /// already wear [taken] (M14 design section 9): colour and accessory are
  /// each unique among the players, and a player asking for a taken one gets
  /// the nearest free one. A tie goes to the later slot. When nothing is free
  /// the choice stands, so a seventh player still has a character.
  PlayerCharacter nearestFreeIn(Iterable<PlayerCharacter> taken) {
    final colours = {for (final c in taken) c.colourSlot};
    final accessories = {for (final c in taken) c.accessory};
    return PlayerCharacter(
      colourSlot: _nearest(colourSlot, firstSlot, lastSlot, (s) => !colours.contains(s)),
      accessory:
          PlayerAccessory.values[_nearest(
            accessory.index,
            0,
            PlayerAccessory.values.length - 1,
            (i) => !accessories.contains(PlayerAccessory.values[i]),
          )],
    );
  }

  /// The nearest value to [wanted] in [first]..[last] that [free] accepts: the
  /// wanted one, then each distance up before the one down, so a tie goes to
  /// the later value. [wanted] when none is free.
  static int _nearest(int wanted, int first, int last, bool Function(int) free) {
    for (var d = 0; wanted + d <= last || wanted - d >= first; d++) {
      if (wanted + d <= last && free(wanted + d)) return wanted + d;
      if (d != 0 && wanted - d >= first && free(wanted - d)) return wanted - d;
    }
    return wanted;
  }

  /// The wire form, `{"c": 4, "a": "crown"}`: short keys, the field is sent
  /// with every hello.
  Map<String, Object?> toJson() => {'c': colourSlot, 'a': accessory.name};

  /// Reads [json], which must hold a colour slot 1 to 6 and a known
  /// accessory's name.
  static PlayerCharacter fromJson(Object? json) {
    if (json is! Map) throw FormatException('Field "character" must be an object, got ${json.runtimeType}');
    return _fromFields(json.cast<String, Object?>(), 'character.');
  }

  /// Reads the `c` and `a` fields of a `{"c", "a"}` object, naming [prefix] in
  /// an error: `character.` for the hello's object, none for a
  /// [SetCharacterMessage]'s own fields, `chars.<id>.` for a frame's entry.
  static PlayerCharacter _fromFields(Map<String, Object?> json, String prefix) {
    final slot = json['c'];
    if (slot is! int || slot < firstSlot || slot > lastSlot) {
      throw FormatException('Field "${prefix}c" must be a colour slot $firstSlot to $lastSlot, got $slot');
    }
    final name = json['a'];
    final accessory = name is String ? PlayerAccessory.values.where((a) => a.name == name).firstOrNull : null;
    if (accessory == null) {
      throw FormatException(
        'Field "${prefix}a" must be one of ${PlayerAccessory.values.map((a) => a.name).join(', ')}, got $name',
      );
    }
    return PlayerCharacter(colourSlot: slot, accessory: accessory);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerCharacter && other.colourSlot == colourSlot && other.accessory == accessory;

  @override
  int get hashCode => Object.hash(colourSlot, accessory);

  @override
  String toString() => 'PlayerCharacter($colourSlot, ${accessory.name})';
}

/// Player colours as 0xAARRGGBB, used for the sprite on the TV and the badge
/// on the phone. Players past the end reuse them in order.
///
/// The values are the look's (M13, design D6 and D12): bright enough for the
/// toy palette, and dark ink reads at 4.5:1 on every one of them. Player 3 is
/// `0xFFA66CFF`, lightened from the mock-ups' `0xFF9B5CFF`, which failed that
/// rule. The look package reads this one list, so a player is the same colour
/// on the host and on every phone.
const playerColors = [0xFF2E9BF0, 0xFFFF8A1F, 0xFFA66CFF, 0xFF14C8A0, 0xFFFF5C8A, 0xFFF2C200];

/// Player [number]'s colour, wrapping round once the palette runs out.
int playerColor(int number) => playerColors[(number - 1) % playerColors.length];
