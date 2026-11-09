import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart'
    show ToyColors, ToyLook, paintDashedEdge, paintStickerShadow, toyLookProvider;
import 'package:protocol/protocol.dart';

import '../layout.dart';
import '../pad.dart';
import '../providers.dart';
import 'pad_drawing.dart';

part 'face_buttons.dart';

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

  /// How strong the flash starts, before it fades out (today's 0.75).
  static const alpha = 0.75;

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
    // The flash is the look's paper, not white (M13 step 8, rule 3).
    foregroundPainter: _FlashPainter(_flash, () => _parts, widget.shapeOf, ref.watch(toyLookProvider).colors.paper),
    child: widget.child,
  );
}

class _FlashPainter<T> extends CustomPainter {
  _FlashPainter(this.flash, this.parts, this.shapeOf, this.colour) : super(repaint: flash);

  final AnimationController flash;
  final Set<T> Function() parts;
  final Path Function(T part, Size size) shapeOf;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (flash.value >= 1) return;
    final paint = Paint()..color = colour.withValues(alpha: PressFlash.alpha * (1 - flash.value));
    for (final part in parts()) {
      canvas.drawPath(shapeOf(part, size), paint);
    }
  }

  @override
  bool shouldRepaint(_FlashPainter<T> old) => old.colour != colour;
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

/// How an arm's corners round, as a share of the square: today's 0.06.
const _armRoundShare = 0.06;

/// Where an arm's arrow points, how long it is and how wide, as shares of the
/// square: today's 0.40, 0.30 and 0.06.
const _arrowTipShare = 0.40;
const _arrowBackShare = 0.30;
const _arrowHalfShare = 0.06;

/// An unlit arm's arrow is drawn at this alpha (today's 0.5).
const _arrowOffAlpha = 0.5;

/// The centre dot's radius as a share of the square: an arm's 0.28, with the
/// arm at 0.34 of the square (today's).
const _centreDotShare = 0.34 * 0.28;

