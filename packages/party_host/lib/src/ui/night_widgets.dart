import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_awards.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import 'host_button.dart';

/// How wide one of the night's award cards is, in logical pixels: three fit
/// inside the start card, as the mock-up draws them (frame 2).
const nightAwardCardWidthPx = 300.0;

/// How wide the night's two game buttons are, in logical pixels (frame 2): they
/// wrap onto two lines on a phone's host screen rather than spill off it.
const nightGameButtonWidthPx = 460.0;

/// How strong a leaver's row is on the scoreboard (design section 4): the row
/// stays, greyed, and comes back to full strength if they rejoin.
const nightAwayOpacity = 0.45;

/// The icon an award's picture key draws (design section 6). Job c2 draws the
/// award's own larger picture in the reveal, from the same key.
IconData nightAwardIcon(NightAwardPicture picture) => switch (picture) {
  NightAwardPicture.sharpshooter => Icons.adjust,
  NightAwardPicture.helper => Icons.volunteer_activism,
  NightAwardPicture.cat => Icons.pets,
  NightAwardPicture.snap => Icons.bolt,
  NightAwardPicture.comeback => Icons.trending_up,
  NightAwardPicture.coin => Icons.monetization_on,
  NightAwardPicture.trophy => Icons.emoji_events,
  NightAwardPicture.retry => Icons.replay,
  NightAwardPicture.shove => Icons.front_hand,
  NightAwardPicture.bump => Icons.sports_baseball,
  NightAwardPicture.gold => Icons.paid,
  NightAwardPicture.steady => Icons.savings,
};

/// The crown's path in a [size] box: the night's winner wears it on the final
/// scores (frame 7), and the picker's Party night card draws one too (frame 1).
Path crownPath(Size size) {
  final (w, h) = (size.width, size.height);
  return Path()
    ..moveTo(0, h)
    ..lineTo(w * 0.06, h * 0.18)
    ..lineTo(w * 0.3, h * 0.62)
    ..lineTo(w * 0.5, 0)
    ..lineTo(w * 0.7, h * 0.62)
    ..lineTo(w * 0.94, h * 0.18)
    ..lineTo(w, h)
    ..close();
}

/// A toy crown in the look's focus yellow, for the night's winner.
class NightCrown extends StatelessWidget {
  const NightCrown({super.key, this.size = 44});

  /// How wide the crown is; it is 0.7 of that high.
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 0.7),
    painter: _NightCrownPainter(look: ToyLookScope.of(context)),
  );
}

class _NightCrownPainter extends CustomPainter {
  const _NightCrownPainter({required this.look});

  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) => toyShape(
    canvas,
    crownPath(size),
    look.colors.focus,
    ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth),
    shade: look.shade,
  );

  @override
  bool shouldRepaint(_NightCrownPainter oldDelegate) => oldDelegate.look != look;
}

/// The look's sticker disc with an icon on it: an award's picture on its card
/// (frame 2) and the cat's paw beside the start card's cat line.
class NightDisc extends StatelessWidget {
  const NightDisc({super.key, required this.colour, required this.icon, this.size = 44});

  /// The disc's fill, in the look's palette.
  final Color colour;

  /// What stands on the disc.
  final IconData icon;

  /// How wide the disc is.
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colour,
          border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
        ),
        child: Icon(icon, size: size * 0.55, color: look.colors.paper),
      ),
    );
  }
}

/// One of the night's three awards on the start card (frame 2): its name in the
/// header, its picture on a rosette and the one line that says who wins it.
class NightAwardCard extends StatelessWidget {
  const NightAwardCard({super.key, required this.award, required this.colour});

  /// The award this card names.
  final NightAward award;

  /// The award's colour: the header's tint and the rosette's fill.
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return SizedBox(
      width: nightAwardCardWidthPx,
      child: ToyCard(
        header: award.title,
        headerColor: Color.alphaBlend(colour.withValues(alpha: 0.3), colors.paper),
        padding: const EdgeInsets.all(ToySizes.space12),
        popIn: false,
        child: Row(
          children: [
            NightDisc(colour: colour, icon: nightAwardIcon(award.picture), size: look.sizes.buttonHeight * 0.8),
            const SizedBox(width: ToySizes.space8),
            Expanded(
              child: Text(
                award.line,
                style: look.type.body.copyWith(color: colors.inkSoft),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner over the scoreboard before the night's last round (frame 5):
/// "Last round: double points!", in the look's focus yellow with a star at each
/// end, so the words are never carried by colour alone (G5).
class NightLastRoundBanner extends StatelessWidget {
  const NightLastRoundBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final style = look.type.button.copyWith(color: colors.ink);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16, vertical: ToySizes.space8),
      decoration: BoxDecoration(
        color: colors.focus,
        border: Border.all(color: colors.ink, width: look.sizes.outlineWidth),
        borderRadius: BorderRadius.circular(ToySizes.cardCorner),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: style.fontSize, color: colors.ink),
          const SizedBox(width: ToySizes.space8),
          Flexible(child: Text(NightText.lastRoundBanner, style: style)),
          const SizedBox(width: ToySizes.space8),
          Icon(Icons.star, size: style.fontSize, color: colors.ink),
        ],
      ),
    );
  }
}

/// The two buttons that pick the next round (design section 2 N6): Shape Race,
/// and the Bumper Round, live now that the Arena reports its rounds (M14 b2).
/// A build that turns [nightBumperRoundReady] off waits with "Soon" beside the
/// disabled button, as the mock-up's frame 2 drew it.
class NightGameButtons extends StatelessWidget {
  const NightGameButtons({super.key, required this.onShapeRace, required this.onBumperRound, this.autofocus = false});

  /// Plays a Shape Race round: its puzzle pick and join screen follow.
  final VoidCallback onShapeRace;

  /// Plays a Bumper Round; null disables the button.
  final VoidCallback? onBumperRound;

  /// Whether Shape Race takes the focus first.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final soon = onBumperRound == null;
    return Wrap(
      spacing: ToySizes.space12,
      runSpacing: ToySizes.space12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: nightGameButtonWidthPx,
          child: HostButton(
            key: const Key('nightShapeRace'),
            label: HostText.shapeRace,
            icon: Icons.extension,
            autofocus: autofocus,
            onPressed: onShapeRace,
          ),
        ),
        SizedBox(
          width: nightGameButtonWidthPx,
          child: HostButton(
            key: const Key('nightBumper'),
            label: NightText.bumperRound,
            icon: Icons.sports_baseball,
            onPressed: onBumperRound,
          ),
        ),
        // A disabled button says why in a word beside it (frame 2): a dashed
        // edge alone would leave a child waiting for it to light up.
        if (soon) Text(NightText.soon, style: look.type.body.copyWith(color: look.colors.onBackground)),
      ],
    );
  }
}

/// The question the scoreboard asks before a night is thrown away (design
/// section 4): "End the party night?" with Yes and No, No taking the focus so a
/// pressed thumb that presses again stays in the night.
class NightLeaveDialog extends StatelessWidget {
  const NightLeaveDialog({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ToyCard(
      key: const Key('endNightDialog'),
      header: NightText.endNight,
      padding: const EdgeInsets.all(ToySizes.space24),
      popIn: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HostButton(
            key: const Key('endNightNo'),
            label: NightText.no,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: ToySizes.space12),
          HostButton(
            key: const Key('endNightYes'),
            label: NightText.yes,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
}
