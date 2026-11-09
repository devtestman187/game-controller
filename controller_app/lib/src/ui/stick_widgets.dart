import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show ToyLook, paintStickerShadow, toyLookProvider;
import 'package:protocol/protocol.dart';

import '../gyro.dart';
import '../layout.dart';
import '../providers.dart';
import '../sticks.dart';
import 'pad_drawing.dart';
import 'pad_widgets.dart';

/// Stick mode (PRD C12, v2 C14 to C16): left stick and D-pad, Select and
/// Start, A/B/X/Y and right stick, LB and RB, laid out by [stickLayout].
class StickModeView extends ConsumerWidget {
  const StickModeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floating = ref.watch(stickSettingsProvider.select((s) => s.floating));
    final buttonSize = ref.watch(stickSettingsProvider.select((s) => s.buttonSize));
    final mm = ref.watch(pxPerMmProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = stickLayout(constraints.biggest, mm: mm, buttonSize: buttonSize);
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
            Positioned.fromRect(
              rect: layout.faceButtons,
              child: const FaceButtonsView(geometry: FaceGeometry.compact),
            ),
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
    if (!floating && (e.localPosition - widget.home.center).distance > _radius * stickTouch) return;
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
    ref.read(padProvider.notifier).stick(widget.side, stickCenter, touched: false);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(padProvider.select((p) => widget.side == StickSide.left ? p.left : p.right)) ?? stickCenter;
    final floating = ref.watch(stickSettingsProvider.select((s) => s.floating));
    final look = ref.watch(toyLookProvider);
    final player = ref.watch(clientStateProvider.select((s) => s.player));
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
        painter: StickPainter(
          look: look,
          center: _center ?? widget.home.center,
          radius: _radius,
          value: value,
          active: _pointer != null,
          // An idle floating stick is shown faintly where it will appear.
          faint: floating && _pointer == null,
          player: player,
        ),
      ),
    );
  }
}

/// A stick in the look (M13 step 8, rule 5): the base a paper ring with an ink
/// edge at today's alpha, the knob the player's colour with an ink edge and the
/// hard shadow, pushed in while it's held, and not held at today's faded alpha.
class StickPainter extends CustomPainter {
  const StickPainter({
    required this.look,
    required this.center,
    required this.radius,
    required this.value,
    required this.active,
    required this.faint,
    this.player,
  });

  /// The look the pad is drawn in.
  final ToyLook look;

  final Offset center;
  final double radius;
  final Stick value;

  /// Whether a thumb holds the stick now (the knob drawn full, and squished).
  final bool active;

  /// Whether the stick is an idle floating one, drawn faintly where it appears.
  final bool faint;

  /// This phone's player, or null before the host gives them a number.
  final int? player;

  /// The alpha everything takes when [faint] (today's 0.4), and the knob's
  /// when it isn't held (today's 0.55).
  static const faintAlpha = 0.4;
  static const idleAlpha = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = faint ? faintAlpha : 1.0;
    canvas.drawCircle(center, radius, Paint()..color = look.colors.paper.withValues(alpha: alpha));
    canvas.drawCircle(center, radius, padInkEdge(look)..color = look.colors.ink.withValues(alpha: alpha));
    final knobRadius = max(14.0, radius * 0.42);
    final travel = radius - knobRadius * 0.5;
    final knob = Path()
      ..addOval(Rect.fromCircle(center: center + Offset(value.x, value.y) * travel, radius: knobRadius));
    _paintKnob(canvas, knob, alpha);
  }

  /// The knob: pushed in while it's held (no shadow, body moved), otherwise the
  /// hard shadow under it and today's faded colour.
  void _paintKnob(Canvas canvas, Path knob, double alpha) {
    final fill = padPlayerColour(look.colors, player);
    if (active) {
      final body = knob.shift(padSquish(true));
      canvas
        ..drawPath(body, Paint()..color = fill.withValues(alpha: alpha))
        ..drawPath(body, padInkEdge(look)..color = look.colors.ink.withValues(alpha: alpha));
      return;
    }
    // The shadow keeps the look's own alpha: a faint stick is only a hint of
    // where it appears, and it casts the same sticker shadow as the rest.
    paintStickerShadow(canvas, knob, look.colors.ink);
    final body = Paint()..color = fill.withValues(alpha: idleAlpha * alpha);
    canvas
      ..drawPath(knob, body)
      ..drawPath(knob, padInkEdge(look)..color = look.colors.ink.withValues(alpha: idleAlpha * alpha));
  }

  @override
  bool shouldRepaint(StickPainter old) =>
      old.look != look ||
      old.center != center ||
      old.value != value ||
      old.active != active ||
      old.faint != faint ||
      old.radius != radius ||
      old.player != player;
}
