import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Radius, RRect, Rect, StrokeCap, StrokeJoin;

import 'toy_character.dart';
import 'toy_colors.dart';
import 'toy_look.dart';

/// How far above a body's top edge the tallest accessory draws — the cap's
/// arch — in body radii. A row that holds a badge leaves this much room above
/// it ([toyAccessoryHeadroom]), so the accessory is never clipped by the card
/// round it (M13 design 5b).
const toyAccessoryReachShare = 0.9;

/// The room a badge [diameter] across needs above it for its accessory, in the
/// same pixels: the badge's radius times [toyAccessoryReachShare].
double toyAccessoryHeadroom(double diameter) => diameter / 2 * toyAccessoryReachShare;

/// The ears: where their middles sit from the body's middle and their own
/// radius, in body radii (design 5b: two round ears at ±0.6 radii, half in the
/// body). They are drawn high enough to leave the eyes clear.
const earOffsetShare = Offset(0.7, -0.9);
const earShare = 0.34;

/// The antenna: where its stalk starts and ends on the body's crown, how thick
/// the stalk is, and the paper ball's radius and rise, in body radii (design
/// 5b: a stalk 0.6 radii tall with a paper ball).
const antennaFootShare = -0.95;
const antennaTopShare = -1.55;
const antennaStalkShare = 0.1;
const antennaBallShare = 0.18;
const antennaBallRiseShare = -1.62;

/// The bow's knot on the body, in body radii, the two loops' points either side
/// of it, and the knot's paper circle (design 5b: a paper bow at the top-right).
const bowKnotShare = Offset(0.55, -1.0);
const bowLoops = [
  [Offset(0.55, -1.0), Offset(0.1, -1.25), Offset(0.25, -0.8)],
  [Offset(0.55, -1.0), Offset(1.0, -1.2), Offset(1.05, -0.78)],
];
const bowKnotDotShare = 0.1;

/// The cap's dome: where it meets the head either side, the height its top
/// arches to, and the brim's box and corner, in body radii (design 5b: a paper
/// cap on top with a brim to the front).
const capSideShare = 0.85;
const capRiseShare = -0.55;
const capArchShare = -1.9;
const capBrimShare = Rect.fromLTRB(0.52, -0.78, 1.28, -0.56);
const capBrimCornerShare = 0.1;

/// The tuft's three strokes: each runs from the head to its tip through a bend,
/// in body radii, at this thickness (design 5b: three ink hair strokes).
const tuftStrokes = [
  (from: Offset(-0.45, -0.9), bend: Offset(-0.62, -1.16), to: Offset(-0.7, -1.3)),
  (from: Offset(-0.05, -0.98), bend: Offset(-0.08, -1.25), to: Offset(0.02, -1.42)),
  (from: Offset(0.35, -0.93), bend: Offset(0.42, -1.2), to: Offset(0.6, -1.28)),
];
const tuftShare = 0.1;

/// The crown's outline, round from its left point: its points rise 0.38 radii
/// above the body's top and its valleys sit between them (design 5b: a small
/// paper crown with three points).
const crownPoints = [
  Offset(-0.55, -0.88),
  Offset(-0.55, -1.28),
  Offset(-0.28, -1.05),
  Offset(0, -1.38),
  Offset(0.28, -1.05),
  Offset(0.55, -1.28),
  Offset(0.55, -0.88),
];

/// The body an accessory is drawn on: its middle, its radius and its colour, in
/// the canvas's own units.
typedef _Body = ({Offset centre, double radius, Color colour});

/// Draws [accessory] on top of a character's body (M13 design 5b): a few simple
/// shapes with the look's ink edge, above the body's middle and never over its
/// face, so each reads at a phone's size and tells the players apart without
/// colour.
///
/// Ink, paper and the body's own colour only ([bodyColour], for the ears), so
/// any accessory suits any of the six colours — and any added later — in both
/// palettes. The ink edge is the look's outline in pixels: [canvas]'s whole
/// scale is taken out of it, as a game's painter divides its own outline by the
/// board's scale, so the edge is the look's width on screen in a scaled canvas.
///
/// [tiltDeg] turns the whole accessory about the body's middle, for the flop
/// that follows a walking worker's bob a little late (design 5a): every
/// accessory takes it, and a crown simply tilts.
void paintAccessory(
  Canvas canvas,
  ToyAccessory accessory,
  Offset bodyCentre,
  double bodyRadius,
  Color bodyColour,
  ToyLook look, {
  double tiltDeg = 0,
}) {
  final colours = look.colors;
  final edge = look.sizes.outlineWidth / _pxPerUnit(canvas);
  final body = (centre: bodyCentre, radius: bodyRadius, colour: bodyColour);
  if (tiltDeg != 0) {
    canvas
      ..save()
      ..translate(bodyCentre.dx, bodyCentre.dy)
      ..rotate(tiltDeg * math.pi / 180)
      ..translate(-bodyCentre.dx, -bodyCentre.dy);
  }
  switch (accessory) {
    case ToyAccessory.ears:
      _ears(canvas, body, colours, edge);
    case ToyAccessory.antenna:
      _antenna(canvas, body, colours, edge);
    case ToyAccessory.bow:
      _bow(canvas, body, colours, edge);
    case ToyAccessory.cap:
      _cap(canvas, body, colours, edge);
    case ToyAccessory.tuft:
      _tuft(canvas, body, colours, edge);
    case ToyAccessory.crown:
      _crown(canvas, body, colours, edge);
  }
  if (tiltDeg != 0) canvas.restore();
}

