import 'dart:async';
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
    final showsGame = ref.watch(showsGameProvider);
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
            // Over a game, Start (Pause) is in the bar.
            if (!showsGame)
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

  /// The pad, and the app scope it lives in, kept while mounted: a thumb still
  /// on the stick when the screen goes must let go in [dispose], where [ref]
  /// no longer works (B-031).
  late final PadNotifier _pad;
  State<ProviderScope>? _scope;

  double get _radius => widget.home.width / 2;

  @override
  void initState() {
    super.initState();
    _scope = context.findAncestorStateOfType<State<ProviderScope>>();
    _pad = ref.read(padProvider.notifier);
  }

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
    // A pointer move can land after the stick is gone (B-031): ref is unusable
    // then, and dispose has already let the stick go.
    if (!mounted || center == null) return;
    ref
        .read(padProvider.notifier)
        .stick(widget.side, stickValue(position - center, _radius, ref.read(stickSettingsProvider)));
  }

  void _up(int pointer) {
    // The same: a lift can land after the stick is gone, and dispose has let
    // the stick go already.
    if (!mounted || pointer != _pointer) return;
    setState(() {
      _pointer = null;
      _center = null;
    });
    ref.read(padProvider.notifier).stick(widget.side, stickCenter, touched: false);
  }

  @override
  void dispose() {
    // A thumb on the stick when its screen goes (a round ends, the layout
    // changes, a reconnect) never lifts: let the stick go, or the TV keeps it
    // pushed (B-031). A provider can't change while the widget tree is
    // finalizing, so the release goes out right after this frame, unless the
    // app's scope went with the screen and no pad is left to tell.
    if (_pointer != null) {
      final side = widget.side;
      final pad = _pad;
      unawaited(
        Future.microtask(() {
          if (_scope?.mounted ?? false) pad.stick(side, stickCenter, touched: false);
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(padProvider.select((p) => widget.side == StickSide.left ? p.left : p.right)) ?? stickCenter;
    final floating = ref.watch(stickSettingsProvider.select((s) => s.floating));
    final look = ref.watch(toyLookProvider);
    final player = ref.watch(clientStateProvider.select((s) => s.player));
    final character = ref.watch(clientStateProvider.select((s) => s.character));
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
          geometry: StickGeometry(center: _center ?? widget.home.center, radius: _radius, value: value),
          active: _pointer != null,
          // An idle floating stick is shown faintly where it will appear.
          faint: floating && _pointer == null,
          fill: PadFill(player: player, character: character),
        ),
      ),
    );
  }
}

/// Where a stick is drawn and where its knob sits: the base's [center] and [radius], and the knob's [value], the
/// stick's tilt from the middle (each axis from -1 to 1).
class StickGeometry {
  const StickGeometry({required this.center, required this.radius, required this.value});

  /// The centre of the base, in the pad's pixels.
  final Offset center;

  /// The radius of the base, in pixels.
  final double radius;

  /// The knob's tilt, each axis from -1 to 1; (0, 0) is the middle.
  final Stick value;

  @override
  bool operator ==(Object other) =>
      other is StickGeometry && other.center == center && other.radius == radius && other.value == value;

  @override
  int get hashCode => Object.hash(center, radius, value);
}

/// A stick in the look (M13 step 8, rule 5): the base a paper ring with an ink
/// edge at today's alpha, the knob the fill's colour (the character's, else the
/// player's) with an ink edge and the hard shadow, pushed in while it's held, and
/// not held at today's faded alpha.
class StickPainter extends CustomPainter {
  const StickPainter({
    required this.look,
    required this.geometry,
    required this.active,
    required this.faint,
    this.fill = const PadFill(),
  });

  /// The look the pad is drawn in.
  final ToyLook look;

  /// Where the stick is drawn and where its knob sits.
  final StickGeometry geometry;

  /// Whether a thumb holds the stick now (the knob drawn full, and squished).
  final bool active;

  /// Whether the stick is an idle floating one, drawn faintly where it appears.
  final bool faint;

  /// The colour the knob is filled with: the character's over the player's.
  final PadFill fill;

  /// The alpha everything takes when [faint] (today's 0.4), and the knob's
  /// when it isn't held (today's 0.55).
  static const faintAlpha = 0.4;
  static const idleAlpha = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = faint ? faintAlpha : 1.0;
    final center = geometry.center;
    final radius = geometry.radius;
    canvas.drawCircle(center, radius, Paint()..color = look.colors.paper.withValues(alpha: alpha));
    canvas.drawCircle(center, radius, padInkEdge(look)..color = look.colors.ink.withValues(alpha: alpha));
    final knobRadius = max(14.0, radius * 0.42);
    final travel = radius - knobRadius * 0.5;
    final value = geometry.value;
    final knob = Path()
      ..addOval(Rect.fromCircle(center: center + Offset(value.x, value.y) * travel, radius: knobRadius));
    _paintKnob(canvas, knob, alpha);
  }

  /// The knob: pushed in while it's held (no shadow, body moved), otherwise the
  /// hard shadow under it and today's faded colour.
  void _paintKnob(Canvas canvas, Path knob, double alpha) {
    final colour = fill.colour(look.colors);
    if (active) {
      final body = knob.shift(padSquish(true));
      canvas
        ..drawPath(body, Paint()..color = colour.withValues(alpha: alpha))
        ..drawPath(body, padInkEdge(look)..color = look.colors.ink.withValues(alpha: alpha));
      return;
    }
    // The shadow keeps the look's own alpha: a faint stick is only a hint of
    // where it appears, and it casts the same sticker shadow as the rest.
    paintStickerShadow(canvas, knob, look.colors.ink);
    final body = Paint()..color = colour.withValues(alpha: idleAlpha * alpha);
    canvas
      ..drawPath(knob, body)
      ..drawPath(knob, padInkEdge(look));
  }

  @override
  bool shouldRepaint(StickPainter old) =>
      old.look != look || old.geometry != geometry || old.active != active || old.faint != faint || old.fill != fill;
}
