part of 'night_reveal_screen.dart';

/// How wide the reveal's badge is, in frame px (DESIGN section 4, the awards
/// reveal): the winner's badge or the award's disc on the card's left.
const nightRevealBadgePx = 190.0;

/// The award's name on the reveal, in frame px (DESIGN section 4: 52).
const nightRevealAwardPx = 52.0;

/// A winner's name on the reveal, in frame px (DESIGN section 4: 40).
const nightRevealWinnerPx = 40.0;

/// The reason the award was won, in frame px (DESIGN section 4: 26).
const nightRevealReasonPx = 26.0;

/// How wide the winner's crown is against the badge, so it sits on the disc's
/// top edge at any size.
const nightRevealCrownShare = 0.32;

/// How many lines the reason may take: a tie has the names' room to keep, so
/// the reason stays to two lines and ellipsises (brief S5).
const nightRevealReasonLines = 2;

/// One award's moment (DESIGN section 4, frame 6): one full-width card, the
/// big badge on the left, and on the right who won it and why, or "Not won
/// tonight". Confetti falls behind a won one.
class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.outcome, required this.colour, required this.night, required this.players});

  final NightAwardOutcome outcome;

  /// The award's colour: its disc's fill, when nobody won it.
  final Color colour;

  /// The night, for the players it met who have since left, and the roster now.
  final NightState night;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (outcome.isWon)
          const Positioned.fill(
            child: IgnorePointer(child: NightConfetti(key: Key('nightRevealConfetti'))),
          ),
        // The card fills the stage: the frame's width less the frame's gutter
        // at each side, and no fixed width anywhere (DESIGN section 1,
        // rule 4). It is given the body's width, so its width never follows the
        // length of the award's name.
        LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SizedBox(
              width: constraints.maxWidth,
              child: ToyCard(
                key: const Key('nightReveal'),
                padding: const EdgeInsets.all(ToySizes.space32),
                child: Row(
                  children: [
                    _RevealBadge(outcome: outcome, colour: colour, night: night, players: players),
                    const SizedBox(width: ToySizes.space32),
                    Expanded(
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

/// The reveal's badge on the card's left (DESIGN section 4): the winner's own
/// badge with the crown on it, or the award's disc when nobody won it.
class _RevealBadge extends StatelessWidget {
  const _RevealBadge({required this.outcome, required this.colour, required this.night, required this.players});

  final NightAwardOutcome outcome;
  final Color colour;
  final NightState night;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    if (!outcome.isWon) {
      return NightDisc(colour: colour, icon: nightAwardIcon(outcome.award.picture), size: nightRevealBadgePx);
    }
    // A shared award shows the first winner's badge: their names each have
    // their own line beside it (brief S5).
    final who = _who(night, players, outcome.winners.first);
    return SizedBox.square(
      dimension: nightRevealBadgePx,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          PlayerBadge(number: who.number, size: nightRevealBadgePx, character: who.character),
          const Positioned(top: 0, child: NightCrown(size: nightRevealBadgePx * nightRevealCrownShare)),
        ],
      ),
    );
  }
}

/// What the card says about the award: its name, its winners and their reason,
/// or the kind word that nobody won it (design section 6).
class _AwardBody extends StatelessWidget {
  const _AwardBody({required this.outcome, required this.night, required this.players});

  final NightAwardOutcome outcome;
  final NightState night;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final name = ToyType.frame.title.copyWith(fontSize: nightRevealAwardPx, color: colors.ink);
    final winner = ToyType.frame.title.copyWith(fontSize: nightRevealWinnerPx, color: colors.ink);
    final reason = ToyType.frame.body.copyWith(fontSize: nightRevealReasonPx, color: colors.inkSoft);
    if (!outcome.isWon) {
      return Column(
        key: const Key('nightAwardMissed'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RevealLine(outcome.award.title, style: name),
          const SizedBox(height: ToySizes.space8),
          _RevealLine(NightText.notWon, style: winner),
          const SizedBox(height: ToySizes.space8),
          _RevealLine(outcome.award.line, style: reason, maxLines: nightRevealReasonLines),
        ],
      );
    }
    final winners = [for (final id in outcome.winners) _who(night, players, id)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RevealLine(outcome.award.title, style: name),
        const SizedBox(height: ToySizes.space8),
        // A tie gives each winner a line of their own, ellipsised rather than
        // wrapped, so the card keeps its height at two names (brief S5).
        for (final who in winners) _RevealLine(NightText.playerName(who.nickname, who.number), style: winner),
        const SizedBox(height: ToySizes.space16),
        _RevealLine(outcome.reason ?? outcome.award.line, style: reason, maxLines: nightRevealReasonLines),
        const SizedBox(height: ToySizes.space16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: nightRevealReasonPx, color: colors.focus),
            const SizedBox(width: ToySizes.space8),
            Text(NightText.awardPoints(awardPoints), style: reason.copyWith(color: colors.good)),
          ],
        ),
      ],
    );
  }
}

/// One line of the card's right side, ellipsised rather than wrapped, so a
/// long award name, nickname or reason stays inside the card.
class _RevealLine extends StatelessWidget {
  const _RevealLine(this.text, {required this.style, this.maxLines = 1});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
}

/// Who a winner is: the roster's player, or the one the night remembers when
/// they have left (design section 4: their row stays, so their award does too).
NightPlayer _who(NightState night, List<GamePlayer> players, String id) {
  for (final player in players) {
    if (player.id == id) return (number: player.number, nickname: player.nickname, character: player.character);
  }
  return night.seen[id] ?? (number: 0, nickname: null, character: null);
}
