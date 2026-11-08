import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../providers.dart';

/// The ring a lit host button draws (m12 bug 1107f rule A): the look's focus
/// ring, as wide as the TV's focus ring was, so it reads from the couch.
const hostRingPx = ToySizes.focusRing;

/// What a host row, step or card that is a button looks like (m12 bug 1107f
/// rules A and B, in the look: M13 3b). At rest it is paper with the ink edge,
/// the look's corners and ink text. Lit — pressed, or focused while [showFocus]
/// says the focus look shows — it takes the focus fill and a [hostRingPx] focus
/// ring outside its ink edge.
///
/// The host's rows, steps and cards that are buttons all take their look from
/// here, so a phone and a TV light up the same way and there is one place to
/// change it. [fill] is what the button shows at rest; null is the look's paper.
ButtonStyle hostButtonLook(BuildContext context, {required bool showFocus, Color? fill}) {
  final look = ToyLookScope.of(context);
  final colors = look.colors;
  bool isLit(Set<WidgetState> states) =>
      states.contains(WidgetState.pressed) || (showFocus && states.contains(WidgetState.focused));
  final edge = BorderSide(color: colors.ink, width: look.sizes.outlineWidth);
  return ButtonStyle(
    side: WidgetStatePropertyAll(edge),
    foregroundColor: WidgetStatePropertyAll(colors.ink),
    shape: WidgetStateProperty.resolveWith((states) => HostEdgeBorder(look: look, isLit: isLit(states), side: edge)),
    backgroundColor: WidgetStateProperty.resolveWith((states) => isLit(states) ? colors.focus : fill ?? colors.paper),
  );
}

/// A card-shaped button's edge (M13 3b): the ink outline, and outside it the
/// focus ring while the button is lit, so a row or a card that is a button
/// shows the focus the way a [ToyButton] does.
class HostEdgeBorder extends OutlinedBorder {
  const HostEdgeBorder({required this.look, required this.isLit, super.side});

  /// The look the ring is drawn in.
  final ToyLook look;

  /// Whether the button is lit, which draws the focus ring.
  final bool isLit;

  /// The paper's rounded rect, [rect]'s own corners.
  static Path _paperPath(Rect rect) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(ToySizes.cardCorner)));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _paperPath(rect.deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _paperPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (isLit) {
      final ring = _paperPath(rect.inflate(hostRingPx));
      canvas.drawPath(ring, Paint()..color = look.colors.focus);
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side.width
          ..color = side.color,
      );
    }
    canvas.drawPath(
      _paperPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  OutlinedBorder copyWith({BorderSide? side}) => HostEdgeBorder(look: look, isLit: isLit, side: side ?? this.side);

  @override
  HostEdgeBorder scale(double t) => HostEdgeBorder(look: look, isLit: isLit, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      other is HostEdgeBorder && other.look == look && other.isLit == isLit && other.side == side;

  @override
  int get hashCode => Object.hash(look, isLit, side);
}

/// A host menu button (was `TvButton`: the host screens run on a phone too,
/// M12), drawn as the look's [ToyButton] with the look's good fill. On a
/// touch-first host it lights up under a thumb and no longer stays lit from the
/// focus ([hostFocusLookProvider], m12 bug 1107f).
class HostButton extends ConsumerWidget {
  const HostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
    this.compact = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;

  /// To move the focus here from code.
  final FocusNode? focusNode;

  /// Smaller, for a panel's title row: the look's dense button.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ToyButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      autofocus: autofocus,
      focusNode: focusNode,
      dense: compact,
      showFocus: ref.watch(hostFocusLookProvider),
    );
  }
}
