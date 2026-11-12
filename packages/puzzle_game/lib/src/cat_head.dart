part of 'view.dart';

/// The head's parts as shares of its box: the face's width, height and how far
/// down it sits (the ears take the height above it), and where the ears' three
/// points are.
const _faceWidth = 0.90;
const _faceHeight = 0.78;
const _faceDown = 0.08;
const _earOuter = (-0.44, 0.02);
const _earTip = (-0.36, -0.46);
const _earInner = (-0.06, -0.16);

/// The eyes' places and size, as shares of the head's box, and how big a pupil
/// is against its eye.
const _eyeAt = (-0.19, -0.03);
const _eyeRadiusShare = 0.10;
const _catPupilShare = 0.5;

/// The nose: its width and how far down its point sits, as shares of the box.
const _noseWidthShare = 0.10;
const _noseDown = 0.17;
const _nosePointDown = 0.25;

/// The cat's head peeking in over the board area's top edge (M14 bug c1): a
/// round head with two ears in the cat's colour, outlined in the pieces' ink,
/// with its eyes and nose in the ink and its pupils turned toward the piece
/// [pose] aims at, so the eyes follow it (the owner asked for ears, eyes and a
/// nose). The caller has clipped the board area, so the part still above its
/// top edge as the cat slides in is not seen.
void paintCatHead(Canvas canvas, CatPose pose, ToyLook look, ToyShapeStyle style) {
  final head = pose.head;
  final w = head.width;
  final h = head.height;
  final at = head.center;

  // An ear's point, [mirror] -1 for the right one, from its shares of the box.
  Offset ear((double, double) point, double mirror) => at + Offset(point.$1 * w * mirror, point.$2 * h);
  final path = Path()
    ..addOval(Rect.fromCenter(center: at + Offset(0, _faceDown * h), width: _faceWidth * w, height: _faceHeight * h));
  for (final mirror in const [-1.0, 1.0]) {
    path.addPolygon([ear(_earOuter, mirror), ear(_earTip, mirror), ear(_earInner, mirror)], true);
  }
  toyShape(canvas, path, _catColour(look), style, shade: look.shade);
  final ink = Paint()..color = look.colors.ink;
  for (final side in const [-1.0, 1.0]) {
    final eye = at + Offset(side * _eyeAt.$1 * w, _eyeAt.$2 * h);
    canvas
      ..drawCircle(eye, _eyeRadiusShare * w, Paint()..color = look.colors.paper)
      ..drawCircle(eye + pose.gaze, _eyeRadiusShare * _catPupilShare * w, ink);
  }
  canvas.drawPath(
    Path()..addPolygon([
      at + Offset(-_noseWidthShare / 2 * w, _noseDown * h),
      at + Offset(_noseWidthShare / 2 * w, _noseDown * h),
      at + Offset(0, _nosePointDown * h),
    ], true),
    ink,
  );
}
