import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart';

/// The game's status panel (PRD v2 P6), in the top bar so no control gets
/// smaller (C24): one shape at its angle, a short text and a progress bar,
/// red while [StatusMessage.warning] is on.
class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.status});

  final StatusMessage status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = status.text;
    final progress = status.progress;
    final shape = status.shape;
    final accent = status.warning ? scheme.error : scheme.primary;
    return Container(
      key: const Key('statusPanel'),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: status.warning ? Border.all(color: scheme.error, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shape != null) ...[
            SizedBox.square(
              key: const Key('statusShape'),
              dimension: 28,
              child: CustomPaint(painter: StatusShapePainter(shape)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: status.warning ? scheme.error : scheme.onSurface,
                    ),
                  ),
                if (progress != null) ...[
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        key: const Key('statusProgress'),
                        value: progress,
                        minHeight: 4,
                        color: accent,
                        backgroundColor: scheme.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a [StatusShape] filling its box, turned to its angle.
class StatusShapePainter extends CustomPainter {
  StatusShapePainter(this.shape);

  final StatusShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2;
    final fill = Paint()..color = Color(shape.color);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.5);
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
  bool shouldRepaint(StatusShapePainter old) => old.shape != shape;
}
