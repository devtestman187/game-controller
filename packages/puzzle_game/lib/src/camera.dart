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
/// A [SplitLayout.target] of `phones` is fitted to the box a phone gives it;
/// a screen layout is drawn as today's picture.
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
      layout.target == LayoutTarget.phones ? place(layout, camera, box, PuzzleSide.left).scale : fieldIn(box).scale;

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

  /// Where a phone's clock area starts, as a fraction of the box height
  /// (m12-phone-layout §0.7c): 0.14 of a 393 px phone is 55 px, just below the
  /// 52 px top bar the phone app draws over the game.
  static const hudTopFraction = 0.14;

  /// The clock's text height, as a fraction of the box height (§0.7c), and
  /// the score's: the clock is the one thing read from across the room.
  static const hudClockFraction = 0.08;
  static const hudScoreFraction = 0.04;

  /// The gap between the clock area's lines and above its bar, as a fraction
  /// of the box height: half the score's height, so the lines read apart at
  /// any size.
  static const hudLineGapFraction = 0.02;

  /// The time bar's thickness, as a fraction of the box height: 4.7 px on a
  /// 393 px phone, as thin as the clock's stroke.
  static const hudBarFraction = 0.012;

  /// The clock area's height in its one-line form (clock, gap, bar) and in its
  /// two-line form (clock, gap, score, gap, bar), as fractions of the box
  /// height.
  static const hudOneLineHeight = hudClockFraction + hudLineGapFraction + hudBarFraction;
  static const hudTwoLineHeight = hudClockFraction + 2 * hudLineGapFraction + hudScoreFraction + hudBarFraction;

  /// A character's width as a fraction of its text height. The app's font
  /// draws most glyphs narrower than this, so a form chosen by it is never too
  /// small for the texts; the test font's square glyphs are wider.
  static const _glyphEm = 0.5;

  /// The characters the clock is measured for: "10:00", a 10 minute limit, so
  /// the clock area never changes form as the clock counts down.
  static const _clockChars = 5;

  /// The width [text] takes at [hudScoreFraction], as a fraction of the box
  /// height.
  static double _textWidth(String text) => text.length * _glyphEm * hudScoreFraction;

  /// The width and the height [form] needs for [text], as fractions of the box
  /// height (m12-phone-layout §0.7c): one line is the clock and the score
  /// beside each other, two lines put the score under the clock, and the short
  /// form puts each of [text]'s short lines under the clock on a line of its
  /// own, with [hudLineGapFraction] between lines and the bar under them all.
  static ({double width, double height}) _hudSize(HudForm form, ({String score, List<String> short}) text) {
    final clock = _clockChars * _glyphEm * hudClockFraction;
    final lines = form == HudForm.oneLine || form == HudForm.twoLines ? [text.score] : text.short;
    final widest = [clock, ...lines.map(_textWidth)].reduce(max);
    return (
      width: form == HudForm.oneLine ? clock + hudLineGapFraction + _textWidth(text.score) : widest,
      height: form == HudForm.oneLine
          ? hudOneLineHeight
          : hudTwoLineHeight + (lines.length - 1) * (hudLineGapFraction + hudScoreFraction),
    );
  }

  /// The distance from the box's left edge to the clock area, and from the
  /// clock area to the world, in px: enough to keep the texts clear of the
  /// screen's rounded corner and of the board.
  static const hudMarginPx = 8.0;
  static const hudWorldGapPx = 8.0;

  /// The distance from the board's top-left corner to the clock area when it
  /// has no room beside the world, in px (§0.7c's last resort).
  static const hudCornerMarginPx = 8.0;

  /// Where the clock area goes in [box] and which form it takes
  /// (m12-phone-layout §0.7c): beside the world, at [hudTopFraction] of the
  /// box's height, in the first of [HudForm]'s forms that the spare width fits
  /// — one line, two lines, then [HudForm.short] — and otherwise over the
  /// board's top-left corner on a panel the painter draws. [text] is what the
  /// HUD may draw, so the form is picked by the real score; the clock counts
  /// for "10:00" whatever it says now. [rect] is the area the texts and the
  /// bar go in, in px.
  static ({Rect rect, HudForm form}) hudPlace(
    SplitLayout layout,
    PuzzleCamera camera,
    Size box,
    ({String score, List<String> short}) text,
  ) {
    final world = place(layout, camera, box, PuzzleSide.left);
    final spare = world.origin.dx - hudMarginPx - hudWorldGapPx;
    final top = box.height * hudTopFraction;
    const forms = [HudForm.oneLine, HudForm.twoLines, HudForm.short];
    for (final form in forms) {
      final size = _hudSize(form, text);
      if (spare >= box.height * size.width) {
        return (rect: Rect.fromLTWH(hudMarginPx, top, box.height * size.width, box.height * size.height), form: form);
      }
    }
    final board = Rect.fromLTWH(
      world.origin.dx + layout.left.board.left * world.scale,
      world.origin.dy + layout.left.board.top * world.scale,
      layout.left.board.width * world.scale,
      layout.left.board.height * world.scale,
    );
    final size = _hudSize(HudForm.corner, text);
    final width = min(box.height * size.width, board.width - 2 * hudCornerMarginPx);
    return (
      rect: Rect.fromLTWH(
        board.left + hudCornerMarginPx,
        board.top + hudCornerMarginPx,
        width,
        box.height * size.height,
      ),
      form: HudForm.corner,
    );
  }

  @override
  bool operator ==(Object other) => other is PuzzleCamera && other.side == side;

  @override
  int get hashCode => side.hashCode;
}

/// The form a phone's clock area takes (m12-phone-layout §0.7c), narrowest
/// first: one line when the box's spare width fits the clock beside the whole
/// score, two lines when it fits the score under the clock, [short] when it
/// fits only the score's short lines ("You 2/4", "Right 3/6") under the clock,
/// and over the board's corner when it fits none of them.
enum HudForm { oneLine, twoLines, short, corner }

/// The field of size [field] in [box]: the scale and the offset of its top
/// left.
({double scale, Offset origin}) fieldIn(Size box, [Size field = fieldSize]) {
  final scale = min(box.width / field.width, box.height / field.height);
  final origin = Offset((box.width - field.width * scale) / 2, (box.height - field.height * scale) / 2);
  return (scale: scale, origin: origin);
}
