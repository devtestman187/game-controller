part of 'view.dart';

/// The paw's size, the foreleg's thickness and the bow the leg takes to one
/// side of its line, as shares of the head's width.
const _pawWidthShare = 0.34;
const _legWidthShare = 0.13;
const _legBowShare = 0.16;

/// The paw's pad: its width and height against the paw's size, and how far down
/// it sits under the toes.
const _padWidthShare = 0.86;
const _padHeightShare = 0.72;
const _padDownShare = 0.10;

/// The paw's toes: each one's middle and radius, as shares of the paw's size.
const _toes = [(-0.30, -0.16, 0.15), (0.02, -0.26, 0.16), (0.32, -0.16, 0.15)];

/// The swat's burst: how wide against the head's width, how thick its rays, how
/// many, and where each ray starts against the burst's width.
const _swatWidthShare = 0.55;
const _swatThicknessShare = 0.09;
const _swatRays = 6;
const _swatInnerShare = 0.45;
const _swatGrowShare = 0.5;

/// The cat's paw and foreleg (M14 bug c1): the leg comes out from under the head
/// at [CatPose.shoulder] and stretches to the tip, bowed to one side and thicker
/// at the shoulder, ending in a paw in the cat's colour with the pieces' ink
/// edge. Nothing once the tip is in ([CatView] has no paw out while it warns).
void paintCatPaw(Canvas canvas, CatPose pose, ToyLook look, ToyShapeStyle style) {
  final tip = pose.tip;
  if (tip == null) return;
  final headWidth = pose.head.width;
  final size = headWidth * _pawWidthShare;
  final towards = tip - pose.shoulder;
  final distance = towards.distance;
  if (distance > size / 2) {
    final end = tip - towards / distance * (size / 2);
    final away = Offset(-towards.dy, towards.dx) / distance;
    // The bow peaks half way out, so the leg reads as a stretch, not a stick.
    final bend = away * (headWidth * _legBowShare);
    final leg = Path()
      ..moveTo(pose.shoulder.dx, pose.shoulder.dy)
      ..quadraticBezierTo(
        (pose.shoulder.dx + end.dx) / 2 + bend.dx,
        (pose.shoulder.dy + end.dy) / 2 + bend.dy,
        end.dx,
        end.dy,
      );
    Paint stroke(double width, Color colour) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = colour;
    final legWidth = headWidth * _legWidthShare;
    canvas
      ..drawPath(leg, stroke(legWidth + 2 * style.outlineWidth, style.ink))
      ..drawPath(leg, stroke(legWidth, _catColour(look)));
  }
  _paw(canvas, tip, size, look, style);
}

/// The paw at [at], [size] across: a pad under three toes, in the cat's colour
/// with the pieces' ink edge, as the old paw was drawn (design mockup, `paw`).
void _paw(Canvas canvas, Offset at, double size, ToyLook look, ToyShapeStyle style) {
  final path = Path()
    ..addOval(
      Rect.fromCenter(
        center: at + Offset(0, _padDownShare * size),
        width: _padWidthShare * size,
        height: _padHeightShare * size,
      ),
    );
  for (final (dx, dy, r) in _toes) {
    path.addOval(Rect.fromCircle(center: at + Offset(dx * size, dy * size), radius: r * size));
  }
  toyShape(canvas, path, _catColour(look), style, shade: look.shade);
}

/// The swat's burst at [at], [share] of the way through the bat (M14 bug c1):
/// short rays thrown out from the piece, growing and fading as the paw comes off
/// it, in the look's `caution`, which reads on both palettes.
void paintCatSwat(Canvas canvas, Offset at, double share, double headWidth, ToyColors colours) {
  final width = headWidth * _swatWidthShare * (1 - _swatGrowShare * (1 - share));
  final inner = width * _swatInnerShare;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = headWidth * _swatThicknessShare * (1 - share / 2)
    ..color = colours.caution.withValues(alpha: 1 - share);
  for (var ray = 0; ray < _swatRays; ray++) {
    final turn = ray * 2 * pi / _swatRays;
    final away = Offset(cos(turn), sin(turn));
    canvas.drawLine(at + away * inner, at + away * width, paint);
  }
}
