import 'dart:math';

import 'puzzle.dart';

/// The least a turned piece starts away from any correct angle, in degrees, at
/// each level (B-012b): Easy 30, Medium 60, Hard 90. A piece that started
/// closer would look almost right, so there would be nothing to turn. Harder
/// is more turning, never more clock: the clock stays one setting.
double levelStartDeg(Level level) => switch (level) {
  Level.easy => 30.0,
  Level.medium => 60.0,
  Level.hard => 90.0,
};

/// The least error, in degrees, a turned piece of [level] starts at:
/// [levelStartDeg] or half the shape's [symmetry] where that is less, since no
/// piece can be turned further off than that — a square is back onto itself
/// every 90°, so 45° is the furthest it starts, and a triangle 60°.
double leastStartDeg(Level level, double symmetry) => min(levelStartDeg(level), symmetry / 2);

/// The most a whole degree falls short of a least error, in degrees: half a
/// degree. A piece's target angle may not be whole, and a tray lays its pieces
/// at whole degrees only, so the furthest whole degree can sit this far under
/// [leastStartDeg] — and a turned piece must still not start correct.
const wholeDegreeSlackDeg = 0.5;

/// Each piece's start angle: a turned piece (rotated, and not a circle) at a
/// random error from [leastStartDeg] up to half its symmetry, either side of
/// its target angle; the others at their target angle. In degrees, 0 to 360.
Map<int, double> startAngles(Puzzle puzzle, Random random) {
  final starts = <int, double>{};
  for (final (i, spec) in puzzle.pieces.indexed) {
    var angle = spec.targetAngle;
    if (spec.rotated && spec.shape.symmetry != 0) {
      // The error is picked first, not a random angle that has to land far
      // enough off: with 90° to reach for a rectangle, chance never gets there.
      final least = leastStartDeg(puzzle.level, spec.shape.symmetry);
      final error = least + random.nextDouble() * (spec.shape.symmetry / 2 - least);
      angle = spec.targetAngle + (random.nextBool() ? error : -error);
    }
    starts[i] = angle % 360;
  }
  return starts;
}

/// Start angles for a split-screen tray: each turned piece (rotated, not a
/// circle) at an allowed angle (at least [leastStartDeg] from any correct one,
/// [wholeDegreeSlackDeg] under it where the target angle is not whole, by
/// [angleError] with the shape's symmetry) whose box is within 10% of the
/// smallest allowed box height ([flat] true: for a tray below the board) or
/// width ([flat] false: for a tray beside it), chosen at random among those,
/// scanning whole degrees 0 to 359. A long piece that starts correct (not
/// turned; its box at the target angle at least twice as tall as wide, or
/// twice as wide as tall) lies along the tray: at targetAngle + 90 when that
/// makes the box flatter (flat) or narrower (not flat); otherwise at
/// targetAngle, like every other piece that starts correct. In degrees, 0 to
/// 360.
Map<int, double> compactStartAngles(Puzzle puzzle, Random random, {required bool flat}) {
  final starts = <int, double>{};
  for (final (i, spec) in puzzle.pieces.indexed) {
    final shape = spec.shape;
    if (spec.rotated && shape.symmetry != 0) {
      // Every whole degree that is far enough from correct, with the box
      // height (or width) it gives.
      final allowed = <int>[];
      final sizes = <int, double>{};
      var smallest = double.infinity;
      final least = leastStartDeg(puzzle.level, shape.symmetry) - wholeDegreeSlackDeg;
      for (var a = 0; a < 360; a++) {
        if (angleError(a.toDouble(), spec.targetAngle, shape.symmetry) < least) continue;
        final box = shape.bounds(a.toDouble());
        allowed.add(a);
        sizes[a] = flat ? box.height : box.width;
        smallest = min(smallest, sizes[a]!);
      }
      if (allowed.isNotEmpty) {
        final flattest = [
          for (final a in allowed)
            if (sizes[a]! <= smallest * 1.1) a,
        ];
        starts[i] = flattest[random.nextInt(flattest.length)].toDouble();
        continue;
      }
    }
    var angle = spec.targetAngle;
    final box = shape.bounds(spec.targetAngle);
    final long = !shape.circle && (box.height >= 2 * box.width || box.width >= 2 * box.height);
    if (long) {
      final turned = shape.bounds(spec.targetAngle + 90);
      if (flat ? turned.height < box.height : turned.width < box.width) angle = spec.targetAngle + 90;
    }
    starts[i] = angle % 360;
  }
  return starts;
}
