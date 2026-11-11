part of 'cpu_pilot.dart';

/// The way Robo steers: reading its plan off the grid, keeping clear of the
/// hazards, working a corner, and the few ways out of one.
extension CpuSteering on CpuPilot {
  /// The way's next point: the farthest one within a few cells that the
  /// marble can see from where it stands, so it cuts a corner as far as the
  /// walls allow. Null when the way's end is reached.
  Offset? _waypoint(Offset hereUnits) {
    if (_way.isEmpty) return null;
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < _way.length; i++) {
      final d = (mapUnits(_way[i]) - hereUnits).distance;
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    if (nearest == _way.length - 1 && best < grid.cell) return null;
    final reach = grid.cell * cpuAimCells;
    var aim = -1;
    var blind = -1;
    for (var i = nearest; i < _way.length; i++) {
      final at = mapUnits(_way[i]);
      final d = (at - hereUnits).distance;
      if (d > reach) break;
      if (d >= grid.cell && blind < 0) blind = i;
      if (_clearLine(hereUnits, at)) aim = i;
    }
    if (aim >= 0) return mapUnits(_way[aim]);
    if (blind >= 0) return mapUnits(_way[blind]);
    return null;
  }

  /// Whether the straight way from [fromUnits] to [toUnits], both in map
  /// units, stays clear of walls and the field's edge all the way.
  bool _clearLine(Offset fromUnits, Offset toUnits) {
    final span = toUnits - fromUnits;
    final steps = max(1, (span.distance / (grid.cell * 0.25)).ceil());
    for (var i = 1; i <= steps; i++) {
      if (!grid.isFree(CpuPilot._fractionOfUnits(fromUnits + span * (i / steps)))) return false;
    }
    return true;
  }

  /// [steer] with a hazard's berth pushing it away: harder the closer the
  /// hazard, so a marble passing beside one keeps its distance.
  Offset _clearOfHazards(Offset steer, Offset hereUnits) {
    final berth = _tuning.hazardMargin * mapFieldSize.shortestSide;
    var pushed = steer;
    for (final hazard in _hazards) {
      final away = hereUnits - mapUnits(hazard);
      if (away.distance >= berth) continue;
      final safe = away.distance < 1e-6 ? const Offset(1, 0) : away / away.distance;
      pushed += safe * (cpuHazardPush * (1 - away.distance / berth));
    }
    return pushed.distance < 1e-6 ? steer : pushed / pushed.distance;
  }

  /// The centre of the nearest free cell to [hereUnits], in map units, looking
  /// a few cells round it; null when a few cells round hold none. A marble
  /// resting against a wall stands in a cell the grid calls taken, and this is
  /// the step back onto free ground that lets it plan again.
  Offset? _freeSpot(Offset hereUnits) {
    final i0 = (hereUnits.dx / grid.cell).floor();
    final j0 = (hereUnits.dy / grid.cell).floor();
    Offset? best;
    var bestD = double.infinity;
    for (var r = 1; r <= cpuFreeCells; r++) {
      for (var i = i0 - r; i <= i0 + r; i++) {
        for (var j = j0 - r; j <= j0 + r; j++) {
          if (max((i - i0).abs(), (j - j0).abs()) != r) continue;
          final at = Offset((i + 0.5) * grid.cell, (j + 0.5) * grid.cell);
          if (!grid.isFree(CpuPilot._fractionOfUnits(at))) continue;
          final d = (at - hereUnits).distance;
          if (d >= bestD) continue;
          best = at;
          bestD = d;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  /// Whether [hereUnits] plus [cells] cells along [steer] is free of walls and
  /// the field's edge.
  bool _freeAhead(Offset steer, Offset hereUnits, double cells) =>
      grid.isFree(CpuPilot._fractionOfUnits(hereUnits + steer * (grid.cell * cells)));

  /// Whether a step from [hereUnits] along [steer] is free.
  bool _freeStep(Offset steer, Offset hereUnits) => _freeAhead(steer, hereUnits, cpuStepCells);

  /// A way out of a corner: the first compass way whose probe is free, from
  /// the seeded random's turn of the list so a round never loops the same way.
  /// The probe shortens when a wall's berth is deep, so a marble pressed into
  /// one always finds the step's worth of free ground that starts it moving.
  Offset _turnOut(Offset hereUnits) {
    final ways = [..._escapeWays]..shuffle(random);
    for (final cells in const [cpuEscapeCells, 0.5, 0.25]) {
      for (final way in ways) {
        final dir = way / way.distance;
        if (!_freeAhead(dir, hereUnits, cells)) continue;
        _escape = dir;
        _escapeLeftS = cpuEscapeHoldS;
        return dir;
      }
    }
    _escape = Offset.zero;
    _escapeLeftS = 0;
    return Offset.zero;
  }
}
