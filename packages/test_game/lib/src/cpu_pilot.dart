import 'dart:math';
import 'dart:ui';

import 'arena.dart';
import 'arena_events.dart';
import 'arena_field.dart';
import 'arena_map.dart';
import 'arena_robo.dart';
import 'arena_specs.dart';
import 'cpu_tuning.dart';
import 'map_grid.dart';

part 'cpu_pilot_steering.dart';

/// The eight ways an escape may try, in map units, round the compass.
const _escapeWays = [
  Offset(1, 0),
  Offset(1, 1),
  Offset(0, 1),
  Offset(-1, 1),
  Offset(-1, 0),
  Offset(-1, -1),
  Offset(0, -1),
  Offset(1, -1),
];

/// The seed a round's pilot starts from, so the same round plays the same way
/// every time (party-night §7a: seeded, so the tests repeat).
const roboSeed = 7;

/// The grid Robo plans on: the map's walls and the ground its sliding movers
/// sweep, so it never plans a way through a gate that is shut most of the
/// round. A swing or a spin is left out: it is gone from a spot as quickly as
/// it comes.
MapGrid cpuGrid(ArenaMap map) => MapGrid(map: map, blockMovers: true);

/// Robo's hands (party-night §7a, M14 b3): one [GameInput] a step, played on
/// the host from the game's own state, so no phone and no network knows Robo
/// is a CPU.
///
/// It rolls along a [MapGrid] path to the nearest coin it can reach on the
/// map, gives hazards the level's berth, and follows the plan for the level's
/// reaction time before looking again. Medium and Hard also dash at a player
/// close by with coins, at the pace their table row gives (party-night §7a).
/// Its wobble and its escape from a corner come from the seeded [random] the
/// round was built with, so a round plays the same way every time.
final class CpuPilot {
  CpuPilot({required this.level, required this.grid, required this.random}) : _tuning = CpuTuning.of(level);

  /// The level's numbers (design 7a).
  final RoboLevel level;

  /// The map's grid, which the way is planned on.
  final MapGrid grid;

  /// The round's seeded random, for the wobble and the way out of a corner
  /// (design 7a: a round can be replayed in a test).
  final Random random;

  final CpuTuning _tuning;

  /// The way to the coin, as the map writes points, from the last look.
  List<Offset> _way = const [];

  /// The coin the way leads to, kept while the way stays short.
  Offset? _target;

  /// The hazards as they were at the last look: the reaction time makes its
  /// dodging as late as its looking.
  List<Offset> _hazards = const [];

  Offset _before = Offset.zero;
  double _sinceLookS = double.infinity;
  double _stillS = 0;
  double _veers = 0;
  double _escapeLeftS = 0;
  Offset _escape = Offset.zero;
  double _closest = double.infinity;
  double _sinceProgressS = 0;
  int _coins = 0;

  /// Seconds since the last shove it started, or infinity before one: the
  /// level's wait between shoves (party-night §7a's table).
  double _sinceShoveS = double.infinity;

  /// The coin a dash is aimed at, in map units, while the straight way to it is
  /// clear and it is far enough to be worth one: party-night §7a's "dashes
  /// toward a far coin". Null when the coin it is after is close, or the way to
  /// it turns.
  Offset? _dashTo;

  /// The coins it pressed at without getting there this round: a gate that was
  /// shut or a mover in the way, which the grid cannot see. They are tried
  /// again when no other coin is left.
  final Set<Offset> _unreachable = {};

  /// One step's input for Robo, from the game as it stands and the step's
  /// [dt] in seconds. It moves nothing when Robo is not on the field (the
  /// seat is added and taken away by the session).
  GameInput step(ArenaGame game, double dt) {
    final robo = game.player(roboPlayerId);
    if (robo == null) return GameInput.none;
    final here = _fractionOf(robo.position, game.size);
    final hereUnits = mapUnits(here);
    _noteStuck(hereUnits, dt);
    _noteProgress(game, hereUnits, dt);
    _sinceLookS += dt;
    if (_sinceLookS >= _tuning.reactionS) _look(game, here);
    final shove = _shoveAt(game, robo, hereUnits, dt);
    if (shove != null) {
      _before = hereUnits;
      return GameInput(move: shove, dash: true);
    }
    final dash = _dashAt(game, robo, hereUnits);
    if (dash != null) {
      _before = hereUnits;
      return GameInput(move: dash, dash: true);
    }
    final heading = _heading(hereUnits, dt);
    if (heading == Offset.zero) return GameInput.none;
    final move = _moveOf(heading, game.size);
    _before = hereUnits;
    return GameInput(move: move);
  }

