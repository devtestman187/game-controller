import 'dart:math';

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_awards.dart';
import '../text/night_text.dart';
import 'host_button.dart';

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

/// The confetti round the awards' reveal and the final scores (frames 6 and 7):
/// small tilted pieces in the look's own colours, still, so a menu pays no
/// frames for them, and drawn from a fixed seed so they never jump between
/// frames. The reveal and the scoreboard put it behind their card.
class NightConfetti extends StatelessWidget {
  const NightConfetti({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _NightConfettiPainter(look: ToyLookScope.of(context)));
}

/// How many pieces the scatter draws, how big one is in logical pixels, the
/// seed it scatters from, and how many of the look's player colours it uses.
const _confettiPieces = 44;
const _confettiWidthPx = 10.0;
const _confettiHeightPx = 6.0;
const _confettiSeed = 7;
const _confettiColourSlots = 6;

class _NightConfettiPainter extends CustomPainter {
  const _NightConfettiPainter({required this.look});

  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(_confettiSeed);
    final colours = [
      for (var slot = 1; slot <= _confettiColourSlots; slot++) look.colors.player(slot),
      look.colors.focus,
    ];
    final paint = Paint();
    final piece = Rect.fromCenter(center: Offset.zero, width: _confettiWidthPx, height: _confettiHeightPx);
    for (var i = 0; i < _confettiPieces; i++) {
      final at = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(random.nextDouble() * 2 * pi)
        ..drawRect(piece, paint..color = colours[i % colours.length])
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_NightConfettiPainter oldDelegate) => oldDelegate.look != look;
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
