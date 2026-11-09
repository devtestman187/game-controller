part of 'view.dart';

/// The worker's body against today's dot (design 5a: 1.3 times), as a share of
/// the dot's radius.
const _bodyShare = 1.3;

/// The smallest a worker's body is drawn across on a phone, in millimetres
/// (design 5a), so its face reads at arm's length.
const _minBodyMm = 7.0;

/// Where the body's middle sits from the point it stands on, in body radii, so
/// the ink ring of an empty-handed worker's grab point shows under its feet.
const _standShare = 1.35;

/// The ink ring at a worker's grab point, as a share of the body's radius, and
/// how thick its stroke is against the look's ink.
const _ringShare = 0.32;
const _ringInkShare = 0.75;

/// The face's shares of the body's radius: where and how big its eyes are, its
/// pupil and how far it looks, where its mouth is and how wide.
const _eyeOffsetShare = 0.34;
const _eyeRiseShare = -0.3;
const _eyeWideShare = 0.19;
const _eyeTallShare = 0.25;
const _pupilShare = 0.1;
const _pupilLookShare = 0.07;
const _mouthRiseShare = 0.12;
const _mouthWideShare = 0.2;

/// The arms' shares of the body's radius: how thick their ink edge is, how
/// thick the player's colour inside it is, how big a mitten hand is, how far it
/// is outlined in ink, and how far an arm bows out between shoulder and hand.
const _armInkShare = 0.42;
const _armColourShare = 0.22;
const _handShare = 0.2;
const _handInkShare = 0.6;
const _armBowShare = 0.22;

/// Where a shoulder sits on the body, in body radii from its middle.
const _shoulderShare = Offset(0.62, 0.34);

/// How far a mitten's colour is lightened toward the paper, so it reads as a
/// mitten on the player's colour.
const _handLighten = 0.35;

/// A sweat drop's size and where it flies, in body radii from the middle.
const _sweatShare = 0.14;
const _sweatAtShare = Offset(0.62, -0.72);

/// The worker's body radius in the painter's units: 1.3 times the dot, or, on a
/// phone that knows its [pxPerMm], as big as [_minBodyMm] across in that
/// screen's pixels, whichever is bigger.
double _workerRadius(double px, double? pxPerMm) {
  final body = PuzzleGame.dotRadius * _bodyShare;
  if (pxPerMm == null || px <= 0) return body;
  return max(body, _minBodyMm / 2 * pxPerMm / px);
}

/// Draws every player of [snapshot] as the worker (design 5a), where M12 drew a
/// dot: the pose the board's moments give it, its character's body colour and
/// accessory (design 5b) and its face. A view with no [workers] draws everyone
/// standing empty-handed.
extension _WorkerPaint on PuzzlePainter {
  void _paintWorkers(Canvas canvas, PuzzleSnapshot snapshot, double px) {
    final radius = _workerRadius(px, pxPerMm);
    for (final p in snapshot.players) {
      // The player's number becomes a character in one place (design 5b), once
      // a player a paint, and a later milestone hands a chosen character here.
      final character = ToyCharacter.forPlayer(p.number);
      final pose = workers?.poseOf(board, p.number, nowMs, effects: look.effects) ?? WorkerPose.on(Offset(p.x, p.y));
      _worker(canvas, pose, character: character, radius: radius, px: px, look: look);
    }
  }
}