  /// Looks again: the hazards as they are now, and the closest coin it can
  /// reach. The plan then stands until the level's reaction time is up. It
  /// keeps the coin it was after while that is no more than a little longer,
  /// so two coins either side of a wall do not pull it back and forth. When
  /// the grid has no way to any coin it walks at the nearest one, which is how
  /// it gets out of a corner the cells lose sight of the field from.
  void _look(ArenaGame game, Offset here) {
    _sinceLookS = 0;
    _hazards = [for (final hazard in game.hazardPositions) _fractionOf(hazard, game.size)];
    _veers = (random.nextDouble() * 2 - 1) * _tuning.wobbleRad;
    final coins = [for (final coin in game.coins) coin.position];
    var left = [
      for (final coin in coins)
        if (!_unreachable.contains(coin)) coin,
    ];
    if (left.isEmpty) {
      _unreachable.clear();
      left = coins;
    }
    List<Offset>? bestWay;
    Offset? bestCoin;
    var bestLength = double.infinity;
    for (final coin in left) {
      final way = grid.path(here, coin);
      if (way == null) continue;
      final length = _lengthOf(way);
      if (length >= bestLength) continue;
      bestWay = way;
      bestCoin = coin;
      bestLength = length;
    }
    final target = _target;
    if (target != null && target != bestCoin && coins.contains(target) && !_unreachable.contains(target)) {
      final keep = grid.path(here, target);
      if (keep != null && _lengthOf(keep) <= bestLength * cpuKeepShare) {
        bestWay = keep;
        bestCoin = target;
      }
    }
    if (bestCoin == null) {
      var near = double.infinity;
      for (final coin in coins) {
        final d = (mapUnits(coin) - mapUnits(here)).distance;
        if (d >= near) continue;
        near = d;
        bestCoin = coin;
      }
    }
    _target = bestCoin;
    _way = bestWay ?? const [];
    // A coin it can run at in a straight line, far enough for a dash to be
    // worth it: the level's top speed is a walk, and a dash crosses the field
    // in a third of a second (party-night §7a).
    final at = bestCoin == null ? null : mapUnits(bestCoin);
    _dashTo = at != null && (at - mapUnits(here)).distance >= grid.cell * cpuDashCells && _clearLine(mapUnits(here), at)
        ? at
        : null;
  }

  /// The dash this step presses to shove a player, or null (party-night §7a's
  /// "Shoves" row): only a level that seeks shoves does; only at a player
  /// close by with coins to drop; only once its wait since the last shove is
  /// over; and, on Hard, only when the push sends that player at a wall or a
  /// hazard. A dash starts on the press, so one step of [GameInput.dash] is
  /// one shove, and the rule refuses it while a dash is cooling down or Robo
  /// is dizzy after a drop.
  Offset? _shoveAt(ArenaGame game, ArenaPlayer robo, Offset hereUnits, double dt) {
    _sinceShoveS += dt;
    final every = _tuning.shoveEveryS;
    if (every == null || _sinceShoveS < every) return null;
    if (robo.dashing || robo.dizzy || robo.cooldown > 0) return null;
    final near = _closeWithCoins(game, hereUnits);
    if (near == null) return null;
    final at = mapUnits(_fractionOf(near.position, game.size));
    final push = (at - hereUnits) / (at - hereUnits).distance;
    if (_tuning.shoveAimed && !_shoveLandsOn(at, push)) return null;
    _sinceShoveS = 0;
    return _moveOf(push, game.size);
  }

  /// The closest player holding coins within the level's shove reach of
  /// [hereUnits] in map units, or null: the one a shove is for, and the one a
  /// dash at a coin must leave alone (party-night §7a: a level "bumps but never
  /// bullies", so its dashes never run a player over on the way to a coin).
  ArenaPlayer? _closeWithCoins(ArenaGame game, Offset hereUnits) {
    final reach = _tuning.shoveRange * mapFieldSize.shortestSide;
    ArenaPlayer? near;
    var nearD = double.infinity;
    for (final player in game.players) {
      if (player.id == roboPlayerId || player.coins == 0) continue;
      final d = (mapUnits(_fractionOf(player.position, game.size)) - hereUnits).distance;
      if (d >= nearD || d > reach || d < 1e-6) continue;
      near = player;
      nearD = d;
    }
    return near;
  }

  /// The dash this step presses toward a far coin it can see the way to, or
  /// null (party-night §7a: "dashes toward a far coin"). It is a plain dash,
  /// so a level's wobble never sends it off the coin's way, and a dash already
  /// running or cooling down, or a marble dizzy after a drop, takes none.
  Offset? _dashAt(ArenaGame game, ArenaPlayer robo, Offset hereUnits) {
    final coin = _dashTo;
    if (coin == null || robo.dashing || robo.dizzy || robo.cooldown > 0) return null;
    if (_closeWithCoins(game, hereUnits) != null) return null;
    final way = coin - hereUnits;
    if (way.distance < 1e-6 || !_clearLine(hereUnits, coin)) return null;
    return _moveOf(way / way.distance, game.size);
  }

  /// Whether a shove along [push], from the player's spot [at] in map units,
  /// runs them into a wall or the field's edge, or through a hazard's berth,
  /// within the few cells a dash covers: what Hard aims a shove at.
  bool _shoveLandsOn(Offset at, Offset push) {
    final runway = grid.cell * cpuShoveCells;
    final berth = _tuning.hazardMargin * mapFieldSize.shortestSide;
    final steps = max(1, (runway / (grid.cell * 0.25)).ceil());
    for (var i = 1; i <= steps; i++) {
      final spot = at + push * (runway * i / steps);
      if (!grid.isFree(_fractionOfUnits(spot))) return true;
      for (final hazard in _hazards) {
        if ((mapUnits(hazard) - spot).distance < berth) return true;
      }
    }
    return false;
  }

