import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../layout.dart';
import '../pad.dart';
import '../providers.dart';

/// Every finger is tracked from the moment it touches down, even after it
/// slides outside the control, so input never gets stuck.
class _PointerArea extends StatelessWidget {
  const _PointerArea({
    required this.onDownOrMove,
    required this.onUp,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
  });

  final void Function(int pointer, Offset local) onDownOrMove;
  final void Function(int pointer) onUp;
  final HitTestBehavior behavior;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: behavior,
    onPointerDown: (e) => onDownOrMove(e.pointer, e.localPosition),
    onPointerMove: (e) => onDownOrMove(e.pointer, e.localPosition),
    onPointerUp: (e) => onUp(e.pointer),
    onPointerCancel: (e) => onUp(e.pointer),
    child: child,
  );
}

/// A quick bright flash over each part of a control as it's pressed, for
/// devices without haptics (PRD v2 C33). [shapeOf] outlines a part.
class PressFlash<T> extends ConsumerStatefulWidget {
  const PressFlash({super.key, required this.pressed, required this.shapeOf, required this.child});

  final Set<T> pressed;
  final Path Function(T part, Size size) shapeOf;
  final Widget child;

  static const duration = Duration(milliseconds: 180);

  @override
  ConsumerState<PressFlash<T>> createState() => _PressFlashState<T>();
}

class _PressFlashState<T> extends ConsumerState<PressFlash<T>> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: PressFlash.duration, value: 1);
  Set<T> _parts = {};

  @override
  void didUpdateWidget(PressFlash<T> old) {
    super.didUpdateWidget(old);
    final added = widget.pressed.difference(old.pressed);
    if (added.isNotEmpty && ref.read(flashOnPressProvider)) {
      _parts = added;
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('pressFlash'),
    foregroundPainter: _FlashPainter(_flash, () => _parts, widget.shapeOf),
    child: widget.child,
  );
}

class _FlashPainter<T> extends CustomPainter {
  _FlashPainter(this.flash, this.parts, this.shapeOf) : super(repaint: flash);

  final AnimationController flash;
  final Set<T> Function() parts;
  final Path Function(T part, Size size) shapeOf;

  @override
  void paint(Canvas canvas, Size size) {
    if (flash.value >= 1) return;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75 * (1 - flash.value));
    for (final part in parts()) {
      canvas.drawPath(shapeOf(part, size), paint);
    }
  }

  @override
  bool shouldRepaint(_FlashPainter<T> old) => false;
}

/// The D-pad's arms, for drawing and flashing: (direction, rectangle) in a
/// square of side [s].
List<((int, int), Rect)> dpadArms(double s) {
  final arm = s * 0.34;
  final c = s / 2;
  return [
    ((0, -1), Rect.fromLTWH(c - arm / 2, 0, arm, c)),
    ((0, 1), Rect.fromLTWH(c - arm / 2, c, arm, c)),
    ((-1, 0), Rect.fromLTWH(0, c - arm / 2, c, arm)),
    ((1, 0), Rect.fromLTWH(c, c - arm / 2, c, arm)),
  ];
}

/// 8-way D-pad. Sliding the thumb changes direction without lifting.
class DpadView extends ConsumerWidget {
  const DpadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(padProvider);
    final pad = ref.read(padProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    // The lit arms (a diagonal lights two).
    final lit = {if (input.dx != 0) (input.dx, 0), if (input.dy != 0) (0, input.dy)};
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox.square(
          key: const Key('dpad'),
          dimension: side,
          child: _PointerArea(
            onDownOrMove: (pointer, local) => pad.dpad(pointer, dpadDirection(local, side)),
            onUp: pad.up,
            child: PressFlash<(int, int)>(
              pressed: lit,
              shapeOf: (dir, size) {
                final rect = dpadArms(size.width).firstWhere((a) => a.$1 == dir).$2;
                return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.06)));
              },
              child: CustomPaint(
                size: Size.square(side),
                painter: _DpadPainter(
                  dx: input.dx,
                  dy: input.dy,
                  base: scheme.surfaceContainerHighest,
                  lit: scheme.primary,
                  arrow: scheme.onSurface,
                ),
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
    for (final ((ax, ay), rect) in dpadArms(s)) {
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
  const FaceButtonsView({super.key, this.geometry = FaceGeometry.classic});

  /// [FaceGeometry.classic] in D-pad and gyro modes, compact in stick mode.
  final FaceGeometry geometry;

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
            // In stick mode only the round area around the buttons takes
            // touches, so the square's corners leave them to the right stick.
            behavior: geometry.roundHitArea ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
            onDownOrMove: (pointer, local) => pad.button(pointer, geometry.buttonAt(local, side)),
            onUp: pad.up,
            child: PressFlash<ControllerButton>(
              pressed: pressed.intersection(colors.keys.toSet()),
              shapeOf: (button, size) => Path()
                ..addOval(
                  Rect.fromCircle(center: geometry.centers[button]! * size.width, radius: geometry.radius * size.width),
                ),
              child: CustomPaint(
                size: Size.square(side),
                painter: _FacePainter(
                  side: side,
                  pressed: pressed,
                  geometry: geometry,
                  base: scheme.surfaceContainerHighest,
                  text: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.side,
    required this.pressed,
    required this.geometry,
    required this.base,
    required this.text,
  });

  final double side;

  final Set<ControllerButton> pressed;
  final FaceGeometry geometry;
  final Color base;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    for (final MapEntry(key: button, value: center) in geometry.centers.entries) {
      final on = pressed.contains(button);
      final color = FaceButtonsView.colors[button]!;
      final c = center * s;
      final r = geometry.radius * s * (on ? 0.94 : 1);
      canvas.drawCircle(c, r, Paint()..color = on ? color : base);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, r * 0.075)
          ..color = color,
      );
      final label = TextPainter(
        text: TextSpan(
          text: button.name.toUpperCase(),
          style: TextStyle(fontSize: r * 0.69, fontWeight: FontWeight.bold, color: on ? Colors.black : color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, c - Offset(label.width / 2, label.height / 2));
    }
  }

  /// Used for hit testing in stick mode (see [FaceButtonsView]).
  @override
  bool hitTest(Offset position) => geometry.takes(position, side);

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.geometry != geometry ||
      old.pressed.length != pressed.length ||
      !old.pressed.containsAll(pressed) ||
      old.base != base;
}

/// Start, Select, LB and RB: pills. Sliding off releases.
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
        child: PressFlash<ControllerButton>(
          pressed: {if (on) button},
          shapeOf: (_, s) => Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height / 2))),
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
      ),
    );
  }
}
