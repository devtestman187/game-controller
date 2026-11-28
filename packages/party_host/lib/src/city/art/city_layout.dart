/// Where the City Rush board sits on a screen: pure geometry, no drawing (M17 map2a).
///
/// Every district is a straight road that runs from the Centre Plaza out to the edge, like the
/// spokes of a wheel. A corner road takes every second spoke and the lane beside it the spoke
/// after it, so the four corners sit on the diagonals and their lanes on the four axes.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../board.dart';
import '../rules.dart';

/// How far the outermost tile centres sit from the screen edge, as a share of the screen's
/// shorter side: room for the tile's half width, its shadow and its district padding.
const cityInsetShare = 0.08;

/// How much of the tightest gap between two tile centres a tile fills, so two tiles never touch
/// and the road's lane shows between them.
const cityTileFitShare = 0.9;

/// How far a district's rect reaches beyond its tiles, as a share of the tile size.
const cityDistrictPadShare = 0.25;

/// The geometry of one board on one screen size. Build it with [CityLayout.compute]; it is
/// immutable, so a painter can keep it and compare it by identity.
final class CityLayout {
  CityLayout._(
    this._centres,
    this._districtRects, {
    required this.size,
    required this.tileSize,
    required this.plazaCenter,
  });

  /// Lays [board] out inside [size]. A district takes its spoke from its place in
  /// [CityRules.corners]: corner `i` the spoke `2i`, the lane beside it spoke `2i + 1`.
  ///
  /// Throws [ArgumentError] when a district is neither a corner nor a lane of [rules], or when
  /// a road isn't [CityRules.roadLength] tiles long.
  factory CityLayout.compute({required Size size, required Board board, required CityRules rules}) {
    final inset = math.min(size.width, size.height) * cityInsetShare;
    final centre = size.center(Offset.zero);
    final reach = Offset(size.width / 2 - inset, size.height / 2 - inset);
    if (rules.roadLength < 2) {
      throw ArgumentError.value(rules.roadLength, 'rules', 'a road needs a tile and the Plaza');
    }
    final steps = rules.roadLength - 1;
    final spokeStepRad = math.pi / rules.corners.length;
    final firstSpokeRad = -math.pi / 2 - spokeStepRad;
    final centres = <String, List<Offset>>{};
    for (final district in board.districts) {
      if (district.road.length != rules.roadLength) {
        throw ArgumentError.value(district.id, 'board', 'a road must be ${rules.roadLength} tiles long');
      }
      final angleRad = firstSpokeRad + _spokeOf(district, rules) * spokeStepRad;
      final spoke = Offset(math.cos(angleRad) * reach.dx, math.sin(angleRad) * reach.dy);
      centres[district.id] = [for (var i = 0; i <= steps; i++) centre + spoke * ((steps - i) / steps)];
    }
    final tileSize = _tileSizeFor(centres.values.toList(), inset);
    return CityLayout._(
      centres,
      {for (final entry in centres.entries) entry.key: _boundsOf(entry.value, steps, tileSize)},
      size: size,
      tileSize: tileSize,
      plazaCenter: centre,
    );
  }

  /// The screen size this layout was made for.
  final Size size;

  /// The side of one square tile.
  final double tileSize;

  /// The middle of the Centre Plaza: the last tile of every road.
  final Offset plazaCenter;

  final Map<String, List<Offset>> _centres;

  final Map<String, Rect> _districtRects;

  /// The middle of tile [index] on road [roadId], 0 being the outer start and the last index
  /// ([CityRules.roadLength] - 1) the Centre Plaza, which every road shares.
  ///
  /// Throws [ArgumentError] for an unknown road and [RangeError] for an index off the road.
  Offset tileCenter(String roadId, int index) {
    final road = _centres[roadId];
    if (road == null) throw ArgumentError.value(roadId, 'roadId', 'no such road on this board');
    RangeError.checkValidIndex(index, road);
    return road[index];
  }

  /// The square [tileSize] wide around [tileCenter].
  Rect tileRect(String roadId, int index) =>
      Rect.fromCenter(center: tileCenter(roadId, index), width: tileSize, height: tileSize);

  /// The box around a district's road tiles, padded by [cityDistrictPadShare] of a tile.
  /// Throws [ArgumentError] for an unknown district.
  Rect districtRect(String districtId) {
    final rect = _districtRects[districtId];
    if (rect == null) throw ArgumentError.value(districtId, 'districtId', 'no such district on this board');
    return rect;
  }
}

int _spokeOf(District district, CityRules rules) {
  final laneOf = district.laneOf;
  final corner = rules.corners.indexOf(laneOf ?? district.id);
  if (corner < 0) {
    throw ArgumentError.value(district.id, 'board', 'a district must be a corner or a lane beside one');
  }
  return laneOf == null ? corner * 2 : corner * 2 + 1;
}

/// The biggest tile that fits: no two road tiles closer than a tile's diagonal allows, and a
/// tile plus its district padding inside the [inset] left at the screen's edge.
double _tileSizeFor(List<List<Offset>> roads, double inset) {
  final points = <Offset>[for (final road in roads) ...road.take(road.length - 1)];
  var tightest = double.infinity;
  for (var a = 0; a < points.length; a++) {
    for (var b = a + 1; b < points.length; b++) {
      tightest = math.min(tightest, (points[a] - points[b]).distance);
    }
    if (roads.isNotEmpty) tightest = math.min(tightest, (points[a] - roads.first.last).distance);
  }
  final fitsApart = tightest * cityTileFitShare / math.sqrt2;
  final fitsInset = inset / (1 / 2 + cityDistrictPadShare);
  return math.min(fitsApart, fitsInset);
}

Rect _boundsOf(List<Offset> road, int steps, double tileSize) {
  final points = steps == 0 ? road : road.take(steps).toList();
  var bounds = Rect.fromPoints(points.first, points.first);
  for (final point in points) {
    bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
  }
  return bounds.inflate(tileSize * (1 / 2 + cityDistrictPadShare));
}
