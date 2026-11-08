import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sticker_shadow.dart';
import 'toy_look.dart';
import 'toy_look_scope.dart';
import 'toy_sizes.dart';

/// The thin ink edge round the focus ring (design section 4).
const _ringEdgeWidth = 1.5;

/// The disabled pill's edge: 6 px of ink, then 4 px of paper (design section
/// 4's dashed edge).
const _dashOn = 6.0;
const _dashOff = 4.0;

/// How far inside the button's box the pill sits: the ink edge's outer half,
/// the focus ring and half of its own edge, so the whole look stays in the
/// box whatever the state.
double _pillInsetOf(ToyLook look) => look.sizes.outlineWidth / 2 + ToySizes.focusRing + _ringEdgeWidth / 2;

/// The scale the focus bounce reaches for its peak (design section 4).
const _bouncePeak = 1.06;

/// The scale a focused button rests at (design section 4).
const _focusScale = 1.04;

/// A menu button in the look (design section 4): a fat pill with the fill, an
/// ink edge and the hard shadow, which squishes when pressed and bounces when
/// the focus lands on it.
///
/// It replaces `HostButton` (step 3). Activation runs through the framework's
/// [ActivateIntent], so a tap, Enter, Space, the TV remote's centre and the
/// gamepad's A all press it, and the TV's D-pad moves the focus to it as it
/// did before (M12 bug 1107f kept the focus look off a touch-first host, which
/// is what [showFocus] false is for).
class ToyButton extends StatefulWidget {
  const ToyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.focusNode,
    this.autofocus = false,
    this.showFocus = true,
  });

  /// What the button says, in the look's button type and ink (design D12).
  final String label;

  /// What a press does; null makes the button a disabled, dashed one.
  final VoidCallback? onPressed;

  /// The pill's fill, or the palette's good green.
  final Color? color;

  /// An icon before the label, in ink.
  final IconData? icon;

  /// To move the focus here from code.
  final FocusNode? focusNode;

  /// Whether the focus moves here when the screen opens.
  final bool autofocus;

  /// Whether the focus draws the ring and the bounce: false on a touch-first
  /// host, where the focus look isn't shown (M12 bug 1107f).
  final bool showFocus;

  @override
  State<ToyButton> createState() => _ToyButtonState();
}

class _ToyButtonState extends State<ToyButton> with SingleTickerProviderStateMixin {
  /// The focus bounce's length (design section 4): 1.0 to 1.06 to 1.04.
  static const _bounceDuration = Duration(milliseconds: 220);

  late final AnimationController _bounce = AnimationController(vsync: this, duration: _bounceDuration);

  /// The bounce: out to [_bouncePeak] over half the time, then back to
  /// [_focusScale].
  late final Animation<double> _bounceScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: _bouncePeak).chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: _bouncePeak, end: _focusScale).chain(CurveTween(curve: Curves.easeIn)),
      weight: 1,
    ),
  ]).animate(_bounce);

  /// The keys that activate a focused button: Enter, Space, the TV remote's
  /// centre and the gamepad's A. The app's own shortcuts map them the same
  /// way; naming them here keeps the button right wherever it is used.
  static final _activateKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
  };

  static final _activateShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  };

  late final Action<Intent> _activateAction = CallbackAction<ActivateIntent>(
    onInvoke: (intent) {
      _activate();
      return null;
    },
  );

  bool _isFocused = false;
  bool _isPressed = false;

  /// Whether an activate key is still down, so its auto-repeat doesn't press
  /// the button again for every repeat.
  bool _isKeyHeld = false;

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    setState(() {
      _isFocused = focused;
      if (!focused) _release();
    });
    if (focused && widget.showFocus && ToyLookScope.of(context).effects) {
      _bounce.forward(from: 0);
    }
  }

  /// Presses the button for a tap or an activate key: the look goes squished
  /// and, for a key, the callback runs once per press.
  void _activate() {
    final onPressed = widget.onPressed;
    if (onPressed == null || _isKeyHeld) return;
    _isKeyHeld = true;
    _press();
    onPressed();
  }

  void _press() {
    if (!_isPressed) setState(() => _isPressed = true);
  }

  void _release() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  /// Lets go of the press when the activate key lifts. The key's down is taken
  /// by the shortcuts above, but their release is not, so it reaches this
  /// button from below.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent && _activateKeys.contains(event.logicalKey)) {
      _isKeyHeld = false;
      _release();
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _handleKeyEvent,
          child: FocusableActionDetector(
            enabled: enabled,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            shortcuts: _activateShortcuts,
            actions: {ActivateIntent: _activateAction},
            onFocusChange: _handleFocusChange,
            child: AnimatedBuilder(
              animation: _bounce,
              builder: (context, pill) => Transform.scale(scale: _scaleFor(look), child: pill),
              child: _buttonFace(look, enabled),
            ),
          ),
        ),
      ),
    );
  }

  /// The scale the pill is drawn at: 1.0 unless the focus shows, then the
  /// bounce's 1.0 → 1.06 → 1.04, or 1.04 at once with effects off.
  double _scaleFor(ToyLook look) {
    if (!widget.showFocus || !_isFocused) return 1;
    return look.effects ? _bounceScale.value : _focusScale;
  }

  /// The button itself: the pill, the pointer and the content, which moves
  /// with the pill while it is pressed.
  Widget _buttonFace(ToyLook look, bool enabled) {
    return SizedBox(
      height: look.sizes.buttonHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _press() : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? _release : null,
        onTap: widget.onPressed,
        child: CustomPaint(
          painter: ToyButtonPainter(
            look: look,
            fill: widget.color ?? look.colors.good,
            isEnabled: enabled,
            isFocused: widget.showFocus && _isFocused,
            isPressed: _isPressed,
          ),
          child: Transform.translate(offset: _isPressed ? ToySizes.shadowOffset : Offset.zero, child: _content(look)),
        ),
      ),
    );
  }

  /// The icon and the label, in ink, with the look's button type.
  Widget _content(ToyLook look) {
    final icon = widget.icon;
    final colors = look.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: look.type.button.fontSize, color: colors.ink),
            const SizedBox(width: ToySizes.space8),
          ],
          DefaultTextStyle.merge(
            style: look.type.button.copyWith(color: colors.ink),
            child: Text(widget.label),
          ),
        ],
      ),
    );
  }
}

