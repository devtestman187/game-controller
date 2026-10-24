import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart';

/// A small picture of a controller (PRD T5): D-pad, Select/Start and A/B/X/Y,
/// lit while held. A null [input] (not connected) shows everything released.
class InputVisualizer extends StatelessWidget {
  const InputVisualizer({super.key, required this.input, this.width = 210});

  final InputStateMessage? input;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      // D-pad and face buttons are 3 units square each, with 3.6 units between.
      height: width / 3.2,
      child: CustomPaint(
        painter: _ControllerPainter(
          buttons: input?.buttons ?? const {},
          dx: input?.dx ?? 0,
          tx: input?.ax,
          ty: input?.ay,
          dy: input?.dy ?? 0,
          base: scheme.surfaceContainerHighest,
          lit: scheme.primary,
          label: scheme.onSurface,
        ),
      ),
    );
  }
}

class _ControllerPainter extends CustomPainter {
  _ControllerPainter({
    required this.buttons,
    required this.dx,
    required this.dy,
    this.tx,
    this.ty,
    required this.base,
    required this.lit,
    required this.label,
  });

  final Set<ControllerButton> buttons;
  final int dx;
  final int dy;

  /// Gyro tilt, null outside gyro mode.
  final double? tx;
  final double? ty;
  final Color base;
  final Color lit;
  final Color label;

  static const _faceColors = {
    ControllerButton.a: Color(0xFF4CAF50),
    ControllerButton.b: Color(0xFFE53935),
    ControllerButton.x: Color(0xFF1E88E5),
    ControllerButton.y: Color(0xFFFDD835),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final unit = h / 3;

    final tiltX = tx;
    final tiltY = ty;
    if (tiltX != null && tiltY != null) {
      // Gyro mode: a stick with a dot where the tilt is.
      final c = Offset(h / 2, h / 2);
      final r = h / 2 - 1;
      canvas.drawCircle(c, r, Paint()..color = base);
      final cross = Paint()
        ..color = label.withValues(alpha: 0.2)
        ..strokeWidth = 1;
      canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), cross);
      canvas.drawLine(c - Offset(0, r), c + Offset(0, r), cross);
      final dot = unit * 0.35;
      canvas.drawCircle(c + Offset(tiltX, tiltY) * (r - dot), dot, Paint()..color = lit);
    } else {
      // D-pad: a 3x3 grid, lit on the arms of the current direction.
      for (final (ax, ay) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
        final on = (ax != 0 && ax == dx) || (ay != 0 && ay == dy);
        final rect = Rect.fromLTWH((ax + 1) * unit, (ay + 1) * unit, unit, unit);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(unit * 0.15)),
          Paint()..color = on ? lit : base,
        );
      }
      canvas.drawRect(Rect.fromLTWH(unit, unit, unit, unit).deflate(1), Paint()..color = base);
    }

    // Select and Start in the middle.
    final mid = size.width / 2;
    for (final (button, offset) in const [(ControllerButton.select, -1), (ControllerButton.start, 1)]) {
      final on = buttons.contains(button);
      final rect = Rect.fromCenter(
        center: Offset(mid + offset * unit * 0.75, h / 2),
        width: unit * 1.2,
        height: unit * 0.55,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit)), Paint()..color = on ? lit : base);
    }

    // A/B/X/Y diamond on the right.
    final right = size.width - h / 2;
    final centers = {
      ControllerButton.y: Offset(right, unit * 0.5),
      ControllerButton.x: Offset(right - unit, h / 2),
      ControllerButton.b: Offset(right + unit, h / 2),
      ControllerButton.a: Offset(right, h - unit * 0.5),
    };
    for (final MapEntry(key: button, value: c) in centers.entries) {
      final on = buttons.contains(button);
      final color = _faceColors[button]!;
      canvas.drawCircle(c, unit * 0.45, Paint()..color = on ? color : base);
      final text = TextPainter(
        text: TextSpan(
          text: button.name.toUpperCase(),
          style: TextStyle(fontSize: unit * 0.5, fontWeight: FontWeight.bold, color: on ? Colors.black : color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ControllerPainter old) =>
      old.dx != dx ||
      old.tx != tx ||
      old.ty != ty ||
      old.dy != dy ||
      old.buttons.length != buttons.length ||
      !old.buttons.containsAll(buttons) ||
      old.lit != lit;
}
