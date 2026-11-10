import 'dart:math';
import 'dart:ui';

import 'match.dart';
import 'piece_size.dart';
import 'puzzle.dart';
import 'split_layout.dart';

part 'camera_fit.dart';

/// What a phone draws of the other side (m12-opponent-mirror rules 1–8): its
/// rect in the box's px, the px per board unit, and the clock area with it.
typedef MirrorPlacement = ({Rect rect, double scale, ({Rect rect, HudForm form}) hud});

/// What a phone draws of a match (m12-phone-layout §2): the whole match, or
/// the one side a player plays on, fitted to the box. [forPlayer] picks it,
/// and the painters and size check ask it for the scale they draw at.
final class PuzzleCamera {
  /// The whole match: on the split screen today's picture; on a phone the two
  /// sides side by side when the box is wider than 3:1, else stacked with the
  /// left side on top, each with its own clock area. A one-board round fills
  /// the box with its one world (m13 s18).
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
  /// phone's shape take a wide box's width (m12-phone-layout §2).
  static const wholeSideBySideAspect = 3.0;

  /// The camera a phone draws [target]'s match with (m12-phone-layout §2): the
  /// side [playerId] plays on, the whole match when they play no side or
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
  /// layout §2): the painters' scale and the size check's — the 160 x 90
  /// field's on the screen, and the world [place] fits on a phone.
  static double scale(
    SplitLayout layout,
    PuzzleCamera camera,
    Size box, {
    bool split = true,
    List<Rect> padRects = const [],
  }) => layout.target == LayoutTarget.phones
      ? place(layout, camera, box, PuzzleSide.left, split: split, padRects: padRects).scale
      : min(box.width / fieldSize.width, box.height / fieldSize.height);

  /// Where [side]'s world is drawn in [box] on a phone: px per world unit and
  /// the world's top left in px (m12-phone-layout §2). Both sides are the one
  /// [SplitLayout.left] world, so only the position differs between them. A
  /// whole camera on a one-board match ([split] false) fills [box] with its
  /// one world (m13 s18, device test 3), keeping its board and tray clear of
  /// [padRects]; see [_oneBoard].
  static ({double scale, Offset origin}) place(
    SplitLayout layout,
    PuzzleCamera camera,
    Size box,
    PuzzleSide side, {
    bool split = true,
    List<Rect> padRects = const [],
  }) {
    final world = layout.left.size;
    if (camera.side == null && !split) return _oneBoard(layout, box, padRects);
    if (camera.side != null) {
      // One world, fitted: the spare width is shared, and a portrait box puts
      // the spare height under the world (device test 3), else on top.
      final scale = min(box.width / world.width, box.height / world.height);
      final spare = box.height - world.height * scale;
      final origin = Offset((box.width - world.width * scale) / 2, box.height > box.width ? 0 : spare);
      return (scale: scale, origin: origin);
    }
    // Both worlds, centred, side by side or stacked: the left one is first.
    if (box.width > wholeSideBySideAspect * box.height) {
      final scale = min(box.width / (2 * world.width), box.height / world.height);
      final left = Offset((box.width - 2 * world.width * scale) / 2, (box.height - world.height * scale) / 2);
      return (scale: scale, origin: side == PuzzleSide.left ? left : left + Offset(world.width * scale, 0));
    }
    final scale = min(box.width / world.width, box.height / (2 * world.height));
    final left = Offset((box.width - world.width * scale) / 2, (box.height - 2 * world.height * scale) / 2);
    return (scale: scale, origin: side == PuzzleSide.left ? left : left + Offset(0, world.height * scale));
  }

  /// The one world of a one-board round, filling [box] (m13 s18, device test
  /// 3): centred across, its tray row's top at the top bar's band
  /// ([hudTopFraction]), at the largest scale that keeps the board
  /// [mirrorGapPx] above every pad in [pads] its width reaches and leaves the
  /// clock area a place beside or under the world. The world's empty margin
  /// may reach past the band or a pad's air, as nothing is drawn there.
  static ({double scale, Offset origin}) _oneBoard(SplitLayout layout, Size box, List<Rect> pads) {
    final world = layout.left.size;
    final board = layout.left.board;
    final tray = layout.left.tray.top;
    final unit = hudUnit(box);
    final band = unit * hudTopFraction;
    final body = world.height - tray;
    // The clock area beside the world in its narrowest form, or under it in
    // its one-line form: the world leaves one of the two its room.
    final beside = (box.width - 2 * (hudMarginPx + hudWorldGapPx + unit * _shortFormWidth + _floorSlack)) / world.width;
    final under = (box.height - band - hudWorldGapPx - unit * hudOneLineHeight) / body;
    var scale = min(min(box.width / world.width, (box.height - band) / body), max(beside, under));
    // The board is wider, in the box's px, at a bigger scale: the pads are
    // checked at the scale reached, then at the one they leave.
    for (var k = 0; k < 2; k++) {
      final left = (box.width - world.width * scale) / 2;
      for (final pad in pads) {
        final air = pad.inflate(mirrorGapPx);
        if (air.right <= left + board.left * scale || air.left >= left + board.right * scale) continue;
        scale = min(scale, (air.top - band) / (board.bottom - tray));
      }
    }
    return (scale: scale, origin: Offset((box.width - world.width * scale) / 2, band - tray * scale));
  }

