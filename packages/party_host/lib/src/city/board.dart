/// The City Rush board as plain data: districts with one road each, the tokens that
/// walk them, the bolts each player holds, and the one gate of the night. The night's
/// gate goes on a rival's next unbuilt tile, chosen by the mid-night gate game; the
/// board holds at most one gate. No rules live here; the rules are in `rules.dart`.
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

/// The whole board: its districts and the night's one gate. Every district id and every
/// tile id is unique across the board, so a tile can be named by its id alone. A gate
/// stands on a road of this board, on any tile of it, the Plaza included.
final class Board {
  /// Creates a board from [districts]. Throws [ArgumentError] when two districts share
  /// an id, or when a tile id appears more than once across the roads.
  Board({required List<District> districts}) : districts = List.unmodifiable(districts) {
    final districtIds = <String>{};
    final tileIds = <String>{};
    for (final district in districts) {
      if (!districtIds.add(district.id)) {
        throw ArgumentError.value(district.id, 'districts', 'a district id must be unique on the board');
      }
      for (final tile in district.road) {
        if (!tileIds.add(tile.id)) {
          throw ArgumentError.value(tile.id, 'districts', 'a tile id must be unique on the board');
        }
      }
    }
  }

  /// The districts on the board, in the order they were given.
  final List<District> districts;

  Gate? _gate;

  bool _gateOpen = false;

  /// The night's gate, or null while no gate has been placed. The mid-night gate game
  /// places at most one, so a new night, which builds a new [Board], starts with none.
  Gate? get gate => _gate;

  /// Whether the gate is open. One flag serves every player, so a gate opened for one
  /// player is open for all of them. It stays open for the night.
  bool get gateOpen => _gateOpen;

  /// Places the night's gate. Throws [ArgumentError] when the road is not on the board
  /// or the tile index is not a tile of that road, and [StateError] when a gate is
  /// already placed: one gate per night.
  void placeGate(Gate gate) {
    final road = _roadOf(gate.roadId);
    if (road == null) {
      throw ArgumentError.value(gate.roadId, 'gate', 'a gate must stand on a road on the board');
    }
    if (gate.tileIndex < 0 || gate.tileIndex >= road.length) {
      throw ArgumentError.value(gate.tileIndex, 'gate', 'a gate must stand on a tile of its road');
    }
    if (_gate != null) {
      throw StateError('a night has one gate, and one is already placed');
    }
    _gate = gate;
  }

  /// Opens the placed gate for every player. Throws [StateError] when no gate is placed.
  void openGate() {
    if (_gate == null) {
      throw StateError('no gate is placed, so there is none to open');
    }
    _gateOpen = true;
  }

  /// The tiles of the road named [roadId], or null when no district on the board has it.
  List<Tile>? _roadOf(String roadId) {
    for (final district in districts) {
      if (district.id == roadId) {
        return district.road;
      }
    }
    return null;
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