/// What [ToyButton] draws (design section 4): the hard shadow, the pill with
/// its fill and ink edge, the focus ring, and the pressed position. It's a
/// painter of its own so a test can check what each state draws.
class ToyButtonPainter extends CustomPainter {
  const ToyButtonPainter({
    required this.look,
    required this.fill,
    required this.isEnabled,
    required this.isFocused,
    required this.isPressed,
  });

  /// The look the button is drawn in.
  final ToyLook look;

  /// The pill's fill while the button is enabled.
  final Color fill;

  /// Whether the button can be pressed; a disabled one is paper with a dashed
  /// edge and no shadow.
  final bool isEnabled;

  /// Whether the focus ring is drawn, which the button decides with its
  /// [ToyButton.showFocus] as well as the focus.
  final bool isFocused;

  /// Whether the pill is pushed in: no shadow, and the pill a shadow-offset
  /// lower and to the right.
  final bool isPressed;

  /// The pill's rect in a button [size] across.
  Rect pillRect(Size size) {
    final rect = (Offset.zero & size).deflate(_pillInsetOf(look));
    return isPressed ? rect.shift(ToySizes.shadowOffset) : rect;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = pillRect(size);
    final pill = _pill(rect);
    if (isEnabled && !isPressed) paintStickerShadow(canvas, pill, look.colors.ink);
    if (isFocused) _paintRing(canvas, rect);
    canvas.drawPath(pill, Paint()..color = isEnabled ? fill : look.colors.paper);
    if (isEnabled) {
      canvas.drawPath(pill, _edge());
    } else {
      _paintDashed(canvas, pill);
    }
  }

  /// A focus-coloured ring outside the pill's ink edge, itself edged in ink.
  void _paintRing(Canvas canvas, Rect rect) {
    final ring = _pill(rect.inflate(look.sizes.outlineWidth / 2 + ToySizes.focusRing));
    canvas.drawPath(ring, Paint()..color = look.colors.focus);
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringEdgeWidth
        ..color = look.colors.ink,
    );
  }

  /// The disabled pill's dashed edge: [_dashOn] of ink, then [_dashOff] of gap,
  /// round the pill.
  void _paintDashed(Canvas canvas, Path pill) {
    final paint = _edge();
    for (final metric in pill.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dashOn + _dashOff) {
        canvas.drawPath(metric.extractPath(start, math.min(start + _dashOn, metric.length)), paint);
      }
    }
  }

  Paint _edge() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = look.sizes.outlineWidth
    ..color = look.colors.ink;

  @override
  bool shouldRepaint(ToyButtonPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.fill != fill ||
      oldDelegate.isEnabled != isEnabled ||
      oldDelegate.isFocused != isFocused ||
      oldDelegate.isPressed != isPressed;
}

/// The stadium shape filling [rect]: a pill, since its corners are half its
/// height (design section 4).
Path _pill(Rect rect) => Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)));
