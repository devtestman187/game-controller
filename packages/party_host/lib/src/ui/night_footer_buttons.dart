import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../text/night_text.dart';
import 'host_button.dart';

/// The room the night's two way-on buttons take at the frame's footer, in
/// frame px (DESIGN sections 1 and 3): a 960-wide footer keeps 480 px for its
/// buttons beside Thumby's corner, and the night's two share it.
const nightFooterButtonsWidthPx = 480.0;

/// The room between the night's two footer buttons, in frame px: the look's
/// own step, so the pair reads as one group.
const nightFooterButtonGapPx = ToySizes.space16;

/// How much width one of the night's footer buttons has, in frame px: half of
/// [nightFooterButtonsWidthPx] less the gap, so the two are the same width and
/// the pair fits the footer's budget. A label too long for it is ellipsised.
const nightFooterButtonWidthPx = (nightFooterButtonsWidthPx - nightFooterButtonGapPx) / 2;

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
    return SizedBox(
      width: nightFooterButtonsWidthPx,
      child: Row(
        children: [
          SizedBox(
            width: nightFooterButtonWidthPx,
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
            width: nightFooterButtonWidthPx,
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