/// 8-way D-pad. Sliding the thumb changes direction without lifting.
class DpadView extends ConsumerWidget {
  const DpadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(padProvider);
    final pad = ref.read(padProvider.notifier);
    // The pad is drawn from the look provider, not the scope: it is the look
    // the app's scope is made of, and the controls layer is pumped on its own
    // in a test with no scope above it.
    final look = ref.watch(toyLookProvider);
    // This phone's player colours a lit arm (player 1's before one is known).
    final player = ref.watch(clientStateProvider.select((s) => s.player));
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
                return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.width * _armRoundShare)));
              },
              child: CustomPaint(
                size: Size.square(side),
                painter: DpadPainter(look: look, dx: input.dx, dy: input.dy, player: player),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The D-pad as one paper plus (M13 step 8, rule 4): the arms' union, so the
/// centre has no seam, with one ink edge and one hard shadow under the whole
/// shape; ink arrows on the arms, the lit arms filled in this phone's player
/// colour and pushed in, and the centre dot ink at [toyShadowAlpha].
class DpadPainter extends CustomPainter {
  const DpadPainter({required this.look, required this.dx, required this.dy, this.player});

  /// The look the pad is drawn in.
  final ToyLook look;

  /// The D-pad's direction: an arm pointing along it is lit (a diagonal's two).
  final int dx;
  final int dy;

  /// This phone's player, or null before the host gives them a number.
  final int? player;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final plus = _plus(s);
    // One shadow for the whole plus: a lit arm moves inside it rather than
    // dropping the shadow the other arms still cast.
    paintStickerShadow(canvas, plus, look.colors.ink);
    canvas.drawPath(plus, Paint()..color = look.colors.paper);
    _paintLitArms(canvas, plus, s);
    _paintArrows(canvas, s);
    // The edge goes on last, over the lit arms' moved fills, so they never
    // show outside it.
    canvas.drawPath(plus, padInkEdge(look));
    canvas.drawCircle(Offset(s / 2, s / 2), s * _centreDotShare, Paint()..color = padFaintInk(look));
  }

  /// The four arms as one shape: their union, so the edges inside it are gone.
  Path _plus(double s) {
    final radius = Radius.circular(s * _armRoundShare);
    Path? plus;
    for (final (_, rect) in dpadArms(s)) {
      final arm = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
      plus = plus == null ? arm : Path.combine(PathOperation.union, plus, arm);
    }
    return plus!;
  }

  /// A lit arm's fill: the player's colour, moved by the squish and clipped to
  /// the plus, so a moved fill never shows outside the plus's edge.
  void _paintLitArms(Canvas canvas, Path plus, double s) {
    final fill = Paint()..color = padPlayerColour(look.colors, player);
    final shift = padSquish(true);
    canvas
      ..save()
      ..clipPath(plus);
    for (final ((ax, ay), rect) in dpadArms(s)) {
      if (!_lit(ax, ay)) continue;
      canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(shift), Radius.circular(s * _armRoundShare)), fill);
    }
    canvas.restore();
  }

  /// A diagonal lights both of its arms.
  bool _lit(int ax, int ay) => (ax != 0 && ax == dx) || (ay != 0 && ay == dy);

  /// The arms' arrows in ink, a lit one's moved with its arm.
  void _paintArrows(Canvas canvas, double s) {
    final c = s / 2;
    for (final ((ax, ay), _) in dpadArms(s)) {
      final on = _lit(ax, ay);
      final shift = padSquish(on);
      final tip = Offset(c + ax * s * _arrowTipShare, c + ay * s * _arrowTipShare) + shift;
      final back = Offset(c + ax * s * _arrowBackShare, c + ay * s * _arrowBackShare) + shift;
      final side = Offset(-ay * s * _arrowHalfShare, ax * s * _arrowHalfShare);
      final ink = look.colors.ink.withValues(alpha: on ? 1 : _arrowOffAlpha);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + side.dx, back.dy + side.dy)
          ..lineTo(back.dx - side.dx, back.dy - side.dy)
          ..close(),
        Paint()..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(DpadPainter old) => old.look != look || old.dx != dx || old.dy != dy || old.player != player;
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
    final look = ref.watch(toyLookProvider);
    final player = ref.watch(clientStateProvider.select((s) => s.player));
    // The game's label replaces the usual one; a hidden button leaves its
    // space empty (P5).
    final game = ref.watch(gameLayoutProvider);
    if (game.hidden.contains(button)) return SizedBox.fromSize(key: Key('hidden-${button.name}'), size: size);
    final label = game.labels[button] ?? this.label;
    return SizedBox.fromSize(
      size: size,
      child: _PointerArea(
        onDownOrMove: (pointer, local) => pad.button(pointer, (Offset.zero & size).contains(local) ? button : null),
        onUp: pad.up,
        child: PressFlash<ControllerButton>(
          pressed: {if (on) button},
          shapeOf: (_, s) => Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height / 2))),
          child: CustomPaint(
            size: size,
            painter: SmallButtonPainter(look: look, pressed: on, player: player),
            // The label sits on the pill, so it goes where the pill did.
            child: Transform.translate(
              offset: padSquish(on),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: look.type.button.copyWith(color: look.colors.ink)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small button's pill (M13 step 8, rule 6): paper with an ink edge and the
/// hard shadow, filled with this phone's player colour and pushed in while
/// it's pressed. The label is a [Text] above it, so a tap still finds it.
class SmallButtonPainter extends CustomPainter {
  const SmallButtonPainter({required this.look, required this.pressed, this.player});

  /// The look the pad is drawn in.
  final ToyLook look;

  /// Whether the button is held now.
  final bool pressed;

  /// This phone's player, or null before the host gives them a number.
  final int? player;

  @override
  void paint(Canvas canvas, Size size) {
    final pill = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2)));
    final fill = pressed ? padPlayerColour(look.colors, player) : look.colors.paper;
    paintPadPart(canvas, pill, look: look, fill: fill, pressed: pressed);
  }

  @override
  bool shouldRepaint(SmallButtonPainter old) => old.look != look || old.pressed != pressed || old.player != player;
}
