import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../pad.dart';
import '../providers.dart';

/// Every finger is tracked from the moment it touches down, even after it
/// slides outside the control, so input never gets stuck.
class _PointerArea extends StatelessWidget {
  const _PointerArea({required this.onDownOrMove, required this.onUp, required this.child});

  final void Function(int pointer, Offset local) onDownOrMove;
  final void Function(int pointer) onUp;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) => onDownOrMove(e.pointer, e.localPosition),
    onPointerMove: (e) => onDownOrMove(e.pointer, e.localPosition),
    onPointerUp: (e) => onUp(e.pointer),
    onPointerCancel: (e) => onUp(e.pointer),
    child: child,
  );
}

/// 8-way D-pad. Sliding the thumb changes direction without lifting.
class DpadView extends ConsumerWidget {
  const DpadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(padProvider);
    final pad = ref.read(padProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox.square(
          key: const Key('dpad'),
          dimension: side,
          child: _PointerArea(
            onDownOrMove: (pointer, local) => pad.dpad(pointer, dpadDirection(local, side)),
            onUp: pad.up,
            child: CustomPaint(
              painter: _DpadPainter(
                dx: input.dx,
                dy: input.dy,
                base: scheme.surfaceContainerHighest,
                lit: scheme.primary,
                arrow: scheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DpadPainter extends CustomPainter {
  _DpadPainter({required this.dx, required this.dy, required this.base, required this.lit, required this.arrow});

  final int dx;
  final int dy;
  final Color base;
  final Color lit;
  final Color arrow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final arm = s * 0.34;
    final c = s / 2;
    final radius = Radius.circular(s * 0.06);
    // (direction, arm rectangle)
    final arms = <((int, int), Rect)>[
      ((0, -1), Rect.fromLTWH(c - arm / 2, 0, arm, c)),
      ((0, 1), Rect.fromLTWH(c - arm / 2, c, arm, c)),
      ((-1, 0), Rect.fromLTWH(0, c - arm / 2, c, arm)),
      ((1, 0), Rect.fromLTWH(c, c - arm / 2, c, arm)),
    ];
    for (final ((ax, ay), rect) in arms) {
      // A diagonal lights both of its arms.
      final on = (ax != 0 && ax == dx) || (ay != 0 && ay == dy);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = on ? lit : base);
      final tip = Offset(c + ax * s * 0.40, c + ay * s * 0.40);
      final back = Offset(c + ax * s * 0.30, c + ay * s * 0.30);
      final side = Offset(-ay * s * 0.06, ax * s * 0.06);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + side.dx, back.dy + side.dy)
          ..lineTo(back.dx - side.dx, back.dy - side.dy)
          ..close(),
        Paint()..color = arrow.withValues(alpha: on ? 1 : 0.5),
      );
    }
    canvas.drawCircle(Offset(c, c), arm * 0.28, Paint()..color = arrow.withValues(alpha: 0.15));
  }

  @override
  bool shouldRepaint(_DpadPainter old) => old.dx != dx || old.dy != dy || old.lit != lit || old.base != base;
}

/// A, B, X, Y in a diamond. A thumb can slide from one to the next.
class FaceButtonsView extends ConsumerWidget {
  const FaceButtonsView({super.key});

  static const colors = {
    ControllerButton.a: Color(0xFF4CAF50),
    ControllerButton.b: Color(0xFFE53935),
    ControllerButton.x: Color(0xFF1E88E5),
    ControllerButton.y: Color(0xFFFDD835),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressed = ref.watch(padProvider.select((p) => p.buttons));
    final pad = ref.read(padProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox.square(
          key: const Key('faceButtons'),
          dimension: side,
          child: _PointerArea(
            onDownOrMove: (pointer, local) => pad.button(pointer, faceButtonAt(local, side)),
            onUp: pad.up,
            child: CustomPaint(
              painter: _FacePainter(pressed: pressed, base: scheme.surfaceContainerHighest, text: scheme.onSurface),
            ),
          ),
        );
      },
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({required this.pressed, required this.base, required this.text});

  final Set<ControllerButton> pressed;
  final Color base;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    for (final MapEntry(key: button, value: center) in faceButtonCenters.entries) {
      final on = pressed.contains(button);
      final color = FaceButtonsView.colors[button]!;
      final c = center * s;
      final r = faceButtonRadius * s * (on ? 0.94 : 1);
      canvas.drawCircle(c, r, Paint()..color = on ? color : base);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012
          ..color = color,
      );
      final label = TextPainter(
        text: TextSpan(
          text: button.name.toUpperCase(),
          style: TextStyle(fontSize: s * 0.11, fontWeight: FontWeight.bold, color: on ? Colors.black : color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, c - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.pressed.length != pressed.length || !old.pressed.containsAll(pressed) || old.base != base;
}

/// Start and Select: small pills. Sliding off releases.
class SmallButton extends ConsumerWidget {
  const SmallButton({super.key, required this.button, required this.label, this.size = const Size(96, 44)});

  final ControllerButton button;
  final String label;

  /// 96 x 44 for Start/Select; stick mode sizes them (and LB/RB) to its layout.
  final Size size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(padProvider.select((p) => p.buttons.contains(button)));
    final pad = ref.read(padProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.fromSize(
      size: size,
      child: _PointerArea(
        onDownOrMove: (pointer, local) => pad.button(pointer, (Offset.zero & size).contains(local) ? button : null),
        onUp: pad.up,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: on ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(size.height / 2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: on ? scheme.onPrimary : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
