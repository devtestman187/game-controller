import 'dart:ui' show Color;

import 'package:protocol/protocol.dart';

import 'toy_colors.dart';

/// What a player's character wears on top of its body (M13 design 5b): the
/// accessory that changes its silhouette, so players tell each other apart
/// without colour — about one boy in twelve cannot rely on colour alone.
///
/// The order is the default table's: player 1 wears [ears], player 2
/// [antenna], and so on. Every accessory is drawn in ink and paper (and the
/// body's own colour for the ears) by `paintAccessory`.
enum ToyAccessory {
  /// Two round ears on top of the body, in its own colour.
  ears,

  /// An ink stalk with a paper ball on its tip.
  antenna,

  /// A paper bow at the top-right of the body.
  bow,

  /// A paper cap on top, its brim to the front.
  cap,

  /// Three ink hair strokes on top.
  tuft,

  /// A small paper crown with three points.
  crown;

  /// The accessory's name in words, as the phone's settings list it (M14
  /// design section 9): "round ears", "an antenna", "a bow"…
  String get label => switch (this) {
    ToyAccessory.ears => 'round ears',
    ToyAccessory.antenna => 'an antenna',
    ToyAccessory.bow => 'a bow',
    ToyAccessory.cap => 'a cap',
    ToyAccessory.tuft => 'a tuft',
    ToyAccessory.crown => 'a crown',
  };
}

/// Who a player is shown as (M13 design 5b): a colour and an accessory, never a
/// number on the body. A number stays only in words and on the menus' badges,
/// which have room (design D10).
///
/// This is the only place a player's number becomes a character:
/// [ToyCharacter.forPlayer] gives the defaults, and the worker, the Arena's
/// marble and the menus' badges ask it. When players choose their own (PRD
/// L7), the host will hand each player's choice to the views and only where the
/// character comes from changes — no painter changes.
final class ToyCharacter {
  const ToyCharacter({required this.colourSlot, required this.accessory})
    : assert(colourSlot >= firstSlot && colourSlot <= lastSlot, 'a character wears one of the player colours');

  /// The first and last colour slots a character may wear: the protocol's six
  /// player colours, which players past the sixth reuse in order (design 5b).
  static const firstSlot = 1;
  static const lastSlot = 6;

  /// Player [number]'s default character (design 5b): a colour slot and an
  /// accessory. Numbers past the sixth wrap as the protocol's player colours
  /// do, so player 7 is player 1's character.
  factory ToyCharacter.forPlayer(int number) => ToyCharacter(
    colourSlot: (number - firstSlot) % lastSlot + firstSlot,
    accessory: ToyAccessory.values[(number - firstSlot) % ToyAccessory.values.length],
  );

  /// The character a player is drawn as (M14 L7): the host's [choice], or
  /// [forPlayer] their [number] when they sent none (an older phone, or a
  /// local player).
  factory ToyCharacter.of(PlayerCharacter? choice, int number) => choice == null
      ? ToyCharacter.forPlayer(number)
      : ToyCharacter(colourSlot: choice.colourSlot, accessory: ToyAccessory.values.byName(choice.accessory.name));

  /// The player colours' names in words, by slot (M14 design section 9): the
  /// phone's "Blue is taken tonight, you're Teal" says them.
  static const colourNames = ['Blue', 'Orange', 'Purple', 'Teal', 'Pink', 'Yellow'];

  /// Which of the protocol's player colours the body is drawn in, 1 to 6: the
  /// `player(n)` slot.
  final int colourSlot;

  /// The shape it wears on top of its body.
  final ToyAccessory accessory;

  /// The body colour's name in words, from [colourNames].
  String get colourName => colourNames[colourSlot - firstSlot];

  /// This character's body colour in [colors]: the slot's player colour, the
  /// same on the host and on every phone (design D6).
  Color colourIn(ToyColors colors) => colors.player(colourSlot);

  @override
  bool operator ==(Object other) =>
      other is ToyCharacter && other.colourSlot == colourSlot && other.accessory == accessory;

  @override
  int get hashCode => Object.hash(colourSlot, accessory);

  @override
  String toString() => 'ToyCharacter($colourSlot, ${accessory.name})';
}
