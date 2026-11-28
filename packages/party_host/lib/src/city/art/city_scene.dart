/// The City Rush board's changing state as one frame's picture data (M17 map2a): how many tiles each
/// road has built, where each token stands, the gate, the roadworks cone and each player's Bolts
/// chip. [CityScene.from] turns a [CitySnapshot] into it with no drawing and no clock, so the same
/// snapshot always gives the same scene.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../board.dart';
import '../rules.dart';
import 'city_layout.dart';

/// How far apart the Bolts chips sit along the row under the Centre Plaza, in tiles.
const cityChipSpacingTiles = 1.1;

/// How far below the Centre Plaza's middle the row of Bolts chips sits, in tiles: clear of the Plaza.
const cityChipDropTiles = 1.0;

/// How far above the Centre Plaza's middle the roadworks cone stands, in tiles.
const cityConeRiseTiles = 1.0;

/// How many players get a colour on the board. From the next player on, a token shows a number badge.
const cityColouredSlots = 6;

/// What the board shows this frame, as plain values the game already holds.
final class CitySnapshot {
  /// Creates a snapshot. [tilesBuilt] counts the built tiles of each road by road id; a road not
  /// in it has none built. [bolts] is null while no Bolts chips are shown.
  const CitySnapshot({
    required this.board,
    required this.rules,
    required this.tilesBuilt,
    required this.tokens,
    required this.bolts,
    required this.roadworks,
  });

  /// The districts and the gate.
  final Board board;

  /// The rules the night plays by: the road length.
  final CityRules rules;

  /// The built tiles of each road, by road id.
  final Map<String, int> tilesBuilt;

  /// Every player's token, one per player.
  final List<Token> tokens;

  /// The Bolts each player holds, or null when the chips are not shown.
  final Bolts? bolts;

  /// Whether a roadworks cone stands on the board this frame.
  final bool roadworks;
}

/// One road's state in a [CityScene].
final class CityRoadScene {
  /// Creates the state of the road named [roadId], which has [roadLength] tiles including the
  /// Plaza and [builtTiles] built.
  const CityRoadScene({
    required this.roadId,
    required this.roadLength,
    required this.builtTiles,
    required this.complete,
  });

  /// The id of the district whose road this is.
  final String roadId;

  /// The number of tiles on the road, the Plaza included.
  final int roadLength;

  /// How many tiles are built, from 0 to [roadLength]. The Plaza is never built on, so tiles
  /// from index [roadLength] - 1 on are not drawn as built.
  final int builtTiles;

  /// Whether every tile before the Plaza is built.
  final bool complete;
}

/// One token's place in a [CityScene].
final class CityTokenScene {
  /// Creates the placement of [playerId]'s token at [centre], with the colour of [slot].
  const CityTokenScene({
    required this.playerId,
    required this.slot,
    required this.centre,
    required this.absent,
    required this.badgeNumber,
  });

  /// The player who owns the token.
  final String playerId;

  /// The player's place in the order the tokens were given, from 0.
  final int slot;

  /// Where the token's middle is on the screen.
  final Offset centre;

  /// Whether the player is away, so the token is drawn dimmed.
  final bool absent;

  /// The number a badge shows: the slot plus one from the seventh player on, else null.
  final int? badgeNumber;
}

/// The gate's place in a [CityScene].
final class CityGateScene {
  /// Creates the gate's marker at [centre], open or not.
  const CityGateScene({required this.centre, required this.open});

  /// The middle of the gate's tile on the screen.
  final Offset centre;

  /// Whether the gate is open for every player.
  final bool open;
}

/// One player's Bolts chip in a [CityScene].
final class CityChipScene {
  /// Creates the chip of [playerId], which shows [bolts], at [centre].
  const CityChipScene({required this.playerId, required this.bolts, required this.centre});

  /// The player the chip counts.
  final String playerId;

  /// The Bolts the player holds.
  final int bolts;

  /// The chip's middle on the screen.
  final Offset centre;
}

/// The moving layer of the board in one frame: what [CityOverlayPainter] paints.
final class CityScene {
  /// Creates a scene from its parts.
  const CityScene({
    required this.roads,
    required this.tokens,
    required this.gate,
    required this.roadworksCone,
    required this.chips,
  });

  /// Builds the scene that [snapshot] shows on [layout]. Pure: the same input gives the same
  /// scene. Throws what [CityLayout.tileCenter] throws when a token or the gate stands off its road.
  static CityScene from(CitySnapshot snapshot, CityLayout layout) {
    final players = <String>[];
    for (final token in snapshot.tokens) {
      if (!players.contains(token.playerId)) players.add(token.playerId);
    }
    return CityScene(
      roads: [for (final district in snapshot.board.districts) _roadOf(district.id, snapshot)],
      tokens: [for (final token in snapshot.tokens) _tokenOf(token, players.indexOf(token.playerId), layout)],
      gate: _gateOf(snapshot.board, layout),
      roadworksCone: snapshot.roadworks,
      chips: _chipsOf(snapshot.bolts, players, layout),
    );
  }

  /// The state of every road on the board, in the board's order.
  final List<CityRoadScene> roads;

  /// Every token's place, in the order the snapshot gave them.
  final List<CityTokenScene> tokens;

  /// The gate's marker, or null while no gate is placed.
  final CityGateScene? gate;

  /// Whether the roadworks cone stands on the board.
  final bool roadworksCone;

  /// One Bolts chip per player with a token; empty while the chips are not shown.
  final List<CityChipScene> chips;
}

/// The road's built count, kept between none and the road's full length. The Plaza is not built
/// on, so a road is complete once every tile before it is built.
CityRoadScene _roadOf(String roadId, CitySnapshot snapshot) {
  final roadLength = snapshot.rules.roadLength;
  final built = math.min(math.max(snapshot.tilesBuilt[roadId] ?? 0, 0), roadLength);
  return CityRoadScene(roadId: roadId, roadLength: roadLength, builtTiles: built, complete: built >= roadLength - 1);
}

CityTokenScene _tokenOf(Token token, int slot, CityLayout layout) => CityTokenScene(
  playerId: token.playerId,
  slot: slot,
  centre: layout.tileCenter(token.roadId, token.tilePosition),
  absent: token.absent,
  badgeNumber: slot < cityColouredSlots ? null : slot + 1,
);

CityGateScene? _gateOf(Board board, CityLayout layout) {
  final gate = board.gate;
  if (gate == null) return null;
  return CityGateScene(centre: layout.tileCenter(gate.roadId, gate.tileIndex), open: board.gateOpen);
}

/// The chips for [players] in their order, laid out in a row under the Centre Plaza and centred on
/// it. Empty when [bolts] is null, so no chip is shown.
List<CityChipScene> _chipsOf(Bolts? bolts, List<String> players, CityLayout layout) {
  if (bolts == null) return const [];
  final spacing = layout.tileSize * cityChipSpacingTiles;
  final row = layout.plazaCenter + Offset(0, layout.tileSize * cityChipDropTiles);
  return [
    for (var slot = 0; slot < players.length; slot++)
      CityChipScene(
        playerId: players[slot],
        bolts: bolts.of(players[slot]),
        centre: row + Offset((slot - (players.length - 1) / 2) * spacing, 0),
      ),
  ];
}
