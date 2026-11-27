/// The City Rush board as plain data: districts with one fixed road each, the
/// tokens that walk them, the bolts each player holds, the roadworks that block
/// a tile, and the gates that stand on a road. No rules live here yet; this is
/// the shape the rules and the screens are built on.
library;

/// One square on a road. [id] is unique on the board.
class Tile {
  /// Creates a tile with the given [id].
  const Tile(this.id);

  /// The board-wide id of this tile.
  final String id;
}

/// The last tile of every road, where the walk ends.
final class Plaza extends Tile {
  /// Creates the plaza with the given [id].
  const Plaza(super.id);
}

/// One district: its [id] and its single fixed [road], an ordered list of tiles
/// with no branches, ending at the [Plaza].
final class District {
  /// Creates a district. Throws [ArgumentError] when [road] is empty or does not
  /// end at a [Plaza].
  District({required this.id, required List<Tile> road}) : road = List.unmodifiable(road) {
    if (road.isEmpty) {
      throw ArgumentError.value(road, 'road', 'a road needs at least one tile');
    }
    if (road.last is! Plaza) {
      throw ArgumentError.value(road, 'road', 'a road must end at the Plaza');
    }
  }

  /// The district's id.
  final String id;

  /// The tiles of the road in walking order; the last one is the [Plaza].
  final List<Tile> road;
}

/// A player's piece on the board: which player, where on the road, and whether
/// they have stepped away from the game.
final class Token {
  /// Creates a token for [playerId] standing at [tilePosition] on its road.
  /// [absent] is true while the player is away.
  const Token({required this.playerId, required this.tilePosition, this.absent = false});

  /// The player who owns this token.
  final String playerId;

  /// The index of the tile on the road that this token stands on.
  final int tilePosition;

  /// Whether the player is away, so the token is not moved for them.
  final bool absent;
}

/// The bolts each player holds, by player id. A player not in [byPlayer] holds
/// none.
final class Bolts {
  /// Creates the bolts from [byPlayer], a count of bolts per player id.
  const Bolts(this.byPlayer);

  /// The bolts per player id.
  final Map<String, int> byPlayer;

  /// The bolts [playerId] holds, zero when the player is not in the map.
  int of(String playerId) => byPlayer[playerId] ?? 0;
}

/// Roadworks that block one tile of a road.
final class RoadworksBlock {
  /// Creates a roadworks block on the tile with [tileId].
  const RoadworksBlock({required this.tileId});

  /// The id of the tile this block sits on.
  final String tileId;
}

/// The kinds of gate that can stand on a road.
enum GateKind { brokenBridge, potholeField, riverFerry }

/// A gate on a road. It starts closed. It is shared: one [opened] flag serves
/// every player who walks past it.
final class Gate {
  /// Creates a closed gate of the given [kind].
  Gate({required this.kind});

  /// The kind of gate.
  final GateKind kind;

  bool _opened = false;

  /// Whether the gate is open for every player.
  bool get opened => _opened;

  /// Opens the gate for every player.
  void open() {
    _opened = true;
  }
}
