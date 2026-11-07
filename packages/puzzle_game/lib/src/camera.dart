import 'dart:math';
import 'dart:ui';

import 'match.dart';
import 'puzzle.dart';
import 'split_layout.dart';

/// What a phone draws of a match (m12-phone-layout §2): the whole match, or
/// the one side a player plays on. [forPlayer] picks it from a phone's player
/// ID; the painters and the size check ask it for the scale, so both always
/// draw what the rules play.
///
/// A `phones` layout is the one with a [SplitLayout.hud] (m12 §1); a screen
/// layout has none and is drawn as today's picture.
final class PuzzleCamera {
  /// The whole match: on the split screen today's picture; on a phone the two
  /// sides side by side when the box is wider than 3:1, else stacked with the
  /// left side on top, each with its own clock area.
  const PuzzleCamera.whole() : side = null;

  /// One side's world, fitted to the box and aligned to its bottom, so the
  /// spare height goes on top, away from the thumbs (m12-phone-layout §2).
  const PuzzleCamera.side(this.side);

  /// The side this camera shows, or null for the whole match.
  final PuzzleSide? side;

  /// The widest a box may be, against its height, before the whole match
  /// draws its sides side by side rather than stacked: two worlds of about a
  /// phone's shape take a wide box's width, and a box that wide is not a
  /// phone (m12-phone-layout §2).
  static const wholeSideBySideAspect = 3.0;

  /// The camera a phone draws [target]'s match with (m12-phone-layout §2): the
  /// side [playerId] plays on, or the whole match when they play no side, when
  /// [wholeMatch] is set (a tablet has the room for both), or on the screen.
  static PuzzleCamera forPlayer({
    required LayoutTarget target,
    required Map<String, PuzzleSide> teams,
    String? playerId,
    bool wholeMatch = false,
  }) {
    if (target == LayoutTarget.screen || wholeMatch || playerId == null) return const PuzzleCamera.whole();
    final side = teams[playerId];
    return side == null ? const PuzzleCamera.whole() : PuzzleCamera.side(side);
  }

  /// Px per world unit that [camera] draws [layout] at in [box] (m12-phone-
  /// layout §2): the painters' scale, and the size check's.
  ///
  /// On the screen that is [fieldIn]'s, px per field unit of the 160 x 90
  /// picture; on a phone it is px per unit of the world the sides are drawn
  /// in, which [place] fits to the box.
  static double scale(SplitLayout layout, PuzzleCamera camera, Size box) =>
      layout.hud == null ? fieldIn(box).scale : place(layout, camera, box, PuzzleSide.left).scale;

  /// Where [side]'s world is drawn in [box] on a phone: px per world unit and
  /// the world's top left in px (m12-phone-layout §2). Both sides are the one
  /// [SplitLayout.left] world, so only the position differs between them.
  static ({double scale, Offset origin}) place(SplitLayout layout, PuzzleCamera camera, Size box, PuzzleSide side) {
    final world = layout.left.size;
    if (camera.side != null) {
      // One world, fitted: the spare width is shared, the spare height is on
      // top.
      final scale = min(box.width / world.width, box.height / world.height);
      final origin = Offset((box.width - world.width * scale) / 2, box.height - world.height * scale);
      return (scale: scale, origin: origin);
    }
    // Both worlds, centred, side by side or stacked: the left one is the
    // first from the top left.
    if (box.width > wholeSideBySideAspect * box.height) {
      final scale = min(box.width / (2 * world.width), box.height / world.height);
      final left = Offset((box.width - 2 * world.width * scale) / 2, (box.height - world.height * scale) / 2);
      return (scale: scale, origin: side == PuzzleSide.left ? left : left + Offset(world.width * scale, 0));
    }
    final scale = min(box.width / world.width, box.height / (2 * world.height));
    final left = Offset((box.width - world.width * scale) / 2, (box.height - 2 * world.height * scale) / 2);
    return (scale: scale, origin: side == PuzzleSide.left ? left : left + Offset(0, world.height * scale));
  }

  @override
  bool operator ==(Object other) => other is PuzzleCamera && other.side == side;

  @override
  int get hashCode => side.hashCode;
}

/// The field of size [field] in [box]: the scale and the offset of its top
/// left.
({double scale, Offset origin}) fieldIn(Size box, [Size field = fieldSize]) {
  final scale = min(box.width / field.width, box.height / field.height);
  final origin = Offset((box.width - field.width * scale) / 2, (box.height - field.height * scale) / 2);
  return (scale: scale, origin: origin);
}
