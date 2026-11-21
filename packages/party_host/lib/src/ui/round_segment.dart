import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'host_focus_ring.dart';
import 'host_shortcuts.dart';

/// A chip's height in a round segment, in frame px: it fits the frame's 64 px
/// header with the look's room above and below it.
const roundChipHeightPx = 48.0;

/// One chip of a [RoundSegment] (M16 phonehost1 S2, DESIGN section 4): the
/// [value] picking it means, and the [label] the chip says.
///
/// It is a plain value so the caller names its own choices and their words (the
/// night's "3 rounds" and "5 rounds"), and the segment stays a widget that only
/// draws what it is given.
@immutable
class RoundOption {
  const RoundOption({required this.value, required this.label});

  /// What picking this chip means, which [RoundSegment.onChanged] hears.
  final int value;

  /// What the chip says, in the frame's body type.
  final String label;
}

/// The night's round picker as a two-chip segment (M16 phonehost1 S2, DESIGN
/// section 4): the chosen chip in the look's focus yellow, the others on the
/// look's paper, in the header's right end.
///
/// A chip is a button like any other host control: a tap, the TV remote's
/// centre, Enter and a gamepad's A all pick it (PRD v2 T21), and it takes the
/// focus as the remote's directions pass over it, showing the host's focus
/// ring. The text is ink on both fills (design D12), so the chip reads in
/// Sunny and Night alike.
class RoundSegment extends StatelessWidget {
  const RoundSegment({super.key, required this.value, required this.onChanged, required this.options});

  /// The chosen chip's value; the chip whose [RoundOption.value] is this one is
  /// filled, and the others are not.
  final int value;

  /// What picking a chip does, or null for a segment nobody may change (the
  /// night already under way): every chip is then unpickable.
  final ValueChanged<int>? onChanged;

  /// The chips, in the order they show.
  final List<RoundOption> options;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: ToySizes.space8),
          _RoundChip(
            option: options[i],
            isSelected: options[i].value == value,
            onPressed: onChanged == null ? null : () => onChanged(options[i].value),
          ),
        ],
      ],
    );
  }
}

/// One chip: the look's pill, filled with the focus yellow while it is the
/// chosen one, that picks its option when tapped or activated.
class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.option, required this.isSelected, this.onPressed});

  final RoundOption option;

  /// Whether this is the chosen chip, which fills it with the focus yellow.
  final bool isSelected;

  /// What a tap or an activate key does, or null for a chip that can't be
  /// picked.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final style = ToyType.frame.button.copyWith(fontSize: ToyType.frame.body.fontSize, color: colors.ink);
    final onPressed = this.onPressed;
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      // The chip's tap sits under ExcludeSemantics (it is drawn and hit-tested
      // there), so a screen reader needs it named here: TalkBack on a phone host
      // finds the button and presses it (finding 10). Null with no callback, so
      // a night already under way offers nothing to press.
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
              child: SizedBox(
                height: roundChipHeightPx,
                child: CustomPaint(
                  painter: ToyPillPainter(look: look, fill: isSelected ? colors.focus : colors.paper),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16),
                    child: Center(
                      child: Text(
                        option.label,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
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
