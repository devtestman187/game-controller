import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' show PhoneText, RoboBadge, ToyBadge, ToyCharacter, ToyLookScope, ToySizes;
import 'package:protocol/protocol.dart';

/// The night's part of the result card, under the name row (M14 design section 9,
/// B-040): the points this round earned and the night's standings. On the night's
/// last round the standings give way to "Awards coming…": the host sends the final
/// standings and the winner after its reveal, and the phone shows them then (np2).
class ResultNight extends StatelessWidget {
  const ResultNight({super.key, required this.result, required this.number});

  final ViewResult result;

  /// This phone's player's number, or null when the phone has none.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final points = result.points;
    final round = result.round;
    final lastRound = round != null && round == result.of;
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
        if (lastRound) ...[
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
