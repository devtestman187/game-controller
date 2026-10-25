import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../gyro.dart';
import '../providers.dart';
import '../sticks.dart';
import 'pad_widgets.dart';

/// Stick mode (PRD C12): left stick and D-pad, Select and Start, A/B/X/Y and
/// right stick, LB and RB, laid out by [stickLayout].
class StickModeView extends ConsumerWidget {
  const StickModeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floating = ref.watch(stickSettingsProvider.select((s) => s.floating));
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = stickLayout(constraints.biggest);
        return Stack(
          children: [
            // The sticks go first, so in floating mode every other control
            // sits on top and wins where it overlaps a stick's zone.
            Positioned.fromRect(
              rect: floating ? layout.leftZone : layout.leftStick,
              child: AnalogStickView(
                key: const Key('leftStick'),
                side: StickSide.left,
                home: _relative(layout.leftStick, floating ? layout.leftZone : layout.leftStick),
              ),
            ),
            Positioned.fromRect(
              rect: floating ? layout.rightZone : layout.rightStick,
              child: AnalogStickView(
                key: const Key('rightStick'),
                side: StickSide.right,
                home: _relative(layout.rightStick, floating ? layout.rightZone : layout.rightStick),
              ),
            ),
            Positioned.fromRect(rect: layout.dpad, child: const DpadView()),
            Positioned.fromRect(rect: layout.faceButtons, child: const FaceButtonsView()),
            Positioned.fromRect(
              rect: layout.lb,
              child: SmallButton(button: ControllerButton.lb, label: 'LB', size: layout.lb.size),
            ),
            Positioned.fromRect(
              rect: layout.rb,
              child: SmallButton(button: ControllerButton.rb, label: 'RB', size: layout.rb.size),
            ),
            Positioned.fromRect(
              rect: layout.select,
              child: SmallButton(button: ControllerButton.select, label: 'Select', size: layout.select.size),
            ),
            Positioned.fromRect(
              rect: layout.start,
              child: SmallButton(button: ControllerButton.start, label: 'Start', size: layout.start.size),
            ),
          ],
        );
      },
    );
  }

  /// [rect] in the coordinates of [parent].
  static Rect _relative(Rect rect, Rect parent) => rect.shift(-parent.topLeft);
}

/// One analog stick (PRD C13). A fixed stick takes touches inside its circle;
/// a floating one takes them anywhere in its area and centers itself where
/// the thumb lands. The value goes to the TV; letting go re-centers it.
class AnalogStickView extends ConsumerStatefulWidget {
  const AnalogStickView({super.key, required this.side, required this.home});

  final StickSide side;

  /// Where the stick sits when idle, within this widget.
  final Rect home;

  @override
  ConsumerState<AnalogStickView> createState() => _AnalogStickViewState();
}

class _AnalogStickViewState extends ConsumerState<AnalogStickView> {
  int? _pointer;
  Offset? _center;

  double get _radius => widget.home.width / 2;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return; // One thumb per stick.
    final floating = ref.read(stickSettingsProvider).floating;
    // A fixed stick takes touches on its circle (a little beyond, for thumbs).
    if (!floating && (e.localPosition - widget.home.center).distance > _radius * 1.15) return;
    setState(() {
      _pointer = e.pointer;
      _center = floating ? e.localPosition : widget.home.center;
    });
    _move(e.localPosition);
  }

  void _move(Offset position) {
    final center = _center;
    if (center == null) return;
    ref
        .read(padProvider.notifier)
        .stick(widget.side, stickValue(position - center, _radius, ref.read(stickSettingsProvider)));
  }

  void _up(int pointer) {
    if (pointer != _pointer) return;
    setState(() {
      _pointer = null;
      _center = null;
    });
    ref.read(padProvider.notifier).stick(widget.side, stickCenter);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(padProvider.select((p) => widget.side == StickSide.left ? p.left : p.right)) ?? stickCenter;
    final floating = ref.watch(stickSettingsProvider.select((s) => s.floating));
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: (e) {
        if (e.pointer == _pointer) _move(e.localPosition);
      },
      onPointerUp: (e) => _up(e.pointer),
      onPointerCancel: (e) => _up(e.pointer),
      child: CustomPaint(
        size: Size.infinite,
        painter: _StickPainter(
          center: _center ?? widget.home.center,
          radius: _radius,
          value: value,
          active: _pointer != null,
          // An idle floating stick is shown faintly where it will appear.
          faint: floating && _pointer == null,
          base: scheme.surfaceContainerHighest,
          knob: scheme.primary,
          ring: scheme.outline,
        ),
      ),
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter({
    required this.center,
    required this.radius,
    required this.value,
    required this.active,
    required this.faint,
    required this.base,
    required this.knob,
    required this.ring,
  });

  final Offset center;
  final double radius;
  final Stick value;
  final bool active;
  final bool faint;
  final Color base;
  final Color knob;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = faint ? 0.4 : 1.0;
    canvas.drawCircle(center, radius, Paint()..color = base.withValues(alpha: alpha));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring.withValues(alpha: 0.5 * alpha),
    );
    final knobRadius = max(14.0, radius * 0.42);
    final travel = radius - knobRadius * 0.5;
    canvas.drawCircle(
      center + Offset(value.x, value.y) * travel,
      knobRadius,
      Paint()..color = (active ? knob : knob.withValues(alpha: 0.55)).withValues(alpha: (active ? 1.0 : 0.55) * alpha),
    );
  }

  @override
  bool shouldRepaint(_StickPainter old) =>
      old.center != center || old.value != value || old.active != active || old.faint != faint || old.radius != radius;
}
