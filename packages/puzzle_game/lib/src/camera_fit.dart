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

/// The clock area under the world in [box] at [under], in the first of
/// [HudForm]'s forms that fits its width, or null where none does (device
/// test 3). It starts right of a pad whose band it meets, and keeps
/// [PuzzleCamera.mirrorGapPx] of air from every one of [padRects].
({Rect rect, HudForm form})? _hudUnder(
  Size box,
  ({String score, List<String> short}) text,
  ({double left, double top, double room}) under,
  List<Rect> padRects,
) {
  final unit = PuzzleCamera.hudUnit(box);
  for (final form in const [HudForm.oneLine, HudForm.twoLines, HudForm.short]) {
    final size = PuzzleCamera._hudSize(form, text);
    final width = unit * size.width;
    var left = under.left;
    for (final pad in padRects) {
      final air = pad.inflate(PuzzleCamera.mirrorGapPx);
      final inBand = air.top < under.top + unit * size.height && air.bottom > under.top;
      if (inBand && air.right > left && air.left < left + width) left = air.right;
    }
    final rect = Rect.fromLTWH(left, under.top, width, unit * size.height);
    final inside = rect.left >= 0 && rect.top >= 0 && rect.right <= box.width && rect.bottom <= box.height;
    final clear = padRects.every((pad) => !pad.inflate(PuzzleCamera.mirrorGapPx).overlaps(rect));
    if (!inside || !clear || rect.right > under.left + under.room + PuzzleCamera._floorSlack) continue;
    return (rect: rect, form: form);
  }
  return null;
}