/// One worker (design 5a): its noodle arms and mitten hands, its round body in
/// its character's colour with its accessory on top (design 5b), and its face —
/// leaning about the point it stands on, squashed about its middle, and moved
/// by the moment's hop or shake.
void _worker(
  Canvas canvas,
  WorkerPose pose, {
  required ToyCharacter character,
  required double radius,
  required double px,
  required ToyLook look,
}) {
  final colours = look.colors;
  final ink = look.sizes.outlineWidth / px;
  if (pose.onDot) {
    canvas.drawCircle(pose.at, radius * _ringShare, _stroke(ink * _ringInkShare, colours.ink));
  }
  final motion = pose.away * _standShare + pose.motion;
  canvas
    ..save()
    ..translate(pose.at.dx, pose.at.dy);
  if (pose.leanDeg != 0) canvas.rotate(pose.leanDeg * pi / 180);
  canvas
    ..translate(motion.dx * radius, motion.dy * radius)
    ..scale(pose.squash.x, pose.squash.y);
  final colour = character.colourIn(colours);
  _workerArms(canvas, pose.hands, radius, ink, colour, colours);
  toyShape(
    canvas,
    Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
    colour,
    ToyShapeStyle(ink: colours.ink, outlineWidth: ink, shadowOffset: ToySizes.shadowOffset / px),
    shade: look.shade,
  );
  _workerFace(canvas, pose, radius, ink, colours);
  // The accessory is drawn inside the body's own turn, squash and hop, so it
  // moves with the body (design 5b).
  paintAccessory(canvas, character.accessory, Offset.zero, radius, colour, look);
  if (pose.sweat) {
    final at = _sweatAtShare * radius;
    canvas
      ..drawCircle(at, radius * _sweatShare, Paint()..color = colours.paper)
      ..drawCircle(at, radius * _sweatShare, _stroke(ink * _ringInkShare, colours.ink));
  }
  canvas.restore();
}

/// The noodle arms from the body's shoulders to its mitten hands, and the hands
/// themselves: an ink stroke with the player's colour inside it and a mitten on
/// the end, as the design's mock-up draws them (design 5a).
void _workerArms(Canvas canvas, WorkerHands hands, double radius, double ink, Color colour, ToyColors colours) {
  final shoulders = [_shoulderShare * radius, Offset(-_shoulderShare.dx, _shoulderShare.dy) * radius];
  final mittens = [hands.left * radius, hands.right * radius];
  for (final (i, hand) in mittens.indexed) {
    final shoulder = shoulders[i];
    final bow = (shoulder + hand) / 2 + Offset(-(hand.dy - shoulder.dy), hand.dx - shoulder.dx) * _armBowShare;
    final path = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(bow.dx, bow.dy, hand.dx, hand.dy);
    canvas
      ..drawPath(path, _stroke(radius * _armInkShare, colours.ink))
      ..drawPath(path, _stroke(radius * _armColourShare, colour));
    final mitten = Color.lerp(colour, colours.paper, _handLighten)!;
    canvas
      ..drawCircle(hand, radius * _handShare, Paint()..color = mitten)
      ..drawCircle(hand, radius * _handShare, _stroke(ink * _handInkShare, colours.ink));
  }
}

/// What a worker's face is drawn from: where its eyes are, how wide and how low
/// its mouth is, the stroke width, and the look it gives (design 5a).
final class _Face {
  _Face(this.radius, this.ink, this.look, this.colours)
    : eyes = [Offset(-_eyeOffsetShare, _eyeRiseShare) * radius, Offset(_eyeOffsetShare, _eyeRiseShare) * radius],
      mouth = radius * _mouthRiseShare,
      wide = radius * _mouthWideShare;

  final double radius;
  final double ink;
  final Offset look;
  final ToyColors colours;

  /// The two eyes' middles, its left then its right.
  final List<Offset> eyes;

  /// How far the mouth sits below the body's middle, and how wide its features
  /// are.
  final double mouth;
  final double wide;
}

/// The worker's face (design 5a): eyes open with a pupil that looks where
/// [WorkerPose.look] points, screwed shut in effort, shut in a grin, or shut
/// and flat; and a mouth to match.
void _workerFace(Canvas canvas, WorkerPose pose, double radius, double ink, ToyColors colours) {
  final face = _Face(radius, ink, pose.look, colours);
  switch (pose.face) {
    case WorkerFace.smile:
      _workerSmile(canvas, face, open: true);
    case WorkerFace.blink:
      _workerSmile(canvas, face, open: false);
    case WorkerFace.effort:
      _workerEffort(canvas, face);
    case WorkerFace.call:
      _workerCall(canvas, face);
    case WorkerFace.oops:
      _workerOops(canvas, face);
    case WorkerFace.happy:
      _workerHappy(canvas, face);
  }
}

/// A soft smile, its eyes open ([open]) or shut in a blink.
void _workerSmile(Canvas canvas, _Face face, {required bool open}) {
  for (final eye in face.eyes) {
    if (open) {
      _workerEye(canvas, eye, face.radius, face.look, face.colours);
    } else {
      final shut = [Offset(eye.dx - face.wide, eye.dy), Offset(eye.dx + face.wide, eye.dy)];
      _workerLine(canvas, shut, face.ink, face.colours.ink);
    }
  }
  _workerCurve(
    canvas,
    Offset(-face.wide, face.mouth),
    Offset(0, face.mouth * 2.3),
    Offset(face.wide, face.mouth),
    face.ink,
    face.colours.ink,
  );
}

