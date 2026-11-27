import 'package:puzzle_game/puzzle_game.dart' show Level;

import '../night/variant.dart';

/// The longest vote card title: an old phone cuts a button label at 12 characters, so a longer title would not read
/// the same on both phones.
const maxVariantLabelLength = 12;

/// The bundled maps' names by id. test_game keeps the same list but does not export it; no test compares the
/// two yet (code-health "night2b notes"), so keep this copy in step by hand.
const mapNames = <String, String>{
  'playroom': 'Playroom',
  'pinball': 'Pinball',
  'block-castle': 'Block Castle',
  'toy-factory': 'Toy Factory',
  'spinning-tops': 'Spinning Tops',
};

/// The fixed short name of a map whose own name is longer than [maxVariantLabelLength].
const _longMapShortNames = <String, String>{'spinning-tops': 'Spinning Top'};

/// Words of the vote round (M17 night2b), kept apart from [NightText] like the other round texts.
abstract final class VoteText {
  /// The question the phones show above the vote cards.
  static const title = 'Pick the next game';

  /// The line over an open vote on the TV.
  static const voteNow = 'Vote on your phones!';

  /// The title of the vote before round 1.
  static const firstGame = 'Vote for the first game';

  /// The countdown of the open vote, [seconds] whole seconds left.
  static String secondsLeft(int seconds) => '$seconds s';

  /// The line when [name] won the vote with the most votes.
  static String wins(String name) => '$name wins!';

  /// The line when [name] was drawn at random, after a tie or with no vote.
  static String byChance(String name) => '$name by luck!';
}

/// The map's name for a card: its own name, or the id when the map has none listed.
String _mapName(String mapId) => mapNames[mapId] ?? mapId;

/// The title of [variant]'s vote card, at most [maxVariantLabelLength] characters.
String variantLabel(Variant variant) {
  final mapId = variant.mapId ?? '';
  switch (variant.game) {
    case VariantGame.shapeRace:
      return switch (variant.tier) {
        Level.easy => 'Shapes Easy',
        Level.medium => 'Shapes Med',
        Level.hard => 'Shapes Hard',
      };
    case VariantGame.bumperRound:
      final name = _mapName(mapId);
      if (name.length <= maxVariantLabelLength) return name;
      return _longMapShortNames[mapId] ?? _cut(name);
    case VariantGame.arenaRace:
      return _cut('Race ${_mapName(mapId)}');
  }
}

/// The full name of [variant] for the vote card's detail line.
String variantDetail(Variant variant) {
  final mapId = variant.mapId ?? '';
  return switch (variant.game) {
    VariantGame.shapeRace => 'Shape Race, ${variant.tier.name}',
    VariantGame.bumperRound => 'Bumper Round on ${_mapName(mapId)}',
    VariantGame.arenaRace => 'Arena Race on ${_mapName(mapId)}',
  };
}

String _cut(String text) => text.length <= maxVariantLabelLength ? text : text.substring(0, maxVariantLabelLength);
