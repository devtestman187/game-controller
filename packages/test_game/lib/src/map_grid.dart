import 'dart:typed_data';
import 'dart:ui';

import 'arena_field.dart';
import 'arena_map.dart';
import 'arena_specs.dart';

/// A cell's side as a share of a marble's diameter (M14 k1b): a fifth, fine
/// enough to see the 2.5-marble gaps the map rules ask for and cheap enough
/// to fill: a 16:9 field is 139 × 79 cells, about 11 000.
const gridCellShare = 0.2;

/// The map's field in cells, for reachability (M14 k1b): a cell is free only
/// where a marble's centre fits, since the walls are grown by [grow] (a
/// marble's radius by default) and so are the field's edges. [hasPath] and
/// [reachesZone] flood fill from a point, [path] returns the shortest way
/// between two, and [unreachableFrom] finds a pocket nothing reaches.
///
/// The map rules use it, and Robo will steer with it (M14 b3). Points are
/// fractions of the field, as a map file writes them.
final class MapGrid {
  factory MapGrid({
    required ArenaMap map,
    double grow = ArenaFieldRules.playerRadius,
    Size field = mapFieldSize,
    double cellShare = gridCellShare,
  }) {
    final cell = cellShare * 2 * ArenaFieldRules.playerRadius * field.shortestSide;
    final columns = (field.width / cell).ceil();
    final rows = (field.height / cell).ceil();
    final margin = grow * field.shortestSide;
    final walls = [for (final wall in map.walls) wall.rectIn(field, ArenaFieldRules.wallThickness).inflate(margin)];
    final free = Uint8List(columns * rows);
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < columns; i++) {
        final centre = Offset((i + 0.5) * cell, (j + 0.5) * cell);
        final inside =
            centre.dx >= margin &&
            centre.dx <= field.width - margin &&
            centre.dy >= margin &&
            centre.dy <= field.height - margin;
        free[j * columns + i] = inside && !walls.any((rect) => rect.contains(centre)) ? 1 : 0;
      }
    }
    return MapGrid._(
      map: map,
      grow: grow,
      field: field,
      cell: cell,
      wallRects: walls,
      columns: columns,
      rows: rows,
      free: free,
    );
  }

  MapGrid._({
    required this.map,
    required this.grow,
    required this.field,
    required this.cell,
    required this.columns,
    required this.rows,
    required this._free,
    required this._wallRects,
  });

  /// The map this grid was made from.
  final ArenaMap map;

  /// How far the walls are grown, a fraction of the field's shorter side: a
  /// marble's radius means a free cell is where its centre fits.
  final double grow;

  /// The field's size in units; [mapFieldSize] for a map file.
  final Size field;

  /// A cell's side, in units.
  final double cell;

  final int columns;
  final int rows;

  final Uint8List _free;
  final List<Rect> _wallRects;

  /// Whether a marble's centre may stand at [point] (a fraction of the field):
  /// inside the field by [grow] and clear of every wall by as much.
  bool isFree(Offset point) {
    final p = mapUnits(point, field);
    final margin = grow * field.shortestSide;
    if (p.dx < margin || p.dx > field.width - margin || p.dy < margin || p.dy > field.height - margin) {
      return false;
    }
    return !_wallRects.any((rect) => rect.contains(p));
  }

  /// The shortest path from [from] to [to], both fractions of the field, as
  /// the centres of the cells it crosses, in fractions; null when no way is
  /// free. The way is the first one a flood fill finds, so it is as short as
  /// the cells allow.
  List<Offset>? path(Offset from, Offset to) {
    final start = _cellOf(from);
    final target = _cellOf(to);
    if (start == null || target == null || _free[start] == 0 || _free[target] == 0) return null;
    final parent = _flood([start]);
    if (parent[target] == -1) return null;
    final way = <Offset>[];
    for (var cell = target; cell != start; cell = parent[cell]) {
      way.add(_centreOf(cell));
    }
    way.add(_centreOf(start));
    return way.reversed.toList();
  }

  /// Whether a marble can get from [from] to [to], both fractions of the
  /// field.
  bool hasPath(Offset from, Offset to) => path(from, to) != null;

  /// Whether a marble can get from [from] into [zone], both fractions of the
  /// field: any free cell whose centre lies in the zone counts.
  bool reachesZone(Offset from, Rect zone) {
    final start = _cellOf(from);
    if (start == null || _free[start] == 0) return false;
    final parent = _flood([start]);
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < columns; i++) {
        if (parent[j * columns + i] == -1) continue;
        if (_inZone(_centreOf(j * columns + i), zone)) return true;
      }
    }
    return false;
  }

  /// Up to [most] free places inside [zone] (a rect of the field's fractions),
  /// each at least [apart] from the others (a fraction of the field's shorter
  /// side): the places a round may put something of that size, as the Bumper
  /// Round's coins will (G9).
  List<Offset> spotsIn(Rect zone, {required double apart, required int most}) {
    final least = apart * field.shortestSide;
    final spots = <Offset>[];
    for (var cell = 0; cell < _free.length && spots.length < most; cell++) {
      if (_free[cell] == 0) continue;
      final centre = _centreOf(cell);
      if (!_inZone(centre, zone)) continue;
      if (spots.any((spot) => _distanceBetween(spot, centre) < least)) continue;
      spots.add(centre);
    }
    return spots;
  }

  /// How far apart two points of the field are, in units.
  double _distanceBetween(Offset a, Offset b) => (mapUnits(a, field) - mapUnits(b, field)).distance;

  /// A free cell no marble can reach from any of [starts] (fractions of the
  /// field), as a fraction, or null when every free cell can be reached: a
  /// pocket a marble could stand in but never get out of.
  Offset? unreachableFrom(List<Offset> starts) {
    final seeds = [for (final start in starts) ?_cellOf(start)];
    if (seeds.isEmpty) {
      for (var cell = 0; cell < _free.length; cell++) {
        if (_free[cell] == 1) return _centreOf(cell);
      }
      return null;
    }
    final parent = _flood(seeds.where((cell) => _free[cell] == 1).toList());
    for (var cell = 0; cell < _free.length; cell++) {
      if (_free[cell] == 1 && parent[cell] == -1) return _centreOf(cell);
    }
    return null;
  }

  /// Which cell [point] (a fraction of the field) lies in, or null outside the
  /// field.
  int? _cellOf(Offset point) {
    final i = (point.dx * field.width / cell).floor();
    final j = (point.dy * field.height / cell).floor();
    if (i < 0 || i >= columns || j < 0 || j >= rows) return null;
    return j * columns + i;
  }

  Offset _centreOf(int index) =>
      Offset(((index % columns + 0.5) * cell / field.width), ((index ~/ columns + 0.5) * cell / field.height));

  bool _inZone(Offset point, Rect zone) =>
      point.dx >= zone.left && point.dx <= zone.right && point.dy >= zone.top && point.dy <= zone.bottom;

  /// Every cell reachable from [seeds] (cell indices), as each cell's parent
  /// in the flood fill, or -1 for a cell it never reached. The seeds are their
  /// own parents.
  Int32List _flood(List<int> seeds) {
    final parent = Int32List(columns * rows)..fillRange(0, columns * rows, -1);
    final queue = Int32List(columns * rows);
    var tail = 0;
    for (final seed in seeds) {
      parent[seed] = seed;
      queue[tail++] = seed;
    }
    for (var head = 0; head < tail; head++) {
      final cell = queue[head];
      final i = cell % columns;
      final j = cell ~/ columns;
      for (final (di, dj) in _steps) {
        final ni = i + di;
        final nj = j + dj;
        if (ni < 0 || ni >= columns || nj < 0 || nj >= rows) continue;
        final next = nj * columns + ni;
        if (_free[next] == 0 || parent[next] != -1) continue;
        parent[next] = cell;
        queue[tail++] = next;
      }
    }
    return parent;
  }
}

/// The four ways a marble moves cell to cell: across and down only, so a path
/// never cuts a corner a marble's round body could not.
const _steps = [(-1, 0), (1, 0), (0, -1), (0, 1)];