/// Eyes screwed shut and a flat mouth.
void _workerEffort(Canvas canvas, _Face face) {
  final (left, right) = (face.eyes.first, face.eyes.last);
  final w = face.wide;
  final ink = face.colours.ink;
  _workerLine(
    canvas,
    [Offset(left.dx - w, left.dy - w), Offset(left.dx + w, left.dy), Offset(left.dx - w, left.dy + w)],
    face.ink,
    ink,
  );
  _workerLine(
    canvas,
    [Offset(right.dx + w, right.dy - w), Offset(right.dx - w, right.dy), Offset(right.dx + w, right.dy + w)],
    face.ink,
    ink,
  );
  _workerLine(canvas, [Offset(-w, face.mouth), Offset(w, face.mouth)], face.ink, ink);
}

/// Eyes open and a mouth open wide, calling.
void _workerCall(Canvas canvas, _Face face) {
  for (final eye in face.eyes) {
    _workerEye(canvas, eye, face.radius, face.look, face.colours);
  }
  final mouth = Rect.fromCenter(center: Offset(0, face.mouth * 1.6), width: face.wide * 1.3, height: face.wide * 1.6);
  canvas
    ..drawOval(mouth, Paint()..color = face.colours.paper)
    ..drawOval(mouth, _stroke(face.ink * _ringInkShare, face.colours.ink));
}

/// Eyes shut in a wince, curved down, and a small flat mouth.
void _workerOops(Canvas canvas, _Face face) {
  for (final eye in face.eyes) {
    final from = Offset(eye.dx - face.wide, eye.dy);
    final to = Offset(eye.dx + face.wide, eye.dy);
    _workerCurve(canvas, from, Offset(eye.dx, eye.dy + face.wide), to, face.ink, face.colours.ink);
  }
  final brow = [Offset(-face.wide * 0.7, face.mouth * 1.5), Offset(face.wide * 0.7, face.mouth * 1.5)];
  _workerLine(canvas, brow, face.ink, face.colours.ink);
}

/// Eyes shut in a happy curve and a wide grin.
void _workerHappy(Canvas canvas, _Face face) {
  for (final eye in face.eyes) {
    final shut = [
      Offset(eye.dx - face.wide, eye.dy + face.wide),
      Offset(eye.dx, eye.dy - face.wide),
      Offset(eye.dx + face.wide, eye.dy + face.wide),
    ];
    _workerLine(canvas, shut, face.ink, face.colours.ink);
  }
  _workerCurve(
    canvas,
    Offset(-face.wide * 1.4, face.mouth * 0.5),
    Offset(0, face.mouth * 3),
    Offset(face.wide * 1.4, face.mouth * 0.5),
    face.ink,
    face.colours.ink,
  );
}

/// A worker's eye: the look's paper with an ink pupil looking [look]'s way.
void _workerEye(Canvas canvas, Offset at, double radius, Offset look, ToyColors colours) {
  final wide = radius * _eyeWideShare;
  final tall = radius * _eyeTallShare;
  final pupil = look.distance > 1 ? look / look.distance : look;
  canvas
    ..drawOval(Rect.fromCenter(center: at, width: wide * 2, height: tall * 2), Paint()..color = colours.paper)
    ..drawCircle(at + pupil * radius * _pupilLookShare, radius * _pupilShare, Paint()..color = colours.ink);
}

/// A stroke of [width] in [colour], its ends and corners round.
Paint _stroke(double width, Color colour) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width
  ..color = colour;

/// A polyline of [width] in [colour] through [points].
void _workerLine(Canvas canvas, List<Offset> points, double width, Color colour) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  canvas.drawPath(path, _stroke(width, colour));
}

/// A curve of [width] in [colour] from [from] to [to], bent through [control].
void _workerCurve(Canvas canvas, Offset from, Offset control, Offset to, double width, Color colour) {
  final path = Path()
    ..moveTo(from.dx, from.dy)
    ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
  canvas.drawPath(path, _stroke(width, colour));
}
