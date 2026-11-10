import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena.dart';
import 'arena_map.dart';
import 'arena_mode.dart';
import 'arena_moments.dart';
import 'arena_painter.dart';
import 'arena_snapshot.dart';

/// A map as the waiting card shows it (M14 b2, design sections 7b and 8): the
/// field with its floor, walls, hazards, springs, posts, belts, movers and
/// decor, and no marbles on it, in a box of 16:9, as `tools/level.sh render`
/// draws a map's picture.
///
/// It draws the same [ArenaSnapshot] a round would start in, built once from
/// the map file (b1's rules), so the picture never drifts from the play: a new
/// piece of the kit shows here as soon as it is painted.
class ArenaMapPicture extends StatelessWidget {
  const ArenaMapPicture({super.key, required this.map, this.snapshot});

  /// The map to draw.
  final ArenaMap map;

  /// The field to draw; built from [map] when none is given (a test passes one
  /// to look at it).
  final ArenaSnapshot? snapshot;

  /// The field a map starts in: the Bumper Round's when the map can be bumped
  /// on, the race otherwise, with nobody on it.
  static ArenaSnapshot fieldOf(ArenaMap map) =>
      ArenaGame(map: map, mode: map.bumper == null ? ArenaMode.race : ArenaMode.bumper).snapshot();

  @override
  Widget build(BuildContext context) {
    final field = snapshot ?? fieldOf(map);
    return ClipRect(
      child: CustomPaint(
        key: const Key('arenaMapPicture'),
        painter: ArenaPainter(
          field,
          const <String, ({int number, String name})>{},
          look: ToyLookScope.of(context),
          moments: ArenaMoments(),
        ),
      ),
    );
  }
}
