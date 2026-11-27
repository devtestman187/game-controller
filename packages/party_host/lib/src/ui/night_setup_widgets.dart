import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'host_focus_ring.dart';
import 'host_frame.dart';
import 'host_shortcuts.dart';
import 'round_segment.dart';

/// The size a touch target must have on the device, in logical pixels (the owner's rule, PRD acceptance).
const nightSetupTouchDp = 48.0;

/// The smallest text a setup chip shows on the device, in logical pixels: a phone's frame is drawn at about a third of
/// its size, so the chip's own type would be too small to read there.
const nightSetupTextDp = 14.0;

/// [normalPx] in frame px, or what [deviceDp] is in frame px on this device when that is more: the setup's chips are
/// as big as they are on a TV, and never smaller than [deviceDp] on a phone, whose frame is scaled down.
double nightSetupAtLeastDp(BuildContext context, double normalPx, double deviceDp) {
  final scale = HostFrameInfo.maybeOf(context)?.scale ?? 1;
  return math.max(normalPx, deviceDp / scale);
}

/// The body type of the night setup's text outside the chips (labels, help lines, the cat note) in [color]: the frame's
/// body size, or the [nightSetupTextDp] floor on the device where that is bigger, as the chips' text is.
TextStyle nightSetupBodyStyle(BuildContext context, Color color) {
  final bodySizePx = ToyType.frame.body.fontSize ?? roundChipHeightPx;
  return ToyType.frame.body.copyWith(
    fontSize: nightSetupAtLeastDp(context, bodySizePx, nightSetupTextDp),
    color: color,
  );
}

/// One setting of the night setup: its [label] above a [Wrap] of [children] (chips), and an optional [help] line under
/// them. The wrap puts a chip on a new line where the frame is narrow, so no row overflows.
class NightSetupRow extends StatelessWidget {
  const NightSetupRow({super.key, required this.label, required this.children, this.help});

  /// What the row sets, above its chips.
  final String label;

  /// The row's chips, in the order they show.
  final List<Widget> children;

  /// A line under the chips that says what the chosen one does, or null for none.
  final String? help;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final style = nightSetupBodyStyle(context, colors.onBackground);
    final help = this.help;
    return Padding(
      padding: const EdgeInsets.only(bottom: ToySizes.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: style),
          const SizedBox(height: ToySizes.space8),
          Wrap(spacing: ToySizes.space8, runSpacing: ToySizes.space8, children: children),
          if (help != null) ...[const SizedBox(height: ToySizes.space8), Text(help, style: style)],
        ],
      ),
    );
  }
}

/// One chip of the night setup: the look's pill in the focus yellow while it is [isSelected], on the look's paper
/// otherwise. It is at least [nightSetupTouchDp] tall and wide on the device and its text at least [nightSetupTextDp]
/// (on a TV, where the frame is scaled up, it keeps the normal chip size). Tapping it, or the remote's centre, Enter
/// or a gamepad's A, calls [onPressed]; a null [onPressed] makes the chip unpickable.
class NightSetupChip extends StatelessWidget {
  const NightSetupChip({super.key, required this.label, required this.isSelected, required this.onPressed});

  /// What the chip says, whole: a long label wraps rather than being cut.
  final String label;

  /// Whether this is the chosen chip.
  final bool isSelected;

  /// What picking the chip does, or null for a chip nobody may pick (the night under way).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final bodySizePx = ToyType.frame.body.fontSize ?? roundChipHeightPx;
    final style = ToyType.frame.button.copyWith(
      fontSize: nightSetupAtLeastDp(context, bodySizePx, nightSetupTextDp),
      color: colors.ink,
    );
    final touchPx = nightSetupAtLeastDp(context, roundChipHeightPx, nightSetupTouchDp);
    final onPressed = this.onPressed;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: HostFocusRing(
          child: FocusableActionDetector(
            enabled: onPressed != null,
            shortcuts: hostActivateShortcuts,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  onPressed?.call();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: touchPx, minWidth: touchPx),
                child: CustomPaint(
                  painter: ToyPillPainter(look: look, fill: isSelected ? colors.focus : colors.paper),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16),
                    child: Center(
                      widthFactor: 1,
                      child: Text(label, style: style, textAlign: TextAlign.center),
                    ),
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
