import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' show PhoneText, RoboBadge, ToyBadge, ToyCharacter, ToyLookScope, ToySizes;
import 'package:protocol/protocol.dart';

/// The night's part of the result card, under the name row (M14 design section 9,
/// B-040): the points this round earned and the night's standings. On the night's
/// last round the standings give way to "Awards coming…" until the host sends the
/// night's end after its reveal; then the card shows the awards, the final standings
/// and the winner from that message (np2).
class ResultNight extends StatelessWidget {
  const ResultNight({super.key, required this.result, required this.number, this.end});

  final ViewResult result;

  /// This phone's player's number, or null when the phone has none.
  final int? number;

  /// The night's end the host sent, or null until it does.
  final NightEndMessage? end;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final points = result.points;
    final round = result.round;
    final lastRound = round != null && round == result.of;
    final night = lastRound ? end : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (points != null) ...[
          const SizedBox(height: ToySizes.space8),
          Text(
            PhoneText.pointsEarned(points),
            key: const Key('resultPoints'),
            textAlign: TextAlign.center,
            style: look.type.button.copyWith(color: look.colors.good),
          ),
        ],
        if (night != null)
          _NightEnd(end: night, number: number)
        else if (lastRound) ...[
          const SizedBox(height: ToySizes.space12),
          Text(
            PhoneText.awardsComing,
            key: const Key('resultAwardsComing'),
            style: look.type.body.copyWith(color: look.colors.inkSoft),
          ),
        ] else if (result.standings.isNotEmpty) ...[
          const SizedBox(height: ToySizes.space12),
          Text(PhoneText.standings, style: look.type.body.copyWith(color: look.colors.inkSoft)),
          const SizedBox(height: ToySizes.space4),
          for (final standing in result.standings) _StandingRow(standing: standing, own: standing.number == number),
        ],
      ],
    );
  }
}

/// The last round's part of the card once the host has sent the night's end (np2):
/// the awards, the final standings and who won the night.
class _NightEnd extends StatelessWidget {
  const _NightEnd({required this.end, required this.number});

  final NightEndMessage end;

  /// This phone's player's number, or null when the phone has none.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final winner = _winnerLine(end.standings, number);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (end.awards.isNotEmpty) ...[
          const SizedBox(height: ToySizes.space12),
          Text(PhoneText.awardsHeading, style: look.type.body.copyWith(color: look.colors.inkSoft)),
          const SizedBox(height: ToySizes.space4),
          for (final award in end.awards) _AwardRow(award: award, standings: end.standings),
        ],
        if (end.standings.isNotEmpty) ...[
          const SizedBox(height: ToySizes.space12),
          Text(PhoneText.standings, style: look.type.body.copyWith(color: look.colors.inkSoft)),
          const SizedBox(height: ToySizes.space4),
          for (final standing in end.standings) _StandingRow(standing: standing, own: standing.number == number),
        ],
        if (winner != null) ...[
          const SizedBox(height: ToySizes.space12),
          Text(
            winner,
            key: const Key('resultNightWinner'),
            textAlign: TextAlign.center,
            style: look.type.button.copyWith(color: look.colors.good),
          ),
        ],
      ],
    );
  }

  /// The night's winner line: "You won the night!" when this phone's player is among the
  /// top standings, else the top players' names joined by "and" (a tie names both). Null
  /// when there are no standings.
  static String? _winnerLine(List<ViewStanding> standings, int? number) {
    if (standings.isEmpty) return null;
    final top = standings.map((s) => s.points).reduce((a, b) => a > b ? a : b);
    final winners = standings.where((s) => s.points == top).toList();
    if (winners.any((s) => s.number == number)) return PhoneText.youWonNight;
    final names = winners.map((s) => PhoneText.playerName(s.name, s.number));
    return PhoneText.nightWinner(names.join(' and '));
  }
}

/// One of the night's awards on the card (np2): its name, its winners' names looked up
/// by their IDs in the night's standings, and its points; "Not won tonight" when nobody
/// won it.
class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award, required this.standings});

  final NightAwardRow award;

  /// The night's final standings, which name the award's winners by ID.
  final List<ViewStanding> standings;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final names = [
      for (final id in award.winners)
        for (final standing in standings)
          if (standing.id == id) PhoneText.playerName(standing.name, standing.number),
    ];
    final winners = names.isEmpty ? PhoneText.awardNotWon : names.join(' and ');
    return Text(
      PhoneText.awardLine(award.name, winners, award.points),
      key: Key('resultAward-${award.id}'),
      style: look.type.body.copyWith(color: look.colors.ink),
    );
  }
}

/// The player's own badge on the result card: the look's toy disc, wearing the
/// character the host gave them.
class ResultBadge extends StatelessWidget {
  const ResultBadge({super.key, required this.toy, required this.number});

  final ToyCharacter toy;
  final int number;

  @override
  Widget build(BuildContext context) => ToyBadge(number: number, diameter: _diameter, character: toy);

  static const _diameter = 32.0;
}

/// One row of the night's standings: the character, the name and the points.
class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing, required this.own});

  final ViewStanding standing;

  /// Whether this row is this phone's player.
  final bool own;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final style = look.type.body.copyWith(color: look.colors.ink, fontWeight: own ? FontWeight.bold : null);
    // A row the host left unnamed is "Player N", as the lobby list says it
    // (M16 identity); Robo's row has its own name.
    final name = PhoneText.playerName(standing.name, standing.number);
    return Padding(
      key: Key('standing-${standing.number}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Robo wears the robot disc the TV gives it, never a player's badge
          // (m14 r5 9).
          if (standing.isRobo)
            RoboBadge(number: standing.number, size: _diameter)
          else
            ToyBadge(
              number: standing.number,
              diameter: _diameter,
              character: ToyCharacter.of(standing.character, standing.number),
            ),
          const SizedBox(width: ToySizes.space8),
          Expanded(
            child: Text(name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text('${standing.points}', key: Key('standingPoints-${standing.number}'), style: style),
        ],
      ),
    );
  }

  /// The row's badge, a little smaller than the card's own.
  static const _diameter = 24.0;
}
