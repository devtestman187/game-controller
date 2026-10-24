import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gyro.dart';

/// Gyro mode's left side: where the tilt is (dot), the dead zone (inner
/// ring), and a Calibrate button.
class TiltView extends ConsumerWidget {
  const TiltView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyro = ref.watch(gyroProvider);
    final deadZone = ref.watch(gyroSettingsProvider.select((s) => s.deadZone));
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave room under the circle for the values and the button.
        final side = min(constraints.maxWidth, constraints.maxHeight - 96).clamp(80.0, 400.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: const Key('tiltView'),
              dimension: side,
              child: TiltDot(
                x: gyro.x,
                y: gyro.y,
                deadZone: deadZone,
                ring: scheme.surfaceContainerHighest,
                dot: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'x ${gyro.x.toStringAsFixed(2)}  y ${gyro.y.toStringAsFixed(2)}',
                  key: const Key('tiltValues'),
                  style: text.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                FilledButton.tonalIcon(
                  key: const Key('calibrate'),
                  onPressed: ref.read(gyroProvider.notifier).calibrate,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Calibrate'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A circle with a dot at (x, y) and the dead zone drawn in the middle.
class TiltDot extends StatelessWidget {
  const TiltDot({
    super.key,
    required this.x,
    required this.y,
    required this.deadZone,
    required this.ring,
    required this.dot,
  });

  final double x;
  final double y;
  final double deadZone;
  final Color ring;
  final Color dot;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TiltPainter(x: x, y: y, deadZone: deadZone, ring: ring, dot: dot),
  );
}

class _TiltPainter extends CustomPainter {
  _TiltPainter({required this.x, required this.y, required this.deadZone, required this.ring, required this.dot});

  final double x;
  final double y;
  final double deadZone;
  final Color ring;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = ring);
    final line = Paint()
      ..color = dot.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), line);
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), line);
    if (deadZone > 0) {
      canvas.drawCircle(
        c,
        r * deadZone,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = dot.withValues(alpha: 0.5),
      );
    }
    final dotRadius = max(6.0, r * 0.1);
    canvas.drawCircle(c + Offset(x, y) * (r - dotRadius), dotRadius, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_TiltPainter old) => old.x != x || old.y != y || old.deadZone != deadZone || old.dot != dot;
}
