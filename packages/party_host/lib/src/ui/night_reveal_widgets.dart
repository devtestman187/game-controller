part of 'night_reveal_screen.dart';

/// How wide the reveal's badge is, in frame px (DESIGN section 4, the awards
/// reveal): the winner's badge or the award's disc on the card's left.
const nightRevealBadgePx = 190.0;

/// The award's name on the reveal, in frame px (DESIGN section 4: 52).
const nightRevealAwardPx = 52.0;

/// A winner's name on the reveal, in frame px (DESIGN section 4: 40), while
/// the award has one or two winners ([nightRevealWinnerPxFor]).
const nightRevealWinnerPx = 40.0;

/// How many winners keep the design's [nightRevealWinnerPx]: one or two (brief
/// fB's size tiers).
const nightRevealWinnerPxMaxWinners = 2;

/// A tied winner's name on the reveal, in frame px, when three share the
/// award: three 40 px lines plus the card's 188 px of other content need 358
/// of its 328 px of room at 640x360, 30 px too many (brief fB's size tiers).
const nightRevealTieWinnerPx = 32.0;

/// How many winners take [nightRevealTieWinnerPx]: three (brief fB's size
/// tiers).
const nightRevealTiePxMaxWinners = 3;

/// A tied winner's name on the reveal, in frame px, when four or more share
/// the award: above the frame's 20 px floor, and four 34 px rows plus the
/// card's 188 px of other content take 324 of its 328 px at 640x360 (brief
/// fB's size tiers).
const nightRevealTieManyWinnerPx = 24.0;

/// The size a winner's name takes when [winners] players share the award, in
/// frame px (brief fB): the design's [nightRevealWinnerPx] for one or two,
/// [nightRevealTieWinnerPx] for three and [nightRevealTieManyWinnerPx] for four
/// or more, so a tie keeps its names inside the card.
double nightRevealWinnerPxFor(int winners) => switch (winners) {
  <= nightRevealWinnerPxMaxWinners => nightRevealWinnerPx,
  <= nightRevealTiePxMaxWinners => nightRevealTieWinnerPx,
  _ => nightRevealTieManyWinnerPx,
};

/// How many winners a tie needs before its names take two columns: five, the
/// first count that no longer fits one column of the card at 640x360 (brief
/// fB).
const nightRevealTieColumnMinWinners = 5;

/// How many columns a tie's names take from
/// [nightRevealTieColumnMinWinners] on: two, so six 24 px names need three
/// rows of about 102 px rather than six rows of 204, which with the card's
/// 188 px of other content overflows its 328 px at 640x360 by 64 (brief fB).
const nightRevealTieColumns = 2;

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
    final tied = winner.copyWith(fontSize: nightRevealWinnerPxFor(winners.length));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RevealLine(outcome.award.title, style: name),
        const SizedBox(height: ToySizes.space8),
        // A tie gives each winner a line of their own, ellipsised rather than
        // wrapped, at the size its count takes; five or six share the lines in
        // two columns, so a tie of the night's six players still fits (brief
        // fB).
        _RevealNames(names: [for (final who in winners) NightText.playerName(who.nickname, who.number)], style: tied),
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

/// The winners' names on the card's right, one ellipsised line each: one
/// column for up to four, two columns of up to three for five or six (brief
/// fB).
class _RevealNames extends StatelessWidget {
  const _RevealNames({required this.names, required this.style});

  /// Each winner's line, in the order they won.
  final List<String> names;

  /// The size and colour every name takes ([nightRevealWinnerPxFor]).
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (names.length < nightRevealTieColumnMinWinners) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final name in names) _RevealLine(name, style: style)],
      );
    }
    // Column-major, the first column the taller half: five names make three
    // rows of three and two, six make three and three (brief fB).
    final rows = (names.length + 1) ~/ 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < nightRevealTieColumns; column++) ...[
          if (column > 0) const SizedBox(width: ToySizes.space16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final name in names.skip(column * rows).take(rows)) _RevealLine(name, style: style)],
            ),
          ),
        ],
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