  /// The box's shorter side, in px: what every HUD size is a fraction of
  /// (m12-phone-layout §0.7c, device test 3). A portrait tablet's is its
  /// width's, not its height's.
  static double hudUnit(Size box) => min(box.width, box.height);

  /// Where a phone's clock area starts, as a fraction of the box's shorter
  /// side ([hudUnit]) (§0.7c): 0.14 of a 393 px phone is 55 px, just below the
  /// 52 px top bar the app draws over the game.
  static const hudTopFraction = 0.14;

  /// The clock's text height and the score's (§0.7c).
  static const hudClockFraction = 0.08;
  static const hudScoreFraction = 0.04;

  /// The gap between the clock area's lines and above its bar: half the
  /// score's height, so the lines read apart at any size.
  static const hudLineGapFraction = 0.02;

  /// The time bar's thickness: 4.7 px on a 393 px phone, as thin as the
  /// clock's stroke.
  static const hudBarFraction = 0.012;

  /// The clock area's height in its one-line form (clock, gap, bar) and in its
  /// two-line form (clock, gap, score, gap, bar).
  static const hudOneLineHeight = hudClockFraction + hudLineGapFraction + hudBarFraction;
  static const hudTwoLineHeight = hudClockFraction + 2 * hudLineGapFraction + hudScoreFraction + hudBarFraction;

  /// A character's width as a fraction of its text height: the widest the
  /// look's Fredoka 600 draws any of the HUD's texts (measured in
  /// `text_measure_test.dart`).
  static const glyphEm = 0.55;

  /// The characters the clock is measured for: "10:00", a 10 minute limit, so
  /// the clock area never changes form as the clock counts down.
  static const _clockChars = 5;

  /// The width of the clock area's narrowest form, the room the world must
  /// leave beside it: its clock is the widest line in the form (m13 s18).
  static const _shortFormWidth = _clockChars * glyphEm * hudClockFraction;

  /// The width [text] takes at [hudScoreFraction], as a fraction of the box's
  /// shorter side.
  static double _textWidth(String text) => text.length * glyphEm * hudScoreFraction;

  /// The width and the height [form] needs for [text] (§0.7c): one line puts
  /// the score beside the clock, two lines under it, the short form a line
  /// each.
  static ({double width, double height}) _hudSize(HudForm form, ({String score, List<String> short}) text) {
    final clock = _clockChars * glyphEm * hudClockFraction;
    final lines = form == HudForm.oneLine || form == HudForm.twoLines ? [text.score] : text.short;
    final widest = [clock, ...lines.map(_textWidth)].reduce(max);
    final width = form == HudForm.oneLine ? clock + hudLineGapFraction + _textWidth(text.score) : widest;
    final gap = hudLineGapFraction + hudScoreFraction;
    final height = form == HudForm.oneLine ? hudOneLineHeight : hudTwoLineHeight + (lines.length - 1) * gap;
    return (width: width, height: height);
  }

  /// The distance from the box's left edge to the clock area, and from the
  /// clock area to the world, in px: enough to keep the texts clear of the
  /// screen's rounded corner and of the board.
  static const hudMarginPx = 8.0;
  static const hudWorldGapPx = 8.0;

  /// The air between the other side's mirror and what it must not meet — the
  /// clock area, their board, the tray row, this player's pad — in px
  /// (m12-opponent-mirror rules 5 and 8).
  static const mirrorGapPx = 8.0;

  /// The slack on a fit, so floating point may not put a fit a hair under.
  static const _floorSlack = 1e-9;

  /// The distance from the board's top-left corner to the clock area on the
  /// panel it draws there (§0.7c's last resort), in px.
  static const hudCornerMarginPx = 8.0;

  /// The mirror's size against the board's drawn size (m12-opponent-mirror
  /// rules 1 and 5): a quarter of a board at the size check's floor draws its
  /// smallest piece at 2.13 mm, under the 2.2 mm that reads, so it draws at
  /// [mirrorMinPieceMm] over [minPieceMm] — 0.26 of the board.
  static const mirrorFraction = mirrorMinPieceMm / minPieceMm;

