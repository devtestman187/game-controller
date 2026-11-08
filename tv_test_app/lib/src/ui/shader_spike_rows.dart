import 'dart:math' show min, pi;
import 'dart:ui' show FragmentProgram;

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart' show playerColors;
import 'package:toy_look/toy_look.dart';

/// The shapes a row always shows: one in each of four player colours.
const _basicCount = 4;

/// The shapes the stress switch adds to each row, through all six player
/// colours: enough that a slow GPU or a per-shape cost shows as a slow frame.
const _stressCount = 60;

/// How many shapes wide the stress grid is ([_stressCount] fills five rows).
const _stressColumns = 12;

/// A basic shape's size, in logical pixels.
const _basicSize = 108.0;

/// A basic shape's size with the stress shapes under it.
const _stressBasicSize = 44.0;

/// The most of a row's height a basic shape may take, so a short row still
/// leaves its shadow and outline room.
const _basicHeightShare = 0.8;

/// The share of a row's height the four basic shapes take when the stress
/// shapes are shown; the grid fills the rest.
const _stressBandShare = 0.34;

/// A stress shape's size as a share of its grid cell.
const _stressShapeShare = 0.72;

/// The rounded square's corner radius and the bar's width and height, as
/// shares of the shape's size.
const _cornerShare = 0.22;
const _barWidthShare = 1.5;
const _barHeightShare = 0.5;

/// The triangle's apex and base, as shares of its size from its centre.
const _triangleApex = -0.55;
const _triangleBase = 0.45;

/// The spike's four shapes, by index: a circle, a rounded square, a triangle
/// and a wide rounded bar, drawn about (0, 0) [size] across.
Path spikeShape(int index, double size) => switch (index % _basicCount) {
  0 => Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: size / 2)),
  1 =>
    Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size, height: size),
        Radius.circular(size * _cornerShare),
      ),
    ),
  2 =>
    Path()
      ..moveTo(0, size * _triangleApex)
      ..lineTo(size / 2, size * _triangleBase)
      ..lineTo(-size / 2, size * _triangleBase)
      ..close(),
  _ =>
    Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size * _barWidthShare, height: size * _barHeightShare),
        Radius.circular(size * _barHeightShare / 2),
      ),
    ),
};

/// One row of the spike's shapes, turned by [turn] so frames keep coming on a
/// screen that would otherwise be still.
///
/// With [shade] the bodies are the shader's, without it the Canvas fallback's:
/// two painters of the same row are the two looks side by side.
class ShaderSpikePainter extends CustomPainter {
  const ShaderSpikePainter({required this.shade, required this.turn, required this.stress});

  final FragmentProgram? shade;

  /// How far round the shapes have turned, 0 to 1 of one whole turn.
  final double turn;

  /// Whether the 60 stress shapes are drawn.
  final bool stress;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = turn * 2 * pi;
    final basicSize = stress ? _stressBasicSize : min(_basicSize, size.height * _basicHeightShare);
    final basicY = stress ? size.height * _stressBandShare / 2 : size.height / 2;
    for (var i = 0; i < _basicCount; i++) {
      _drawShape(canvas, i, basicSize, Offset(size.width * (i + 0.5) / _basicCount, basicY), radius);
    }
    if (stress) _drawStress(canvas, size, radius);
  }

  /// The stress shapes, in a grid under the four basic ones.
  void _drawStress(Canvas canvas, Size size, double radius) {
    final top = size.height * _stressBandShare;
    final cell = Size(size.width / _stressColumns, (size.height - top) / (_stressCount ~/ _stressColumns));
    final shapeSize = min(cell.width, cell.height) * _stressShapeShare;
    for (var i = 0; i < _stressCount; i++) {
      final centre = Offset(cell.width * (i % _stressColumns + 0.5), top + cell.height * (i ~/ _stressColumns + 0.5));
      _drawShape(canvas, i, shapeSize, centre, radius);
    }
  }

  /// Shape [index], in its player colour, turned [radius] about [centre].
  void _drawShape(Canvas canvas, int index, double size, Offset centre, double radius) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(radius);
    toyShape(
      canvas,
      spikeShape(index, size),
      Color(playerColors[index % playerColors.length]),
      const ToyShapeStyle(),
      shade: shade,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShaderSpikePainter oldDelegate) =>
      oldDelegate.shade != shade || oldDelegate.turn != turn || oldDelegate.stress != stress;
}
