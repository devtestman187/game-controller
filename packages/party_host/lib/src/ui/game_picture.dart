import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// Which game's picture a picker card draws (M13 3b, mock-up `game-picker`).
enum GamePicture {
  /// Shape Race: a triangle, a square and a circle in player colours,
  /// overlapping a little like pieces on a mat.
  shapeRace,

  /// The Arena: a player's marble beside the goal pad and its flag.
  arena,
}

/// How much of the picture's box the Shape Race pieces take, in shares of its
/// shorter side: the pieces sit inside the middle of the card.
const _piecesShare = 0.8;

/// A game's picture for the game picker (M13 3b): drawn with [toyShape], so it
/// looks like the pieces on the boards, shader and all when the look has one.
class GamePictureView extends StatelessWidget {
  const GamePictureView({super.key, required this.picture});

  /// Which game's picture to draw.
  final GamePicture picture;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: GamePicturePainter(look: look, picture: picture),
    );
  }
}

/// Draws one [GamePicture]: the piece shapes and the goal, each with the look's
/// ink edge and hard shadow ([toyShape]).
class GamePicturePainter extends CustomPainter {
  const GamePicturePainter({required this.look, required this.picture});

  /// The look the picture is drawn in: its colours, its outline and its shade.
  final ToyLook look;

  /// Which game's picture this is.
  final GamePicture picture;

  /// The style every piece here is drawn in: the look's ink and this screen's
  /// outline width.
  ToyShapeStyle get _style => ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);

  @override
  void paint(Canvas canvas, Size size) {
    switch (picture) {
      case GamePicture.shapeRace:
        _paintShapeRace(canvas, size);
      case GamePicture.arena:
        _paintArena(canvas, size);
    }
  }

  /// Shape Race's three pieces, overlapping a little across the middle.
  void _paintShapeRace(Canvas canvas, Size size) {
    final colors = look.colors;
    // One measure for every piece, so the picture keeps its shape in any box.
    final unit = math.min(size.width, size.height) * _piecesShare;
    final left = size.width / 2 - unit / 2;
    final top = size.height / 2 - unit / 2;
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(left + unit * 0.22, top + unit * 0.58), radius: unit * 0.24));
    toyShape(canvas, circle, colors.player(1), _style, shade: look.shade);
    final square = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + unit * 0.3, top + unit * 0.18, unit * 0.4, unit * 0.4),
          Radius.circular(unit * 0.06),
        ),
      );
    toyShape(canvas, square, colors.player(2), _style, shade: look.shade);
    final triangle = Path()
      ..moveTo(left + unit * 0.72, top + unit * 0.34)
      ..lineTo(left + unit * 0.94, top + unit * 0.8)
      ..lineTo(left + unit * 0.5, top + unit * 0.8)
      ..close();
    toyShape(canvas, triangle, colors.player(4), _style, shade: look.shade);
  }

  /// The Arena's marble, and the goal pad with its flag on the right.
  void _paintArena(Canvas canvas, Size size) {
    final colors = look.colors;
    final unit = math.min(size.width, size.height) * _piecesShare;
    final left = size.width / 2 - unit / 2;
    final top = size.height / 2 - unit / 2;
    final marble = Path()
      ..addOval(Rect.fromCircle(center: Offset(left + unit * 0.3, top + unit * 0.6), radius: unit * 0.24));
    toyShape(canvas, marble, colors.player(1), _style, shade: look.shade);
    final pad = Rect.fromLTWH(left + unit * 0.56, top + unit * 0.42, unit * 0.42, unit * 0.42);
    final goal = Path()..addRRect(RRect.fromRectAndRadius(pad, Radius.circular(unit * 0.1)));
    toyShape(canvas, goal, colors.good, _style, shade: look.shade);
    // The flag's pole stands on the pad's top edge, in ink and thin.
    canvas.drawLine(
      Offset(pad.left + pad.width * 0.3, pad.top),
      Offset(pad.left + pad.width * 0.3, top + unit * 0.16),
      Paint()
        ..color = colors.ink
        ..strokeWidth = look.sizes.outlineWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(GamePicturePainter oldDelegate) => oldDelegate.look != look || oldDelegate.picture != picture;
}
