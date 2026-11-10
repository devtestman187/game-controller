import 'dart:math';
import 'dart:ui';

import 'package:protocol/protocol.dart';

import 'arena_events.dart';
import 'arena_map.dart';
import 'arena_mode.dart';
import 'arena_specs.dart';

part 'arena_player.dart';

/// The field every Arena mode plays on (party-night §7): its size, the walls,
/// hazards and goal its [map] gives it, the marbles a round moves around it,
/// and the movement they share. [ArenaGame] adds the race's rounds; the Bumper
/// Round (G9) runs on the same field and marbles.
///
/// Everything is measured against the field's size: positions are stored as
/// fractions, and speeds and sizes are fractions of the shorter side per
/// second, so the game feels the same in any window and survives resizing.
class ArenaFieldRules {
  ArenaFieldRules({this.map = ArenaMap.playroom, this.mode = ArenaMode.race, this._size = defaultSize});

  /// The size a field is given until the window says otherwise: a TV's.
  static const defaultSize = Size(960, 540);

  // Sizes and speeds, as fractions of the field's shorter side.
  static const double playerRadius = 0.032;
  static const double hazardRadius = 0.038;
  static const double wallThickness = 0.035;
  static const double speed = 0.55;
  static const double dashSpeed = speed * 2.6;
  static const double aimRange = 0.14;

  // Timing, in seconds.
  static const double dashS = 0.3;
  static const double dashCooldownS = 1.2;
  static const double hazardGraceS = 0.8;
  static const double hitGapS = 0.3;

  /// How long after one marble touches another it can be felt again, so two
  /// resting against each other don't buzz every step.
  static const double contactGapS = 0.3;

  /// How long a shove from another marble takes to fade: it pushes the marble
  /// on for a moment, then it walks on as before.
  static const double shoveS = 0.25;

  /// A wall bump below this speed (a fraction of [speed]) doesn't count, so
  /// resting a thumb against a wall doesn't buzz.
  static const double bumpThreshold = 0.25;

  /// The map this field plays (M14 k1b): its walls, hazards, and — for the
  /// race — its start and goal. With none, the Playroom's.
  final ArenaMap map;

  /// The round this field plays (G9): the race, or the Bumper Round, which
  /// starts its marbles on the map's bumper starts.
  final ArenaMode mode;

  List<WallSpec> get walls => map.walls;
  List<HazardSpec> get hazards => map.hazards;

  /// The race's start and goal. A map with no `race` section is for the
  /// Bumper Round, which brings its own starts (G9), so asking a field for
  /// these says which map and why.
  RaceSpec get race => map.race ?? (throw StateError('The map "${map.id}" has no race section.'));

  /// The Bumper Round's starts and coin zones (G9), named the same way when a
  /// map has none.
  BumperSpec get bumper => map.bumper ?? (throw StateError('The map "${map.id}" has no bumper section.'));

  // The field itself, below.

  Size _size;
  final _players = <String, ArenaPlayer>{}; // In the order they joined.
  double _time = 0; // Since the game started, for the hazards.

  /// Every round flips the field left to right.
  bool mirrored = false;

  Size get size => _size;

  double get _unit => _size.shortestSide;

  /// The sprites, in the order they joined.
  List<ArenaPlayer> get players => List.unmodifiable(_players.values);

  ArenaPlayer? player(String id) => _players[id];

  double get playerRadiusPx => playerRadius * _unit;

  double get hazardRadiusPx => hazardRadius * _unit;

  /// The first start position, in pixels.
  Offset get startPx => _px(_startFor(0));

  Rect get goalRect {
    final g = _goal;
    return Rect.fromPoints(_px(g.topLeft), _px(g.bottomRight));
  }

  List<Rect> get wallRects => [for (final w in walls) _wallRect(w)];

  List<Offset> get hazardPositions => [for (final h in hazards) _px(_mirror(h.at(_time, _size)))];

  /// The pixels of a point [fraction] of the field.
  Offset pixelOf(Offset fraction) => _px(fraction);

