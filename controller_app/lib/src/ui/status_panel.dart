import 'dart:math';

import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' show ToyLook, ToyLookScope, ToySizes, toyShadowAlpha;
import 'package:protocol/protocol.dart';

/// The status panel's height, in shares of the look's button height: the 36 px
/// the bar always gave it (M13 3c, rule 3: the bar's sizes don't change).
const statusPanelHeightShare = 0.75;

/// The room between the panel's parts, in shares of the look's button height.
const statusPanelGapShare = 0.15;

/// How wide the progress bar is, in shares of the look's button height.
const statusProgressWidthShare = 1.5;

/// The shape's size in the panel, in shares of the panel's height.
const statusShapeShare = 0.75;

/// The game's status panel (PRD v2 P6), in the top bar so no control gets
/// smaller (C24): one shape at its angle, a short text and a progress bar, on
/// paper with the look's ink edge, and filled with bad while
/// [StatusMessage.warning] is on (M13 3c, rule 4: a warning's text stays ink).
class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.status});

  final StatusMessage status;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final height = look.sizes.buttonHeight * statusPanelHeightShare;
    return Container(
      key: const Key('statusPanel'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8),
      decoration: ShapeDecoration(
        color: status.warning ? colors.bad : colors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToySizes.space8),
          side: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.shape case final shape?) ...[
            SizedBox.square(
              key: const Key('statusShape'),
              dimension: height * statusShapeShare,
              child: CustomPaint(painter: StatusShapePainter(shape, look)),
            ),
            SizedBox(width: look.sizes.buttonHeight * statusPanelGapShare),
          ],
          Flexible(child: _label(look)),
        ],
      ),
    );
  }

  /// The line of text and, under it, how far the game has gone.
  Widget _label(ToyLook look) {
    final colors = look.colors;
    final text = status.text;
    final progress = status.progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text != null)
          Text(
            text,
            key: const Key('statusText'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: look.type.body.copyWith(color: colors.ink),
          ),
        if (progress != null) ...[
          SizedBox(height: ToySizes.space4 / 2),
          SizedBox(
            width: look.sizes.buttonHeight * statusProgressWidthShare,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ToySizes.space4 / 2),
              child: LinearProgressIndicator(
                key: const Key('statusProgress'),
                value: progress,
                minHeight: ToySizes.space4,
                color: status.warning ? colors.ink : colors.good,
                backgroundColor: colors.ink.withValues(alpha: toyShadowAlpha),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Draws a [StatusShape] filling its box, turned to its angle, in the game's
/// own colours with the look's ink edge, so a shape reads at any angle.
class StatusShapePainter extends CustomPainter {
  StatusShapePainter(this.shape, this.look);

  /// The game's shape: its colour, angle and outline.
  final StatusShape shape;

  /// The look whose ink edge colour and width it is drawn with.
  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2;
    final fill = Paint()..color = Color(shape.color);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.sizes.outlineWidth / 2
      ..color = look.colors.ink;
    if (shape.circle) {
      canvas
        ..drawCircle(c, r * 0.9, fill)
        ..drawCircle(c, r * 0.9, edge);
      return;
    }
    if (shape.points.length < 3) return;
    final a = shape.angle * pi / 180;
    final path = Path()
      ..addPolygon([
        for (final (x, y) in shape.points) c + Offset(x * cos(a) - y * sin(a), x * sin(a) + y * cos(a)) * r,
      ], true);
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, edge);
  }

  @override
  bool shouldRepaint(StatusShapePainter old) => old.shape != shape || old.look != look;
}
