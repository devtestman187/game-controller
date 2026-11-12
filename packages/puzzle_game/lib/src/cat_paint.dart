part of 'view.dart';

/// The cat's colour (design mockup, frame 3): the look's wall, the violet it
/// owns in both palettes, so the cat reads as the same visitor in Sunny and in
/// Night (a look has no cat colour of its own yet). Its ink edge and its
/// shadow are the look's too.
Color _catColour(ToyLook look) => look.colors.wall;

/// The shadow the cat casts on the piece it is after, in world units, how much
/// of the ink it keeps, and how far its ears and tail reach, as shares of the
/// patch it darkens (design mockup: `catShadow`).
const _catShadowWidth = 6.0;
const _catShadowHeight = 3.0;
const _catShadowAlpha = 0.3;
const _catEarShare = 0.26;
const _catTailShare = 0.55;

/// The cat drawn over the board it visits (PRD v2 G3, M14 a2 and bug c1): the
/// shadow on the exact piece it is after while it warns and walks, the head
/// peeking in over the board area's top edge above that piece, and the paw
/// reaching out of it and swatting, with the swat's burst where it lands.
///
/// [share] is how far through its state the cat is ([CatMoments]), so the head
/// slides in and out and the paw stretches; with the effects off it comes and
/// swats without the stretch (G5): the head is drawn at rest, no paw, no burst,
/// and nothing at all as it leaves.
void paintCat(
  Canvas canvas,
  CatView cat, {
  required PuzzleSnapshot board,
  required PuzzleField field,
  required ToyLook look,
  required ToyShapeStyle style,
  double share = 1,
}) {
  final target = cat.target;
  final piece = target != null && target < board.pieces.length ? board.pieces[target] : null;
  if (piece != null && (cat.state == CatState.warning || cat.state == CatState.walk)) {
    _catShadow(canvas, Offset(piece.x, piece.y), look.colors.ink);
  }
  if (!look.effects && cat.state == CatState.leave) return;
  final pose = CatPose.of(cat, board: board, field: field, share: look.effects ? share : 1);
  if (look.effects) paintCatPaw(canvas, pose, look, style);
  // The head stays in the board area — the part still above its top edge, as
  // the cat slides in, is not seen there — while the paw reaches past it, to a
  // piece still in the tray.
  canvas
    ..save()
    ..clipRect(field.board);
  paintCatHead(canvas, pose, look, style);
  canvas.restore();
  if (look.effects) {
    if (pose.swat case final swat?) paintCatSwat(canvas, pose.aim, swat, pose.head.width, look.colors);
  }
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
