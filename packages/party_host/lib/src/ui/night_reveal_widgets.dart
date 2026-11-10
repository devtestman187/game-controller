part of 'night_reveal_screen.dart';

/// One award's moment (frame 6): its picture on the left, and on the right who
/// won it and why, or "Not won tonight". Confetti falls behind a won one.
class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.outcome, required this.colour, required this.night, required this.players});

  final NightAwardOutcome outcome;

  /// The award's colour: its header's tint, its rosette's fill.
  final Color colour;

  /// The night, for the players it met who have since left, and the roster now.
  final NightState night;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Stack(
      children: [
        if (outcome.isWon)
          Positioned.fill(
            child: IgnorePointer(child: NightConfetti(key: const Key('nightRevealConfetti'))),
          ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ToySizes.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: nightRevealCardWidthPx),
              child: ToyCard(
                key: const Key('nightReveal'),
                header: outcome.award.title,
                headerColor: colour,
                padding: const EdgeInsets.all(ToySizes.space32),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NightDisc(
                      colour: colour,
                      icon: nightAwardIcon(outcome.award.picture),
                      size: look.sizes.buttonHeight * 2,
                    ),
                    const SizedBox(width: ToySizes.space24),
                    Flexible(
                      child: _AwardBody(outcome: outcome, night: night, players: players),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What the card says about the award: its winners and their reason, or the
/// kind word that nobody won it (design section 6).
class _AwardBody extends StatelessWidget {
  const _AwardBody({required this.outcome, required this.night, required this.players});

  final NightAwardOutcome outcome;
  final NightState night;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final heading = look.type.button.copyWith(color: colors.ink);
    final quiet = look.type.body.copyWith(color: colors.inkSoft);
    if (!outcome.isWon) {
      return Column(
        key: const Key('nightAwardMissed'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(NightText.notWon, style: heading),
          const SizedBox(height: ToySizes.space8),
          Text(outcome.award.line, style: quiet),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(NightText.winners(outcome.winners.length), style: quiet),
        const SizedBox(height: ToySizes.space8),
        for (final id in outcome.winners) _WinnerRow(who: _who(night, players, id)),
        const SizedBox(height: ToySizes.space16),
        Text(outcome.reason ?? outcome.award.line, style: heading),
        const SizedBox(height: ToySizes.space24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: heading.fontSize, color: colors.focus),
            const SizedBox(width: ToySizes.space8),
            Text(NightText.awardPoints(awardPoints), style: heading.copyWith(color: colors.good)),
          ],
        ),
      ],
    );
  }
}

/// A winner's badge and name, on their own line (frame 6): every player the
/// award is shared by gets one.
class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.who});

  final NightPlayer who;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ToySizes.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToyBadge(
            number: who.number,
            diameter: look.sizes.buttonHeight * rowBadgeShare,
            character: ToyCharacter.of(who.character, who.number),
          ),
          const SizedBox(width: ToySizes.space12),
          Text(
            NightText.playerName(who.nickname, who.number),
            style: look.type.button.copyWith(color: look.colors.ink),
          ),
        ],
      ),
    );
  }
}

/// Who a winner is: the roster's player, or the one the night remembers when
/// they have left (design section 4: their row stays, so their award does too).
NightPlayer _who(NightState night, List<GamePlayer> players, String id) {
  for (final player in players) {
    if (player.id == id) return (number: player.number, nickname: player.nickname, character: player.character);
  }
  return night.seen[id] ?? (number: 0, nickname: null, character: null);
}