  /// Where the other side's mirror goes in [box] and where the clock area goes
  /// with it, or null where a phone draws none (m12-opponent-mirror rules
  /// 1–8): a one-board match ([split] false), the whole match (a tablet), the
  /// screen (the TV), and a box where neither place is both clear of this
  /// player's pad and big enough to read.
  ///
  /// Rule 8's two places, in order. The corner: [hudMarginPx] from the box's
  /// left and [hudTopFraction] of its height down, with the clock area to its
  /// right in its short form (rule 5). The gap: under the clock area, between
  /// the left hand's controls and their board (rule 8's sketch). In each the
  /// mirror takes the largest scale that fits — up to [mirrorFraction] of the
  /// board's drawn size — and keeps it only if its smallest piece still draws
  /// at [mirrorMinPieceMm], which [pxPerMm] turns into px. [puzzle] is their
  /// picture; [text] the HUD the phone draws without a mirror; [padRects] the
  /// controls the app draws under the game, passed through the view.
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
    // A dot draws at that size or bigger ([mirrorDotRadius]), so the smallest
    // piece is the smallest mark and sets the floor.
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
    final at = Offset(hudMarginPx, unit * hudTopFraction);
    final corner = _fitting(box, board.size, at, maxScale, floor, [...boardAndTray, besideHud]);
    if (corner != null) {
      final rect = Rect.fromLTWH(at.dx, at.dy, board.width * corner, board.height * corner);
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

  /// Where the clock area goes in [box] and which form it takes
  /// (m12-phone-layout §0.7c, device test 3): beside the world, at
  /// [hudTopFraction] of the box's shorter side, in the first of [HudForm]'s
  /// forms the spare width fits — one line, two lines, then [HudForm.short] —
  /// then under the world in the first form that fits its width, and
  /// otherwise over the board's top-left corner on a panel the painter draws.
  /// [text] is what the HUD may draw, so the real score picks the form.
  ///
  /// With a [mirror] to its left the area starts at the mirror's right edge
  /// and draws the short form (rule 5). [padRects] are the controls the app
  /// draws under the game: the area keeps clear of them like the mirror does.
  /// [split] says whether the match has two sides, which decides the world the
  /// area goes under and the one the camera draws.
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
    final world = place(layout, camera, box, PuzzleSide.left, split: split, padRects: padRects);
    // The area starts right of the mirror when there is one, and right of the
    // world's left edge (rule 5).
    final left = mirror == null ? hudMarginPx : mirror.right + mirrorGapPx;
    final spare = world.origin.dx - hudWorldGapPx - left;
    final top = unit * hudTopFraction;
    final forms = mirror == null ? const [HudForm.oneLine, HudForm.twoLines, HudForm.short] : const [HudForm.short];
    for (final form in forms) {
      final size = _hudSize(form, text);
      final width = unit * size.width;
      if (spare < width) continue;
      return (rect: Rect.fromLTWH(left, top, width, unit * size.height), form: form);
    }
    if (mirror == null) {
      // Under the world is the last place before the corner: the world drawn
      // last, a side camera's only world or the lower one of a whole match.
      final side = camera.side ?? (split ? PuzzleSide.right : PuzzleSide.left);
      final under = place(layout, camera, box, side, split: split, padRects: padRects);
      final fits = _hudUnder(box, text, (
        left: under.origin.dx,
        top: under.origin.dy + layout.left.size.height * under.scale + hudWorldGapPx,
        room: layout.left.size.width * under.scale,
      ), padRects);
      if (fits != null) return fits;
    }
    final board = Rect.fromLTWH(
      world.origin.dx + layout.left.board.left * world.scale,
      world.origin.dy + layout.left.board.top * world.scale,
      layout.left.board.width * world.scale,
      layout.left.board.height * world.scale,
    );
    final size = _hudSize(HudForm.corner, text);
    final width = min(unit * size.width, board.width - 2 * hudCornerMarginPx);
    final at = board.topLeft + const Offset(hudCornerMarginPx, hudCornerMarginPx);
    return (rect: at & Size(width, unit * size.height), form: HudForm.corner);
  }

  @override
  bool operator ==(Object other) => other is PuzzleCamera && other.side == side;

  @override
  int get hashCode => side.hashCode;
}

/// The form a phone's clock area takes (m12-phone-layout §0.7c), narrowest
/// first: one line when the box's spare width fits the clock beside the whole
/// score, two lines when it fits the score under the clock, [short] when it
/// fits only the score's short lines ("You 2/4", "Right 3/6"), and over the
/// board's corner when it fits none of them.
enum HudForm { oneLine, twoLines, short, corner }
