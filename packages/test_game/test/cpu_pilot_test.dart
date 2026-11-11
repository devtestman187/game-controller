import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

/// One simulation step: the rounds run at the host's fixed step.
const stepS = 1 / 60;

/// The human's id in a Robo test: a still marble, so only Robo moves.
const humanId = 'p1';

/// The seeds every map and level plays in these tests, so a failure repeats.
const seeds = [1, 2, 3];

/// How long a round runs, in steps: the Bumper Round's 60 s clock.
const roundSteps = 60 * 60;

/// How long Robo may take to reach its first coin on a map, per level, in
/// seconds: the slowest travel measured over the five maps and the three seeds
/// (Easy 3.30 s on Block Castle, Medium 2.85 s, Hard 2.52 s) plus the two
/// seconds the coin rules can cost it (M14 f1, r5 finding 2): a coin it stands
/// on is not takable until it is a second old, and a hazard leaves it dizzy
/// for a second, in which it can't dash. The design's levels are aims, not
/// promises, so each level gets its own deadline.
const firstCoinS = {RoboLevel.easy: 5.0, RoboLevel.medium: 4.5, RoboLevel.hard: 5.5};

/// A Bumper Round and the pilot that plays one seat of it.
typedef PilotRound = ({ArenaGame game, CpuPilot pilot});

/// A Bumper Round on [map] with Robo at [level] and a still player, seeded so
/// it repeats.
PilotRound roundOf(ArenaMap map, RoboLevel level, {int seed = 1}) {
  final game = ArenaGame(map: map, mode: ArenaMode.bumper, random: Random(seed));
  final pilot = CpuPilot(level: level, grid: cpuGrid(map), random: Random(seed));
  return (game: game, pilot: pilot);
}

/// One step of [round]: the lone player still, Robo by its pilot. The pilot
/// sees the game before the step, as the session steps it.
void advance(PilotRound round) =>
    round.game.update(stepS, {humanId: GameInput.none, roboPlayerId: round.pilot.step(round.game, stepS)});

/// Where Robo stands, as a fraction of the field.
Offset roboAt(ArenaGame game) {
  final position = game.player(roboPlayerId)!.position;
  return Offset(position.dx / game.size.width, position.dy / game.size.height);
}

/// How many seconds [round] takes to win Robo its first coin; infinite when
/// the clock runs out first.
double firstCoin(PilotRound round) {
  for (var i = 1; i <= roundSteps && round.game.phase == ArenaPhase.playing; i++) {
    advance(round);
    if ((round.game.player(roboPlayerId)?.coins ?? 0) > 0) return i * stepS;
  }
  return double.infinity;
}

/// The coins [round] leaves Robo after its clock runs out.
int coinsOf(PilotRound round) {
  for (var i = 0; i < roundSteps && round.game.phase == ArenaPhase.playing; i++) {
    advance(round);
  }
  return round.game.player(roboPlayerId)?.coins ?? 0;
}

/// The longest time [round] leaves Robo within a marble's diameter of where it
/// stood a step before, in seconds: pressed against a wall, or circling.
double longestHeld(PilotRound round) {
  final reach = ArenaFieldRules.playerRadius * mapFieldSize.shortestSide;
  // Robo's marble comes out on the round's first step, with its first input.
  advance(round);
  var anchor = mapUnits(roboAt(round.game));
  var since = 0.0;
  var most = 0.0;
  for (var i = 1; i < roundSteps; i++) {
    advance(round);
    // The clock's end takes the marbles off the field with the round over.
    if (round.game.player(roboPlayerId) == null) break;
    final at = mapUnits(roboAt(round.game));
    if ((at - anchor).distance > reach) {
      anchor = at;
      since = 0;
    } else {
      since += stepS;
      most = max(most, since);
    }
  }
  return most;
}