  /// Where slot [slot] starts: in the race, slot 0 in the middle, then above,
  /// below, further above, …, as [RaceSpec.startOf] says; in the Bumper Round,
  /// the map's own bumper start for it (G9).
  Offset _startFor(int slot) =>
      _mirror(mode == ArenaMode.bumper ? bumper.starts[slot % bumper.starts.length] : race.startOf(slot));

  Rect get _goal {
    final g = race.goal;
    return mirrored ? Rect.fromLTRB(1 - g.right, g.top, 1 - g.left, g.bottom) : g;
  }

  Offset _mirror(Offset f) => mirrored ? Offset(1 - f.dx, f.dy) : f;

  Offset _px(Offset f) => Offset(f.dx * _size.width, f.dy * _size.height);

  Offset _frac(Offset p) => Offset(p.dx / _size.width, p.dy / _size.height);

  Rect _wallRect(WallSpec w) {
    final a = _px(_mirror(w.from));
    final b = _px(_mirror(w.to));
    return Rect.fromPoints(a, b).inflate(wallThickness * _unit / 2);
  }

  /// The window changed size. The sprites keep their place on the field.
  void resize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _size = size;
  }

  /// Adds a sprite for [id] at the lowest free start position (if it isn't
  /// in the game yet).
  ArenaPlayer join(String id) {
    final existing = _players[id];
    if (existing != null) return existing;
    final used = {for (final p in _players.values) p.slot};
    var slot = 0;
    while (used.contains(slot)) {
      slot++;
    }
    final p = ArenaPlayer._(this, id, slot).._facing = Offset(mirrored ? -1 : 1, 0);
    _players[id] = p;
    return p;
  }

  void leave(String id) => _players.remove(id);

  /// Adds a marble for each controller new to [inputs] and takes away the
  /// marble of every controller that's gone.
  void syncPlayers(Map<String, GameInput> inputs) {
    for (final id in _players.keys.where((id) => !inputs.containsKey(id)).toList()) {
      leave(id);
    }
    inputs.keys.forEach(join);
  }

  /// Moves the field's clock on by [dt] seconds — the hazards ride it — and
  /// counts each marble's dash, cooldown, hazard grace and hit gap down.
  void advanceTime(double dt) {
    _time += dt;
    for (final p in _players.values) {
      p._sinceHit += dt;
      p._sinceBump += dt;
      p._graceLeft = max(0, p._graceLeft - dt);
      p._cooldownLeft = max(0, p._cooldownLeft - dt);
      p._dashLeft = max(0, p._dashLeft - dt);
      p._shove *= max(0.0, 1 - dt / shoveS);
    }
  }

  /// Moves one marble one step from its controller's [input]: the aim, a dash
  /// on the press, the walk or the dash, the walls and the hazards. Every
  /// event it causes goes into [events]. This is the movement every mode
  /// shares (G9).
  void stepMarble(ArenaPlayer pl, double dt, GameInput input, List<GameEvent> events) {
    pl._aim = input.aim;
    if (input.move.distance > 0.05) pl._facing = input.move / input.move.distance;

    // A dashes on the press. Pressed again too soon, it's an error.
    final pressed = input.dash && !pl._dashHeld;
    pl._dashHeld = input.dash;
    if (pressed) {
      if (pl._cooldownLeft > 0) {
        pl.failedDashes++;
        events.add(GameEvent(pl.id, HapticEvent.error, GameEventCause.cooldown));
      } else {
        pl.dashes++;
        pl._dashLeft = dashS;
        pl._cooldownLeft = dashCooldownS;
        events.add(
          GameEvent(pl.id, HapticEvent.rumble, GameEventCause.dash, intensity: 0.8, durationMs: (dashS * 1000).round()),
        );
      }
    }

    final walk = pl.dashing ? pl._facing * (dashSpeed * _unit) : input.move * (speed * _unit);
    // Another marble's shove rides on top of the walk until it fades (G9).
    final velocity = walk + pl._shove;
    pl._velocity = velocity;
    moveMarble(pl, velocity * dt, velocity, events);
    checkHazards(pl, events);
  }

  /// Moves a marble by [delta] pixels this step, in small steps so a fast dash
  /// can't pass through a thin wall, pushing out of walls and the field's
  /// edges after each step. [velocity] says how fast it goes, so a bump only
  /// buzzes above [bumpThreshold].
  void moveMarble(ArenaPlayer pl, Offset delta, Offset velocity, List<GameEvent> events) {
    final r = playerRadiusPx;
    final steps = max(1, (delta.distance / (r / 2)).ceil());
    var p = pl.position;
    var touched = false;
    for (var i = 0; i < steps; i++) {
      p += delta / steps.toDouble();
      final (next, hit) = resolvePoint(p, r);
      p = next;
      touched |= hit;
    }
    pl._pos = _frac(p);
    final fastEnough = velocity.distance >= bumpThreshold * speed * _unit;
    if (touched && !pl._touchingWall && fastEnough && pl._sinceHit >= hitGapS) {
      pl.hits++;
      pl._sinceHit = 0;
      events.add(GameEvent(pl.id, HapticEvent.hit, GameEventCause.wall, intensity: pl.dashing ? 1 : 0.7));
    }
    // Still pressing into a wall counts as touching, so sliding along it
    // doesn't fire again.
    pl._touchingWall = touched;
  }

  /// Pushes a circle at [p] out of every wall and back inside the field.
  /// Returns the new center and whether anything was in the way.
  (Offset, bool) resolvePoint(Offset p, double r) {
    var hit = false;
    for (final rect in wallRects) {
      final closest = Offset(p.dx.clamp(rect.left, rect.right), p.dy.clamp(rect.top, rect.bottom));
      final away = p - closest;
      final d = away.distance;
      if (d >= r) continue;
      hit = true;
      if (d > 1e-6) {
        p = closest + away / d * r;
      } else {
        // The center is inside the wall: leave by the nearest side.
        final exits = [
          (p.dx - rect.left + r, const Offset(-1, 0)),
          (rect.right - p.dx + r, const Offset(1, 0)),
          (p.dy - rect.top + r, const Offset(0, -1)),
          (rect.bottom - p.dy + r, const Offset(0, 1)),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        p += exits.first.$2 * exits.first.$1;
      }
    }
    final x = p.dx.clamp(r, _size.width - r);
    final y = p.dy.clamp(r, _size.height - r);
    if (x != p.dx || y != p.dy) hit = true;
    return (Offset(x, y), hit);
  }

  /// Knocks a marble back out of any hazard it touches, and gives it a short
  /// grace so one hazard doesn't hit it every step.
  void checkHazards(ArenaPlayer pl, List<GameEvent> events) {
    if (pl.recovering) return;
    final p = pl.position;
    final reach = playerRadiusPx + hazardRadiusPx;
    for (final h in hazardPositions) {
      final away = p - h;
      if (away.distance >= reach) continue;
      pl.hits++;
      pl._sinceHit = 0;
      pl._graceLeft = hazardGraceS;
      pl._dashLeft = 0;
      // Knocked back out of the hazard, then out of any wall.
      final dir = away.distance > 1e-6 ? away / away.distance : -pl._facing;
      final (pushed, _) = resolvePoint(h + dir * (reach + playerRadiusPx), playerRadiusPx);
      pl._pos = _frac(pushed);
      events.add(GameEvent(pl.id, HapticEvent.hit, GameEventCause.hazard));
      return;
    }
  }

  /// Whether [pl] has reached the goal, its own radius counted in.
  bool reachedGoal(ArenaPlayer pl) => _goal.inflate(playerRadius * 0.5 * _unit / _size.width).contains(pl._pos);

  /// Ends every marble's dash at once, as a round ends.
  void stopDashes() {
    for (final p in _players.values) {
      p._dashLeft = 0;
    }
  }

  /// Puts every marble back at its start position, facing the way the new
  /// round goes.
  void resetMarbles() {
    for (final p in _players.values) {
      p._reset();
    }
  }

  /// While a won round waits for the next, keeps each marble's A-press state
  /// current, so a press held over the break doesn't dash as the next starts.
  void noteDashHeld(Map<String, GameInput> inputs) {
    for (final p in _players.values) {
      p._dashHeld = inputs[p.id]!.dash;
    }
  }
}
