import 'dart:math';

import 'puzzle.dart';

/// Each piece's start angle: a turned piece (rotated, and not a circle) at a
/// random angle at least 30° from any correct one (up to 50 tries, as now),
/// the others at their target angle. In degrees, 0 to 360.
Map<int, double> startAngles(Puzzle puzzle, Random random) {
  final starts = <int, double>{};
  for (final (i, spec) in puzzle.pieces.indexed) {
    var angle = spec.targetAngle;
    if (spec.rotated && spec.shape.symmetry != 0) {
      for (var tries = 0; tries < 50; tries++) {
        angle = spec.targetAngle + random.nextDouble() * 360;
        if (angleError(angle, spec.targetAngle, spec.shape.symmetry) >= 30) break;
      }
    }
    starts[i] = angle % 360;
  }
  return starts;
}

/// Start angles for a split-screen tray: each turned piece (rotated, not a
/// circle) at an allowed angle (at least 30° from any correct one, by
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
      for (var a = 0; a < 360; a++) {
        if (angleError(a.toDouble(), spec.targetAngle, shape.symmetry) < 30) continue;
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