void main() {
  group('Robo reaches a coin on all five maps', () {
    for (final level in RoboLevel.values) {
      test('at ${level.name} within ${firstCoinS[level]} s', () {
        for (final map in mapLibrary()) {
          for (final seed in seeds) {
            final time = firstCoin(roundOf(map, level, seed: seed));
            expect(
              time,
              lessThanOrEqualTo(firstCoinS[level]!),
              reason: '${map.id} at ${level.name}, seed $seed: ${time.toStringAsFixed(2)} s',
            );
          }
        }
      });
    }
  });

  test('Easy scores less than Medium, and Medium less than Hard, over seeded rounds', () {
    final totals = <RoboLevel, int>{};
    for (final level in RoboLevel.values) {
      var coins = 0;
      for (final map in mapLibrary()) {
        for (final seed in seeds) {
          coins += coinsOf(roundOf(map, level, seed: seed));
        }
      }
      totals[level] = coins;
    }
    expect(totals[RoboLevel.easy], lessThan(totals[RoboLevel.medium]!), reason: 'totals $totals');
    expect(totals[RoboLevel.medium], lessThan(totals[RoboLevel.hard]!), reason: 'totals $totals');
  });

  test('Robo is never held up for more than two seconds', () {
    for (final map in mapLibrary()) {
      for (final level in RoboLevel.values) {
        for (final seed in [1, 2]) {
          final held = longestHeld(roundOf(map, level, seed: seed));
          expect(
            held,
            lessThan(2),
            reason: '${map.id} at ${level.name}, seed $seed: held ${held.toStringAsFixed(2)} s',
          );
        }
      }
    }
  });

  test('the same seed plays the same round twice', () {
    final map = mapLibrary().first;
    final a = roundOf(map, RoboLevel.hard, seed: 5);
    final b = roundOf(map, RoboLevel.hard, seed: 5);
    for (var i = 0; i < 600; i++) {
      final fromA = a.pilot.step(a.game, stepS);
      final fromB = b.pilot.step(b.game, stepS);
      expect(fromB.move, fromA.move, reason: 'step $i');
      expect(fromB.dash, fromA.dash);
      a.game.update(stepS, {humanId: GameInput.none, roboPlayerId: fromA});
      b.game.update(stepS, {humanId: GameInput.none, roboPlayerId: fromB});
      expect(roboAt(b.game), roboAt(a.game), reason: 'step $i');
    }
  });

  test('Robo never asks to move faster than a marble may', () {
    final map = mapLibrary().first;
    for (final level in RoboLevel.values) {
      final round = roundOf(map, level);
      for (var i = 0; i < 1200; i++) {
        final input = round.pilot.step(round.game, stepS);
        expect(input.move.distance, lessThanOrEqualTo(1.0), reason: '${level.name} step $i');
        round.game.update(stepS, {humanId: GameInput.none, roboPlayerId: input});
      }
    }
  });

  group('Robo shoves as the level table says (party-night §7a)', () {
    /// [units] as a fraction of the field, as a map writes a point.
    Offset fractionIn(Offset units) => Offset(units.dx / mapFieldSize.width, units.dy / mapFieldSize.height);

    /// A spot in map units where a push along +x runs into a wall (or, with
    /// [intoWall] false, stays in the open for a few cells), with no hazard
    /// near it or the way, and free ground two cells behind for Robo; null
    /// when the map has none.
    Offset? spotWhere(ArenaGame game, MapGrid grid, {required bool intoWall}) {
      final hazards = [
        for (final hazard in game.hazardPositions)
          mapUnits(Offset(hazard.dx / game.size.width, hazard.dy / game.size.height)),
      ];
      bool clear(Offset at) => hazards.every((hazard) => (hazard - at).distance >= grid.cell * 4);
      for (var j = 0; j * grid.cell < mapFieldSize.height; j++) {
        for (var i = 0; i * grid.cell < mapFieldSize.width; i++) {
          final at = Offset((i + 0.5) * grid.cell, (j + 0.5) * grid.cell);
          if (!grid.isFree(fractionIn(at)) || !clear(at)) continue;
          final way = [for (var n = 1; n <= 12; n++) at + Offset(grid.cell * n / 4, 0)];
          if (way.any((step) => !grid.isFree(fractionIn(step))) != intoWall) continue;
          if (!clear(way.last)) continue;
          final behind = at - Offset(grid.cell * 2, 0);
          if (!grid.isFree(fractionIn(behind)) || !clear(behind)) continue;
          return at;
        }
      }
      return null;
    }

    /// A round on the first map with such a spot: Robo two cells behind the
    /// player, the player at the spot.
    ({PilotRound round, Offset robo, Offset player})? shoveSetUp(RoboLevel level, {required bool intoWall}) {
      for (final map in mapLibrary()) {
        final game = ArenaGame(map: map, mode: ArenaMode.bumper, random: Random(1));
        final grid = cpuGrid(map);
        final at = spotWhere(game, grid, intoWall: intoWall);
        if (at == null) continue;
        return (
          round: (game: game, pilot: CpuPilot(level: level, grid: grid, random: Random(1))),
          robo: at - Offset(grid.cell * 2, 0),
          player: at,
        );
      }
      return null;
    }

    /// The times, in seconds, that Robo shoves the player in a round where it
    /// stands [robo] and a player holding two coins stands [player], both in
    /// map units and both put back each step, so the table's shove rules move
    /// the count rather than the chase for a coin. A shove is the arena's own
    /// count of the marbles a dash pushed, so a dash at a coin that misses the
    /// player is no shove.
    List<double> shovesIn(({PilotRound round, Offset robo, Offset player}) setup, {double seconds = 10}) {
      final game = setup.round.game;
      advance(setup.round); // Robo's and the player's marbles come out with the first step.
      final times = <double>[];
      var shoves = 0;
      for (var i = 1; i <= (seconds / stepS).round(); i++) {
        game.player(roboPlayerId)!.place(game.pixelOf(fractionIn(setup.robo)));
        game.player(humanId)!
          ..place(game.pixelOf(fractionIn(setup.player)))
          ..coins = 2;
        game.update(stepS, {humanId: GameInput.none, roboPlayerId: setup.round.pilot.step(game, stepS)});
        final now = game.player(roboPlayerId)!.shoves;
        if (now > shoves) times.add(i * stepS);
        shoves = now;
      }
      return times;
    }

    test('Easy never seeks a shove, even with a player beside it holding coins', () {
      final setup = shoveSetUp(RoboLevel.easy, intoWall: false);
      expect(setup, isNotNull, reason: 'one of the maps has open ground to stand on');
      expect(shovesIn(setup!, seconds: 10), isEmpty);
    });

    test('Medium shoves a close player with coins, at most one every 4 s', () {
      final setup = shoveSetUp(RoboLevel.medium, intoWall: false);
      expect(setup, isNotNull, reason: 'one of the maps has open ground to stand on');
      final times = shovesIn(setup!, seconds: 10);
      expect(times, isNotEmpty, reason: 'Medium shoves a close player holding coins');
      for (var i = 1; i < times.length; i++) {
        expect(times[i] - times[i - 1], greaterThanOrEqualTo(4 - stepS), reason: 'shoves at $times');
      }
    });

    test('Hard aims its shoves at a wall every 2 s, and leaves an open push be', () {
      final wall = shoveSetUp(RoboLevel.hard, intoWall: true);
      final open = shoveSetUp(RoboLevel.hard, intoWall: false);
      expect(wall, isNotNull, reason: 'one of the maps has ground a shove sends a marble into a wall');
      expect(open, isNotNull, reason: 'one of the maps has open ground to stand on');
      final times = shovesIn(wall!, seconds: 10);
      expect(times, isNotEmpty, reason: 'Hard shoves a player a wall is behind');
      for (var i = 1; i < times.length; i++) {
        expect(times[i] - times[i - 1], greaterThanOrEqualTo(2 - stepS), reason: 'shoves at $times');
      }
      expect(shovesIn(open!, seconds: 10), isEmpty, reason: 'a push with nothing behind it is not aimed at anything');
    });
  });

  test('Robo dashes toward a far coin, at every level', () {
    for (final map in mapLibrary()) {
      for (final level in RoboLevel.values) {
        final round = roundOf(map, level);
        for (var i = 0; i < roundSteps && round.game.phase == ArenaPhase.playing; i++) {
          advance(round);
        }
        expect(
          round.game.player(roboPlayerId)!.dashes,
          greaterThan(0),
          reason: '${map.id} at ${level.name}: a dash toward a coin within reach of a walk',
        );
      }
    }
  });

  test('Robo asks for nothing when its marble is not on the field', () {
    final pilot = CpuPilot(level: RoboLevel.hard, grid: cpuGrid(mapLibrary().first), random: Random(1));
    final race = ArenaGame(map: mapLibrary().first, random: Random(1));
    final input = pilot.step(race, stepS);
    expect(input.move, Offset.zero);
    expect(input.dash, isFalse);
  });
}
