import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../text/night_text.dart';
import 'host_button.dart';

/// The room the night's two way-on buttons may take at the frame's footer, in
/// frame px (DESIGN sections 1 and 3): a 960 px stage less its gutter either
/// side leaves 912 px in the footer, and the two labels' own buttons need less
/// than this, so the rest stays Thumby's corner.
const nightFooterButtonsWidthPx = 640.0;

/// The room between the night's two footer buttons, in frame px: the look's
/// own step, so the pair reads as one group.
const nightFooterButtonGapPx = ToySizes.space16;

/// The room a footer button keeps either side of its icon and label, in frame
/// px: the look's own padding, which the button draws its content inside.
const nightFooterButtonPaddingPx = 2 * ToySizes.space24;

/// The slack a measured button keeps past its label, in frame px: the label is
/// measured in the footer's text style and drawn in the button's own, so a
/// pixel of room keeps another font build's rounding from cutting it.
const nightFooterButtonSlackPx = 1.0;

/// How wide the night's footer button that says [label] is, in frame px: the
/// label measured with the font engine at the look's button type, plus the
/// button's padding either side and the icon's room (its size, the type's, and
/// the step after it), so the button is as wide as its content and its label is
/// drawn whole rather than cut to a width picked by hand.
double nightFooterButtonWidthFor(BuildContext context, String label) {
  // The label's own context, as the button draws it: the look's button type
  // over whatever default style the screen around it sets.
  final style = DefaultTextStyle.of(context).style.merge(ToyLookScope.of(context).type.button);
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final labelWidthPx = painter.width;
  painter.dispose();
  final fontSize = style.fontSize;
  final contentPx = nightFooterButtonPaddingPx + labelWidthPx + nightFooterButtonSlackPx;
  if (fontSize == null) return contentPx.ceilToDouble();
  return (contentPx + fontSize + ToySizes.space8).ceilToDouble();
}

/// The night's way-on buttons for the frame's footer (M16 phonehost2 S3, DESIGN
/// section 4): Shape Race, and the Bumper Round, which the Arena hosts (M14 b2).
///
/// They are the footer's buttons rather than the body's (rule 5: way-on buttons
/// never live in the body), so they are always on screen. The scoreboard and
/// the final scores offer the same pair (S4), so the two screens cannot drift
/// apart in what a night's next round may be.
class NightFooterButtons extends StatelessWidget {
  const NightFooterButtons({super.key, required this.onShapeRace, required this.onBumperRound, this.autofocus = false});

  /// Plays a Shape Race round: its puzzle pick and join screen follow.
  final VoidCallback onShapeRace;

  /// Plays a Bumper Round; null disables the button, as it was before the
  /// Arena could host one.
  final VoidCallback? onBumperRound;

  /// Whether Shape Race takes the focus when the screen opens: the night's
  /// way on is the button a remote or a phone finds first.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final shapeRaceWidthPx = nightFooterButtonWidthFor(context, HostText.shapeRace);
    final bumperWidthPx = nightFooterButtonWidthFor(context, NightText.bumperRound);
    return SizedBox(
      width: shapeRaceWidthPx + nightFooterButtonGapPx + bumperWidthPx,
      child: Row(
        children: [
          SizedBox(
            width: shapeRaceWidthPx,
            child: HostButton(
              key: const Key('nightShapeRace'),
              label: HostText.shapeRace,
              icon: Icons.extension,
              autofocus: autofocus,
              onPressed: onShapeRace,
            ),
          ),
          const SizedBox(width: nightFooterButtonGapPx),
          SizedBox(
            width: bumperWidthPx,
            child: HostButton(
              key: const Key('nightBumper'),
              label: NightText.bumperRound,
              icon: Icons.sports_baseball,
              onPressed: onBumperRound,
            ),
          ),
        ],
      ),
    );
  }
}
