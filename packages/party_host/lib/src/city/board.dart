/// The City Rush board as plain data: districts with one road each, the tokens that
/// walk them, the bolts each player holds, the roadworks that block a tile, and the
/// gates that stand on a road. No rules live here; the rules are in `rules.dart`.
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
/// with no branches, ending at the [Plaza]. A corner road has no [laneOf]; a lane
/// beside a corner names that corner's id in [laneOf].
final class District {
  /// Creates a district. Throws [ArgumentError] when [road] is empty or does not
  /// end at a [Plaza].
  District({required this.id, required List<Tile> road, this.laneOf}) : road = List.unmodifiable(road) {
    if (road.isEmpty) {
      throw ArgumentError.value(road, 'road', 'a road needs at least one tile');
    }
    if (road.last is! Plaza) {
      throw ArgumentError.value(road, 'road', 'a road must end at the Plaza');
    }
  }

  /// The district's id; a token's road is named by this id.
  final String id;

  /// The id of the corner road this lane sits beside, or null for a corner road.
  final String? laneOf;

  /// The tiles of the road in walking order; the last one is the [Plaza].
  final List<Tile> road;
}

/// The whole board: its districts and its gates. Every district id and every tile id
/// is unique across the board, so a tile can be named by its id alone. Every gate
/// stands on a road of this board, on a tile before its Plaza.
final class Board {
  /// Creates a board from [districts] and [gates]. Throws [ArgumentError] when two
  /// districts share an id, when a tile id appears more than once across the roads,
  /// or when a gate stands on no road of the board or on the Plaza.
  Board({required List<District> districts, required List<Gate> gates})
    : districts = List.unmodifiable(districts),
      gates = List.unmodifiable(gates) {
    final districtIds = <String>{};
    final tileIds = <String>{};
    final roadsById = <String, List<Tile>>{};
    for (final district in districts) {
      if (!districtIds.add(district.id)) {
        throw ArgumentError.value(district.id, 'districts', 'a district id must be unique on the board');
      }
      roadsById[district.id] = district.road;
      for (final tile in district.road) {
        if (!tileIds.add(tile.id)) {
          throw ArgumentError.value(tile.id, 'districts', 'a tile id must be unique on the board');
        }
      }
    }
    for (final gate in gates) {
      final road = roadsById[gate.roadId];
      if (road == null) {
        throw ArgumentError.value(gate.roadId, 'gates', 'a gate must stand on a road on the board');
      }
      if (gate.tileIndex < 0 || gate.tileIndex >= road.length - 1) {
        throw ArgumentError.value(gate.tileIndex, 'gates', 'a gate must stand on a tile before the Plaza');
      }
    }
  }

  /// The districts on the board, in the order they were given.
  final List<District> districts;

  /// The gates on the board, in the order they were given.
  final List<Gate> gates;

  bool _gatesOpen = false;

  /// Whether the gates are open. One flag serves every player, so a gate opened for
  /// one player is open for all of them. The gates stay open for the night; a new night
  /// builds a new [Board], so there is no reset method.
  bool get gatesOpen => _gatesOpen;

  /// Opens every gate on the board for every player.
  void openAllGates() {
    _gatesOpen = true;
  }
}

/// A player's piece on the board: which player, which road, where on that road, and
/// whether they have stepped away from the game.
final class Token {
  /// Creates a token for [playerId] on the road named [roadId], standing at
  /// [tilePosition]. [absent] is true while the player is away.
  const Token({required this.playerId, required this.roadId, required this.tilePosition, this.absent = false});

  /// The player who owns this token.
  final String playerId;

  /// The id of the district whose road this token walks.
  final String roadId;

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
enum GateKind {
  /// A bridge that is out until it is opened.
  brokenBridge,

  /// A stretch of road full of potholes that gates the way through.
  potholeField,

  /// A river crossing reached by a ferry.
  riverFerry,
}

/// A gate on the road named [roadId], standing on the tile at [tileIndex]. Whether it
/// is open is a board-wide flag, so a gate has no open state of its own.
final class Gate {
  /// Creates a gate of [kind] on the tile at [tileIndex] of the road named [roadId].
  const Gate({required this.roadId, required this.tileIndex, required this.kind});

  /// The id of the district whose road this gate stands on.
  final String roadId;

  /// The index of the tile on that road where the gate stands.
  final int tileIndex;

  /// The kind of gate.
  final GateKind kind;
}
