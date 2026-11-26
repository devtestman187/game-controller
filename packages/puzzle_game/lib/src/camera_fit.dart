part of 'camera.dart';

/// The largest scale, up to [maxScale], at which [board]'s shape with its top
/// left at [at] fits [box] and meets none of [obstacles] — each with
/// [PuzzleCamera.mirrorGapPx] of air round it — or null when that is under
/// [floor], the scale below which the mirror's smallest piece stops reading.
double? _fitting(Size box, Size board, Offset at, double maxScale, double floor, List<Rect> obstacles) {
  var scale = min(maxScale, min((box.width - at.dx) / board.width, (box.height - at.dy) / board.height));
  for (final obstacle in obstacles) {
    final r = obstacle.inflate(PuzzleCamera.mirrorGapPx);
    // A rect wholly up or left of the place can't be met however big the
    // mirror gets.
    if (r.right <= at.dx || r.bottom <= at.dy) continue;
    scale = min(scale, max((r.left - at.dx) / board.width, (r.top - at.dy) / board.height));
  }
  return scale + PuzzleCamera._floorSlack >= floor ? scale : null;
}

/// Whether [rect] meets any of [controls] with [PuzzleCamera.mirrorGapPx] of
/// air round each (B-044).
bool _meetsControls(Rect rect, List<Rect> controls) =>
    controls.any((control) => control.inflate(PuzzleCamera.mirrorGapPx).overlaps(rect));

/// The clock area under the world in [box] at [under], in the first of
/// [HudForm]'s forms that fits its width, or null where none does (device
/// test 3). It starts right of a control whose band it meets, and keeps
/// [PuzzleCamera.mirrorGapPx] of air from every one of [controls]: the pad's
/// controls and the right hand's (B-044).
({Rect rect, HudForm form})? _hudUnder(
  Size box,
  ({String score, List<String> short}) text,
  ({double left, double top, double room}) under,
  List<Rect> controls,
) {
  final unit = PuzzleCamera.hudUnit(box);
  for (final form in const [HudForm.oneLine, HudForm.twoLines, HudForm.short]) {
    final size = PuzzleCamera._hudSize(form, text);
    final width = unit * size.width;
    var left = under.left;
    for (final control in controls) {
      final air = control.inflate(PuzzleCamera.mirrorGapPx);
      final inBand = air.top < under.top + unit * size.height && air.bottom > under.top;
      if (inBand && air.right > left && air.left < left + width) left = air.right;
    }
    final rect = Rect.fromLTWH(left, under.top, width, unit * size.height);
    final inside = rect.left >= 0 && rect.top >= 0 && rect.right <= box.width && rect.bottom <= box.height;
    final clear = !_meetsControls(rect, controls);
    if (!inside || !clear || rect.right > under.left + under.room + PuzzleCamera._floorSlack) continue;
    return (rect: rect, form: form);
  }
  return null;
}

/// The mirror's rect at scale [s]: [board]'s shape, [PuzzleCamera.mirrorGapPx]
/// from the box's top and right edges.
Rect _stripRect(Size box, Size board, double s) => Rect.fromLTWH(
  box.width - PuzzleCamera.mirrorGapPx - board.width * s,
  PuzzleCamera.mirrorGapPx,
  board.width * s,
  board.height * s,
);

/// The largest scale, up to [maxScale], at which the top-right strip's mirror
/// is inside [box], keeps [PuzzleCamera.mirrorGapPx] from every one of
/// [obstacles] and from every round control in [hudRects] (the square ones: the
/// face buttons and the right stick; a floating stick's zone is no circle and
/// takes no look from the mirror), or null when that is under [floor]. Null too
/// where [hudRects] holds no circle: there is no ring whose corner to take.
double? _stripFitting(Size box, Size board, double maxScale, double floor, List<Rect> obstacles, List<Rect> hudRects) {
  final circles = [
    for (final r in hudRects)
      if ((r.width - r.height).abs() < 1e-6) r,
  ];
  if (circles.isEmpty || floor > maxScale) return null;
  bool clear(double s) {
    final rect = _stripRect(box, board, s);
    if (rect.left < 0 || rect.bottom > box.height + PuzzleCamera._floorSlack) return false;
    if (obstacles.any((o) => o.inflate(PuzzleCamera.mirrorGapPx).overlaps(rect))) return false;
    for (final c in circles) {
      final nearest = Offset(
        max(rect.left, min(c.center.dx, rect.right)),
        max(rect.top, min(c.center.dy, rect.bottom)),
      );
      if ((c.center - nearest).distance - c.width / 2 + PuzzleCamera._floorSlack < PuzzleCamera.mirrorGapPx) {
        return false;
      }
    }
    return true;
  }

  if (!clear(floor)) return null;
  if (clear(maxScale)) return maxScale;
  // Clear only gets harder as the mirror grows, so bisect.
  var lo = floor;
  var hi = maxScale;
  for (var i = 0; i < 30; i++) {
    final mid = (lo + hi) / 2;
    if (clear(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}