/// The two round ears, in the body's own colour with the ink edge on the half
/// that stands out of the body, so they grow out of its crown.
void _ears(Canvas canvas, _Body body, ToyColors colours, double edge) {
  final radius = body.radius * earShare;
  final ink = _stroke(edge, colours.ink);
  for (final side in const [-1, 1]) {
    final centre = body.centre + Offset(side * earOffsetShare.dx, earOffsetShare.dy) * body.radius;
    canvas.drawCircle(centre, radius, Paint()..color = body.colour);
    // Only the outer half is inked: the inner half lies on the body, whose own
    // edge stays as it is.
    final out = math.atan2(centre.dy - body.centre.dy, centre.dx - body.centre.dx);
    canvas.drawArc(Rect.fromCircle(center: centre, radius: radius), out - math.pi / 2, math.pi, false, ink);
  }
}

/// The ink stalk with its paper ball, standing on the body's crown.
void _antenna(Canvas canvas, _Body body, ToyColors colours, double edge) {
  final r = body.radius;
  final foot = body.centre + Offset(0, antennaFootShare * r);
  final top = body.centre + Offset(0, antennaTopShare * r);
  canvas.drawLine(foot, top, _stroke(r * antennaStalkShare, colours.ink));
  final ball = body.centre + Offset(0, antennaBallRiseShare * r);
  final radius = r * antennaBallShare;
  canvas
    ..drawCircle(ball, radius, Paint()..color = colours.paper)
    ..drawCircle(ball, radius, _stroke(edge, colours.ink));
}

/// The two paper loops and their knot, tied at the body's top-right.
void _bow(Canvas canvas, _Body body, ToyColors colours, double edge) {
  final r = body.radius;
  for (final loop in bowLoops) {
    final path = _through([for (final point in loop) body.centre + point * r]);
    canvas
      ..drawPath(path, Paint()..color = colours.paper)
      ..drawPath(path, _stroke(edge, colours.ink));
  }
  final knot = body.centre + bowKnotShare * r;
  canvas
    ..drawCircle(knot, r * bowKnotDotShare, Paint()..color = colours.paper)
    ..drawCircle(knot, r * bowKnotDotShare, _stroke(edge, colours.ink));
}

/// The paper cap on the body's crown, with its brim reaching out to the front
/// (to the right, where the character looks).
void _cap(Canvas canvas, _Body body, ToyColors colours, double edge) {
  final r = body.radius;
  final c = body.centre;
  final dome = Path()
    ..moveTo(c.dx - capSideShare * r, c.dy + capRiseShare * r)
    ..quadraticBezierTo(c.dx, c.dy + capArchShare * r, c.dx + capSideShare * r, c.dy + capRiseShare * r)
    ..close();
  final brimBox = Rect.fromPoints(c + capBrimShare.topLeft * r, c + capBrimShare.bottomRight * r);
  final brim = Path()..addRRect(RRect.fromRectAndRadius(brimBox, Radius.circular(r * capBrimCornerShare)));
  for (final part in [dome, brim]) {
    canvas
      ..drawPath(part, Paint()..color = colours.paper)
      ..drawPath(part, _stroke(edge, colours.ink));
  }
}

/// The three ink hair strokes standing on the body's crown.
void _tuft(Canvas canvas, _Body body, ToyColors colours, double edge) {
  final r = body.radius;
  final ink = _stroke(r * tuftShare, colours.ink);
  for (final stroke in tuftStrokes) {
    final from = body.centre + stroke.from * r;
    final bend = body.centre + stroke.bend * r;
    final to = body.centre + stroke.to * r;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy);
    canvas.drawPath(path, ink);
  }
}

/// The small paper crown with three points, round the body's crown.
void _crown(Canvas canvas, _Body body, ToyColors colours, double edge) {
  final path = _through([for (final point in crownPoints) body.centre + point * body.radius]);
  canvas
    ..drawPath(path, Paint()..color = colours.paper)
    ..drawPath(path, _stroke(edge, colours.ink));
}

/// The closed polyline through [points], for a bow's loop and a crown's outline.
Path _through(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

/// How many pixels one of [canvas]'s own units is on screen: its whole
/// transform's scale, whatever scaled it before this call (a game's painters
/// divide the look's pixel sizes by the same number).
double _pxPerUnit(Canvas canvas) {
  final m = canvas.getTransform();
  return math.sqrt(m[0] * m[0] + m[1] * m[1]);
}

/// A stroke of [width] in [colour], its ends and corners round.
Paint _stroke(double width, Color colour) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width
  ..color = colour;
