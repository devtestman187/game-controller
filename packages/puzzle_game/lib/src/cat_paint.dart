part of 'view.dart';

/// The cat's colour (design mockup, frame 3): the look's wall, the violet it
/// owns in both palettes, so the cat reads as the same visitor in Sunny and in
/// Night (a look has no cat colour of its own yet). Its ink edge and its
/// shadow are the look's too.
Color _catColour(ToyLook look) => look.colors.wall;

/// The cat's sizes in world units: the paw it leaves at the side's edge, the
/// shadow it casts on the piece it wants, and the face it walks in with.
const _catPawSize = 6.5;
const _catShadowWidth = 6.0;
const _catShadowHeight = 3.0;
const _catFaceSize = 8.0;

/// How much of the ink a shadow keeps, and how far its ears and tail reach, as
/// shares of the patch it darkens (design mockup: `catShadow`).
const _catShadowAlpha = 0.3;
const _catEarShare = 0.26;
const _catTailShare = 0.55;

/// How thick a face's smile is, as a share of the face's size.
const _catSmileShare = 0.05;

/// The cat drawn over the board it visits (PRD v2 G3, M14 a2): the paw at the
/// side's edge while it warns, the shadow on the exact piece it is after, the
/// face as it walks, bats and runs off. With the effects off the walk is not
/// drawn — the cat appears at the piece and goes from there (G5) — and
/// nothing flashes at any time.
void paintCat(
  Canvas canvas,
  CatView cat, {
  required PuzzleSnapshot board,
  required ToyLook look,
  required ToyShapeStyle style,
}) {
  final target = cat.target;
  final piece = target != null && target < board.pieces.length ? board.pieces[target] : null;
  if (piece != null && (cat.state == CatState.warning || cat.state == CatState.walk)) {
    _catShadow(canvas, Offset(piece.x, piece.y), look.colors.ink);
  }
  switch (cat.state) {
    case CatState.warning:
      _catPaw(canvas, cat.at, look, style);
    case CatState.walk:
      // With the effects off it is already at the piece: it appears there and
      // goes from there (G5).
      _catFace(canvas, look.effects || piece == null ? cat.at : Offset(piece.x, piece.y), look, style);
    case CatState.bat:
      _catFace(canvas, cat.at, look, style);
    case CatState.leave:
      if (look.effects) _catFace(canvas, cat.at, look, style);
  }
}

/// The paw at the side's edge: four toes over a pad, in the cat's colour with
/// the look's ink edge (design mockup, `paw`).
void _catPaw(Canvas canvas, Offset at, ToyLook look, ToyShapeStyle style) {
  const size = _catPawSize;
  final path = Path();
  for (final (dx, dy, r) in const [
    (-0.30, -0.20, 0.13),
    (-0.10, -0.32, 0.14),
    (0.12, -0.32, 0.14),
    (0.32, -0.16, 0.12),
  ]) {
    path.addOval(Rect.fromCircle(center: at + Offset(dx * size, dy * size), radius: r * size));
  }
  path.addOval(Rect.fromCenter(center: at + Offset(0, 0.14 * size), width: 0.58 * size, height: 0.52 * size));
  toyShape(canvas, path, _catColour(look), style, shade: look.shade);
}

/// The cat's face: a round head with two ears, in the cat's colour, and its
/// eyes and smile in the ink, so it reads without a colour (design mockup,
/// `catFace`).
void _catFace(Canvas canvas, Offset at, ToyLook look, ToyShapeStyle style) {
  const size = _catFaceSize;
  final head = Offset(0, 0.06 * size);
  final path = Path()
    ..addOval(Rect.fromCenter(center: at + head, width: 0.84 * size, height: 0.78 * size))
    ..addPolygon([
      at + Offset(-0.40 * size, -0.14 * size),
      at + Offset(-0.34 * size, -0.54 * size),
      at + Offset(-0.04 * size, -0.26 * size),
    ], true)
    ..addPolygon([
      at + Offset(0.40 * size, -0.14 * size),
      at + Offset(0.34 * size, -0.54 * size),
      at + Offset(0.04 * size, -0.26 * size),
    ], true);
  toyShape(canvas, path, _catColour(look), style, shade: look.shade);
  final ink = look.colors.ink;
  final eye = 0.08 * size;
  canvas
    ..drawCircle(at + Offset(-0.17 * size, -0.02 * size), eye, Paint()..color = ink)
    ..drawCircle(at + Offset(0.17 * size, -0.02 * size), eye, Paint()..color = ink);
  final smile = Path()
    ..moveTo(at.dx - 0.13 * size, at.dy + 0.17 * size)
    ..quadraticBezierTo(at.dx, at.dy + 0.30 * size, at.dx + 0.13 * size, at.dy + 0.17 * size);
  canvas.drawPath(
    smile,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _catSmileShare * size
      ..strokeCap = StrokeCap.round
      ..color = ink,
  );
}

/// The cat's shadow on the piece it wants: a patch with its ears and a curled
/// tail, in the ink at [_catShadowAlpha], so the exact piece reads as marked
/// without covering it (design mockup, `catShadow`).
void _catShadow(Canvas canvas, Offset at, Color ink) {
  final paint = Paint()..color = ink.withValues(alpha: _catShadowAlpha);
  const w = _catShadowWidth;
  const h = _catShadowHeight;
  final patch = Rect.fromCenter(center: at, width: w, height: h);
  canvas
    ..drawOval(patch, paint)
    ..drawPath(
      Path()
        ..addPolygon([
          at + Offset(-w * _catEarShare, -h * 0.3),
          at + Offset(-w * _catEarShare * 0.4, -h * 0.9),
          at + Offset(w * 0.05, -h * 0.3),
        ], true)
        ..addPolygon([
          at + Offset(w * _catEarShare * 0.4, -h * 0.3),
          at + Offset(w * _catEarShare, -h * 0.8),
          at + Offset(w * 0.1, -h * 0.3),
        ], true),
      paint,
    )
    ..drawPath(
      Path()
        ..moveTo(at.dx + w * 0.4, at.dy + h * 0.1)
        ..quadraticBezierTo(at.dx + w * _catTailShare, at.dy - h * 0.2, at.dx + w * 0.5, at.dy - h * 0.7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.3
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: _catShadowAlpha),
    );
}
