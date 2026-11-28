import 'dart:math';
import 'dart:ui';

import 'package:toy_look/toy_look.dart';

import 'present.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';

/// The box's side, in field units: a small present on the top of the board (M17 r3a).
const _boxSide = 9.0;

/// The box's corner radius, the ribbon's width and the bow's width, as shares of the box's side.
const _boxCornerShare = 0.15;
const _ribbonShare = 0.2;
const _bowShare = 0.3;

/// The fuse bar: how far it hangs below the box, and its width and thickness, in field units.
const _fuseGap = 1.5;
const _fuseWidth = 16.0;
const _fuseThickness = 1.2;

/// The fuse left at which the warning colour comes in, in ms: the bar and the box's edge turn to it.
const _warnFuseMs = 3000;

/// The wiggle, with the effects on: how far the box swings either way in radians, and how many ms a swing takes.
const _wiggleRadians = 0.12;
const _wiggleMsPerSwing = 400;

/// The pop's burst, with the effects on: how many rays, and how far in and out from the box's centre each runs,
/// as shares of the box's side.
const _burstRays = 8;
const _burstInShare = 0.85;
const _burstOutShare = 1.2;

/// Draws [present] on the board of [side] it is with (M17 r3a): the gift box near the top centre of the board's
/// [field], and the fuse bar under it, which shrinks as the fuse runs down. The bar is drawn with the effects off
/// too. Once it has popped only a burst of rays is drawn, and only with the effects on: the confetti is B11's.
void paintPresent(
  Canvas canvas,
  PresentState present, {
  required PuzzleField field,
  required ToyLook look,
  required PuzzleSide side,
}) {
  if (present.holder != side) return;
  final centre = Offset(field.board.center.dx, field.board.top + _boxSide / 2);
  final outline = look.sizes.outlineWidth / _pxPerUnit(canvas);
  if (present.popped) {
    if (look.effects) _burst(canvas, centre, look, outline);
    return;
  }
  final warn = present.fuseMs <= _warnFuseMs;
  // The swing runs off the fuse's own clock, so it wiggles in step with the fuse and not with the frame rate.
  final swing = warn && look.effects ? sin(present.fuseMs * 2 * pi / _wiggleMsPerSwing) * _wiggleRadians : 0.0;
  canvas
    ..save()
    ..translate(centre.dx, centre.dy)
    ..rotate(swing);
  _box(canvas, look, outline, warn);
  canvas.restore();
  _fuse(canvas, centre, present, look, outline, warn);
}

/// How many pixels one field unit is on [canvas] as it stands: the whole transform's scale, as text_paint's is
/// (private to the view, so this library keeps its own copy).
double _pxPerUnit(Canvas canvas) {
  final m = canvas.getTransform();
  return sqrt(m[0] * m[0] + m[1] * m[1]);
}

/// The gift box about the origin: a rounded square in the look's bad colour, a ribbon cross and a bow in its focus
/// colour, and an edge in the ink, or in the warning colour once the fuse is short.
void _box(Canvas canvas, ToyLook look, double outline, bool warn) {
  final colours = look.colors;
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: _boxSide, height: _boxSide),
    const Radius.circular(_boxSide * _boxCornerShare),
  );
  final ribbon = Paint()..color = colours.focus;
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = outline
    ..color = warn ? colours.caution : colours.ink;
  final strip = _boxSide * _ribbonShare;
  final bow = _boxSide * _bowShare;
  canvas
    ..drawRRect(body, Paint()..color = colours.bad)
    ..drawRect(Rect.fromCenter(center: Offset.zero, width: _boxSide, height: strip), ribbon)
    ..drawRect(Rect.fromCenter(center: Offset.zero, width: strip, height: _boxSide), ribbon)
    ..drawRRect(body, edge);
  for (final dx in [-bow / 2, bow / 2]) {
    final loop = Rect.fromCenter(center: Offset(dx, -_boxSide / 2), width: bow, height: bow);
    canvas
      ..drawOval(loop, ribbon)
      ..drawOval(loop, edge);
  }
}

/// The fuse bar under the box: a track in the tray colour, and the fuse left as the fill, in the good colour or in
/// the warning colour once it is short. Its share is the fuse left over the fuse it started with.
void _fuse(Canvas canvas, Offset centre, PresentState present, ToyLook look, double outline, bool warn) {
  final colours = look.colors;
  final share = present.fuseTotalMs > 0 ? min(max(present.fuseMs / present.fuseTotalMs, 0.0), 1.0) : 0.0;
  final track = Rect.fromLTWH(
    centre.dx - _fuseWidth / 2,
    centre.dy + _boxSide / 2 + _fuseGap,
    _fuseWidth,
    _fuseThickness,
  );
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = outline
    ..color = colours.ink;
  canvas
    ..drawRect(track, Paint()..color = colours.tray)
    ..drawRect(
      Rect.fromLTWH(track.left, track.top, track.width * share, track.height),
      Paint()..color = warn ? colours.caution : colours.good,
    )
    ..drawRect(track, edge);
}

/// The pop's burst, with the effects on: [_burstRays] short rays in the focus colour, round the box's centre.
void _burst(Canvas canvas, Offset centre, ToyLook look, double outline) {
  final ray = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = outline
    ..color = look.colors.focus;
  for (var i = 0; i < _burstRays; i++) {
    final angle = i * 2 * pi / _burstRays;
    final direction = Offset(cos(angle), sin(angle));
    canvas.drawLine(
      centre + direction * (_boxSide * _burstInShare),
      centre + direction * (_boxSide * _burstOutShare),
      ray,
    );
  }
}
