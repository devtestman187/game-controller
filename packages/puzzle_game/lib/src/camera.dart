import 'dart:math';
import 'dart:ui';

import 'match.dart';
import 'piece_size.dart';
import 'puzzle.dart';
import 'split_layout.dart';

/// What a phone draws of the other side (m12-opponent-mirror rules 1–8): the
/// mirror's rect in the box's px, the px per board unit it draws their board
/// at, and where the clock area goes with it ([PuzzleCamera.mirrorPlace]).
typedef MirrorPlacement = ({Rect rect, double scale, ({Rect rect, HudForm form}) hud});

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
  /// spare height goes on top, away from the thumbs (m12-phone-layout §2);
  /// in a portrait box it is aligned to the top instead, so the spare height
  /// under it is the clock area's (device test 3).
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
      // One world, fitted: the spare width is shared, and a portrait box puts
      // the spare height under the world (device test 3), else on top.
      final scale = min(box.width / world.width, box.height / world.height);
      final spare = box.height - world.height * scale;
      final origin = Offset((box.width - world.width * scale) / 2, box.height > box.width ? 0 : spare);
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

  /// The box's shorter side, in px: what every HUD size is a fraction of
  /// (m12-phone-layout §0.7c, device test 3). A phone on its side is 393 px
  /// tall — its shorter side — so its clock area is the size it was; a
  /// portrait tablet's is its width's, not its height's.
  static double hudUnit(Size box) => min(box.width, box.height);

  /// Where a phone's clock area starts, as a fraction of the box's shorter
  /// side ([hudUnit]) (m12-phone-layout §0.7c): 0.14 of a 393 px phone is
  /// 55 px, just below the 52 px top bar the phone app draws over the game.
  static const hudTopFraction = 0.14;

  /// The clock's text height, as a fraction of the box's shorter side (§0.7c),
  /// and the score's: the clock is the one thing read from across the room.
  static const hudClockFraction = 0.08;
  static const hudScoreFraction = 0.04;

  /// The gap between the clock area's lines and above its bar, as a fraction
  /// of the box's shorter side: half the score's height, so the lines read
  /// apart at any size.
  static const hudLineGapFraction = 0.02;

  /// The time bar's thickness, as a fraction of the box's shorter side: 4.7 px
  /// on a 393 px phone, as thin as the clock's stroke.
  static const hudBarFraction = 0.012;

  /// The clock area's height in its one-line form (clock, gap, bar) and in its
  /// two-line form (clock, gap, score, gap, bar), as fractions of the box's
  /// shorter side.
  static const hudOneLineHeight = hudClockFraction + hudLineGapFraction + hudBarFraction;
  static const hudTwoLineHeight = hudClockFraction + 2 * hudLineGapFraction + hudScoreFraction + hudBarFraction;

  /// A character's width as a fraction of its text height: the widest the
  /// look's Fredoka 600 draws any of the HUD's texts, so a form chosen by it is
  /// never too small for them (measured in `text_measure_test.dart`, which is
  /// why the number is public).
  static const glyphEm = 0.55;

  /// The characters the clock is measured for: "10:00", a 10 minute limit, so
  /// the clock area never changes form as the clock counts down.
  static const _clockChars = 5;

  /// The width [text] takes at [hudScoreFraction], as a fraction of the box's
  /// shorter side.
  static double _textWidth(String text) => text.length * glyphEm * hudScoreFraction;

  /// The width and the height [form] needs for [text], as fractions of the
  /// box's shorter side (m12-phone-layout §0.7c): one line is the clock and
  /// the score beside each other, two lines put the score under the clock, and
  /// the short form puts each of [text]'s short lines under the clock on a
  /// line of its own, with [hudLineGapFraction] between lines and the bar
  /// under them all.
  static ({double width, double height}) _hudSize(HudForm form, ({String score, List<String> short}) text) {
    final clock = _clockChars * glyphEm * hudClockFraction;
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

  /// The air between the other side's mirror and what it must not meet — the
  /// clock area beside it, their board, the tray row and this player's pad — in
  /// px (m12-opponent-mirror rules 5 and 8): its own frame, with room round it.
  static const mirrorGapPx = 8.0;

  /// The slack on a fit: a board whose smallest piece draws exactly at
  /// [mirrorMinPieceMm] keeps its mirror, and a form exactly as wide as the
  /// room keeps its place, though floating point may put either a hair under.
  static const _floorSlack = 1e-9;

  /// The distance from the board's top-left corner to the clock area when it
  /// has no room beside the world, in px (§0.7c's last resort).
  static const hudCornerMarginPx = 8.0;

  /// The mirror's size against the board's drawn size (m12-opponent-mirror
  /// rules 1 and 5): a quarter of the board is what the owner's sketch shows,
  /// but a quarter of a board at the size check's floor draws its smallest
  /// piece at 2.13 mm, under the 2.2 mm that reads, so the mirror draws at
  /// [mirrorMinPieceMm] over [minPieceMm] — 0.26 of the board, and every piece
  /// at 2.2 mm or more.
  static const mirrorFraction = mirrorMinPieceMm / minPieceMm;

  /// Where the other side's mirror goes in [box] and where the clock area goes
  /// with it, or null where a phone draws none (m12-opponent-mirror rules
  /// 1–8): a one-board match ([split] false — solo or a team), the whole match
  /// (a tablet), the screen (the TV), and a box where neither place is both
  /// clear of this player's pad and big enough to read.
  ///
  /// Rule 8's two places, in order. The corner: [hudMarginPx] from the box's
  /// left and [hudTopFraction] of its height down, under the top bar, with the
  /// clock area to its right in its short form (rule 5). The gap: under the
  /// clock area, between the left hand's controls and their board, with the
  /// clock area where a phone without a mirror draws it (rule 8's sketch). In
  /// each place the mirror takes the largest scale that fits — up to
  /// [mirrorFraction] of the board's drawn size — and keeps it only if its
  /// smallest piece still draws at [mirrorMinPieceMm], which [pxPerMm] turns
  /// into px: a wide board on a narrow box draws a smaller mirror rather than
  /// none, and one too small to read draws no mirror there.
  ///
  /// [puzzle] is their picture, whose smallest piece sets that floor; the
  /// mirror is their board's own shape, never stretched. [text] is the HUD the
  /// phone draws without a mirror, which the corner measures its room against.
  /// [padRects] are the controls the app draws under the game, in the box's
  /// px: the app's own geometry, passed through the view, so the game never
  /// copies it (rules 3 and 6).
  static MirrorPlacement? mirrorPlace(
    Puzzle puzzle,
    SplitLayout layout,
    PuzzleCamera camera,
    Size box, {
    required bool split,
    required ({String score, List<String> short}) text,
    double pxPerMm = phonePxPerMm,
    List<Rect> padRects = const [],
  }) {
    if (!split || camera.side == null || layout.target != LayoutTarget.phones) return null;
    final world = place(layout, camera, box, camera.side!);
    final board = layout.left.board;
    final maxScale = world.scale * mirrorFraction;
    // The smallest mark the mirror draws is the smallest piece: a dot is that
    // size or bigger ([mirrorDotRadius]), so it never sets a smaller floor.
    final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
    final floor = mirrorMinPieceMm * pxPerMm / smallest;
    Rect onScreen(Rect r) => Rect.fromLTWH(
      world.origin.dx + r.left * world.scale,
      world.origin.dy + r.top * world.scale,
      r.width * world.scale,
      r.height * world.scale,
    );
    // What the mirror must not meet: their board and tray row, this phone's own
    // pad (rules 3 and 8), and the clock area.
    final boardAndTray = [onScreen(board), onScreen(layout.left.tray), ...padRects];
    final hud = hudPlace(layout, camera, box, text, padRects: padRects, split: split);
    // The corner, with the clock area to its right in its short form, clear of
    // the world: its left edge is where the mirror's right must stop.
    final unit = hudUnit(box);
    final shortForm = _hudSize(HudForm.short, text);
    final besideHud = Rect.fromLTWH(
      world.origin.dx - hudWorldGapPx - unit * shortForm.width,
      unit * hudTopFraction,
      unit * shortForm.width,
      unit * shortForm.height,
    );
    final cornerTop = unit * hudTopFraction;
    final corner = _fitting(box, board.size, Offset(hudMarginPx, cornerTop), maxScale, floor, [
      ...boardAndTray,
      besideHud,
    ]);
    if (corner != null) {
      final rect = Rect.fromLTWH(hudMarginPx, cornerTop, board.width * corner, board.height * corner);
      return (rect: rect, scale: corner, hud: hudPlace(layout, camera, box, text, mirror: rect));
    }
    // The gap, under the clock area, right of the controls that reach into the
    // band the mirror can take there.
    final top = hud.rect.bottom + mirrorGapPx;
    var left = hudMarginPx;
    for (final pad in padRects) {
      if (pad.top < top + board.height * maxScale && pad.bottom > top) left = max(left, pad.right + mirrorGapPx);
    }
    final gap = _fitting(box, board.size, Offset(left, top), maxScale, floor, [...boardAndTray, hud.rect]);
    if (gap == null) return null;
    return (rect: Rect.fromLTWH(left, top, board.width * gap, board.height * gap), scale: gap, hud: hud);
  }

  /// The largest scale, up to [maxScale], at which [board]'s shape with its top
  /// left at [at] fits [box] and meets none of [obstacles] — each with
  /// [mirrorGapPx] of air round it — or null when that is under [floor], the
  /// scale below which the mirror's smallest piece stops reading.
  static double? _fitting(Size box, Size board, Offset at, double maxScale, double floor, List<Rect> obstacles) {
    var scale = min(maxScale, min((box.width - at.dx) / board.width, (box.height - at.dy) / board.height));
    for (final obstacle in obstacles) {
      final r = obstacle.inflate(mirrorGapPx);
      // A rect wholly up or left of the place can't be met however big the
      // mirror gets.
      if (r.right <= at.dx || r.bottom <= at.dy) continue;
      scale = min(scale, max((r.left - at.dx) / board.width, (r.top - at.dy) / board.height));
    }
    return scale + _floorSlack >= floor ? scale : null;
  }

  /// Where the clock area starts in [box] and the width it has, right of the
  /// world and of [mirror] when the box shows one (m12-opponent-mirror rule 5).
  static ({double left, double spare}) _hudRoom(SplitLayout layout, PuzzleCamera camera, Size box, Rect? mirror) {
    final world = place(layout, camera, box, PuzzleSide.left);
    final left = mirror == null ? hudMarginPx : mirror.right + mirrorGapPx;
    return (left: left, spare: world.origin.dx - hudWorldGapPx - left);
  }

  /// Where the clock area goes in [box] and which form it takes
  /// (m12-phone-layout §0.7c, device test 3): beside the world, at
  /// [hudTopFraction] of the box's shorter side, in the first of [HudForm]'s
  /// forms that the spare width fits — one line, two lines, then
  /// [HudForm.short] — then under the world in the first form that fits its
  /// width, and otherwise over the board's top-left corner on a panel the
  /// painter draws, the last resort. [text] is what the HUD may draw, so the
  /// form is picked by the real score; the clock counts for "10:00" whatever
  /// it says now. [rect] is the area the texts and the bar go in, in px.
  ///
  /// With a [mirror] to its left the area starts at the mirror's right edge
  /// and draws the short form (m12-opponent-mirror rule 5): the mirror takes
  /// the width one line needs, and the short form puts "You 2/4" and
  /// "Them 3/6" on a line each, which is what fits beside it.
  ///
  /// [padRects] are the controls the app draws under the game, in the box's
  /// px, as [mirrorPlace] takes them: the clock area keeps clear of them like
  /// the mirror does (device test 3). [split] says whether the camera draws
  /// both sides of a whole match, which decides which world the area goes
  /// under.
  static ({Rect rect, HudForm form}) hudPlace(
    SplitLayout layout,
    PuzzleCamera camera,
    Size box,
    ({String score, List<String> short}) text, {
    Rect? mirror,
    List<Rect> padRects = const [],
    bool split = false,
  }) {
    final unit = hudUnit(box);
    final room = _hudRoom(layout, camera, box, mirror);
    final top = unit * hudTopFraction;
    final forms = mirror == null ? const [HudForm.oneLine, HudForm.twoLines, HudForm.short] : const [HudForm.short];
    for (final form in forms) {
      final size = _hudSize(form, text);
      if (room.spare >= unit * size.width) {
        return (rect: Rect.fromLTWH(room.left, top, unit * size.width, unit * size.height), form: form);
      }
    }
    if (mirror == null) {
      // Under the world is the last place before the corner: the world drawn
      // last, a side camera's only world or the lower one of a whole match.
      final under = place(layout, camera, box, camera.side ?? (split ? PuzzleSide.right : PuzzleSide.left));
      final fits = _hudUnder(box, text, (
        left: under.origin.dx,
        top: under.origin.dy + layout.left.size.height * under.scale + hudWorldGapPx,
        room: layout.left.size.width * under.scale,
      ), padRects);
      if (fits != null) return fits;
    }
    final world = place(layout, camera, box, PuzzleSide.left);
    final board = Rect.fromLTWH(
      world.origin.dx + layout.left.board.left * world.scale,
      world.origin.dy + layout.left.board.top * world.scale,
      layout.left.board.width * world.scale,
      layout.left.board.height * world.scale,
    );
    final size = _hudSize(HudForm.corner, text);
    final width = min(unit * size.width, board.width - 2 * hudCornerMarginPx);
    return (
      rect: Rect.fromLTWH(board.left + hudCornerMarginPx, board.top + hudCornerMarginPx, width, unit * size.height),
      form: HudForm.corner,
    );
  }

  /// The clock area under the world in [box] at [under], in the first of
  /// [HudForm]'s forms that fits its width, or null where none does: the box
  /// has no room under the world, or the pad is there (device test 3). The
  /// area keeps [mirrorGapPx] of air from every one of [padRects].
  static ({Rect rect, HudForm form})? _hudUnder(
    Size box,
    ({String score, List<String> short}) text,
    ({double left, double top, double room}) under,
    List<Rect> padRects,
  ) {
    final unit = hudUnit(box);
    for (final form in const [HudForm.oneLine, HudForm.twoLines, HudForm.short]) {
      final size = _hudSize(form, text);
      final rect = Rect.fromLTWH(under.left, under.top, unit * size.width, unit * size.height);
      final inside = rect.left >= 0 && rect.top >= 0 && rect.right <= box.width && rect.bottom <= box.height;
      if (!inside || rect.width > under.room + _floorSlack) continue;
      if (padRects.any((pad) => pad.inflate(mirrorGapPx).overlaps(rect))) continue;
      return (rect: rect, form: form);
    }
    return null;
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