  /// How far [way] runs, in map units.
  static double _lengthOf(List<Offset> way) {
    var length = 0.0;
    for (var i = 1; i < way.length; i++) {
      length += (mapUnits(way[i]) - mapUnits(way[i - 1])).distance;
    }
    return length;
  }

  /// The direction to steer this step, in map units: along the way, veered by
  /// the level's wobble, pushed away from a hazard in the way, and turned out
  /// of a corner when the marble is held up. Its length is the share of the
  /// level's top speed to ask for, so a step that would overshoot the point it
  /// is steering at is taken shorter. [Offset.zero] when there is nowhere to
  /// go.
  Offset _heading(Offset hereUnits, double dt) {
    if (_escapeLeftS > 0) {
      if (_freeStep(_escape, hereUnits)) return _escape;
      _escapeLeftS = 0;
    }
    if (!grid.isFree(_fractionOfUnits(hereUnits))) {
      final free = _freeSpot(hereUnits);
      if (free != null) return (free - hereUnits) / (free - hereUnits).distance;
    }
    final target = _target;
    final ahead = _waypoint(hereUnits) ?? (target == null ? null : mapUnits(target));
    if (ahead == null) return Offset.zero;
    final plain = ahead - hereUnits;
    if (plain.distance < 1e-6) return _turnOut(hereUnits);
    final dir = plain / plain.distance;
    var steer = _clearOfHazards(_turned(dir, _veers), hereUnits);
    if (!_freeStep(steer, hereUnits)) steer = dir;
    if (!_freeStep(steer, hereUnits)) return _turnOut(hereUnits);
    final step = ArenaFieldRules.speed * mapFieldSize.shortestSide * dt;
    return steer * min(1.0, plain.distance / step);
  }

  /// How long the marble has been falling short of the step it asked for: held
  /// up for a moment and it looks again; held up longer and it turns out.
  void _noteStuck(Offset hereUnits, double dt) {
    if (_escapeLeftS > 0) _escapeLeftS = max(0, _escapeLeftS - dt);
    final expected = _tuning.speedShare * ArenaFieldRules.speed * mapFieldSize.shortestSide * dt;
    if ((hereUnits - _before).distance < expected * cpuStillShare) {
      _stillS += dt;
    } else {
      _stillS = 0;
    }
    if (_stillS >= cpuRetargetS) _sinceLookS = _tuning.reactionS;
    if (_stillS >= cpuEscapeS && _escapeLeftS <= 0) _turnOut(hereUnits);
  }

  /// Notes whether the marble is getting anywhere: a coin taken, or a nearer
  /// coin than it has been, is progress; a second without either means it is
  /// circling something it cannot see, so it turns out and plans again.
  void _noteProgress(ArenaGame game, Offset hereUnits, double dt) {
    final robo = game.player(roboPlayerId)!;
    if (robo.coins != _coins) {
      _coins = robo.coins;
      _closest = double.infinity;
      _sinceProgressS = 0;
    }
    var nearest = double.infinity;
    for (final coin in game.coins) {
      nearest = min(nearest, (mapUnits(coin.position) - hereUnits).distance);
    }
    if (nearest < _closest - grid.cell * 0.5) {
      _closest = nearest;
      _sinceProgressS = 0;
      return;
    }
    _sinceProgressS += dt;
    if (_sinceProgressS < cpuProgressS) return;
    _sinceProgressS = 0;
    _closest = nearest;
    _sinceLookS = _tuning.reactionS;
    final target = _target;
    if (target != null) _unreachable.add(target);
    _turnOut(hereUnits);
  }

  /// [direction] (map units, its length the share of the top speed) as the
  /// game reads an input's move: a unit vector on the screen, scaled by the
  /// level's top speed.
  Offset _moveOf(Offset direction, Size size) {
    final onScreen = Offset(
      direction.dx / mapFieldSize.width * size.width,
      direction.dy / mapFieldSize.height * size.height,
    );
    if (onScreen.distance < 1e-6) return Offset.zero;
    final share = _tuning.speedShare * min(1.0, direction.distance);
    return onScreen / onScreen.distance * share;
  }

  /// [direction] turned by [radians], in map units.
  static Offset _turned(Offset direction, double radians) {
    if (radians == 0) return direction;
    final c = cos(radians);
    final s = sin(radians);
    return Offset(direction.dx * c - direction.dy * s, direction.dx * s + direction.dy * c);
  }

  static Offset _fractionOf(Offset point, Size size) => Offset(point.dx / size.width, point.dy / size.height);

  static Offset _fractionOfUnits(Offset point) => Offset(point.dx / mapFieldSize.width, point.dy / mapFieldSize.height);
}
