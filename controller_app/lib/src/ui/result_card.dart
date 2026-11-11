import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart'
    show PhoneText, PuzzlePhoto, RoboBadge, ToyBadge, ToyCard, ToyCharacter, ToyLookScope, ToySizes;
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../providers.dart';

/// This phone's own result of the round it just drew (M14 design section 9,
/// mock-up 12): the card over the last frame, with the side's picture as the
/// framed photo the host's card shows (design 3a), the outcome and the time,
/// its points in a night, and the night's standings. "Waiting for the host to
/// pick what's next." under it.
///
/// It covers the game and the pad: nothing is pressed here once the round is
/// over. The card goes on the next `view_start`, or on the host's later
/// `view_end` without a result ([viewResultProvider]).
class ResultCard extends ConsumerWidget {
  const ResultCard({super.key, required this.result});

  final ViewResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final number = ref.watch(clientStateProvider.select((s) => s.player));
    final character = ref.watch(clientStateProvider.select((s) => s.character));
    final own = result.standings.where((s) => s.number == number).firstOrNull;
    final name =
        own?.name ?? ref.watch(profileProvider).nickname ?? (number == null ? null : PhoneText.playerShort(number));
    final toy = ToyCharacter.of(own?.character ?? character, own?.number ?? number ?? 1);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          // The mock-up's card leaves the frame's edges clear around it.
          constraints: const BoxConstraints(maxWidth: _cardWidth),
          child: ToyCard(
            header: _outcome(result),
            padding: const EdgeInsets.all(ToySizes.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Picture(),
                _nameRow(context, name: name, number: own?.number ?? number ?? 1, toy: toy),
                ..._night(context, number: number),
                const SizedBox(height: ToySizes.space12),
                Text(
                  PhoneText.waitingForNext,
                  key: const Key('resultWaiting'),
                  textAlign: TextAlign.center,
                  style: look.type.body.copyWith(color: look.colors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The row across the card: the badge, the name, and the time or count.
  Widget _nameRow(BuildContext context, {required String? name, required int number, required ToyCharacter toy}) {
    final look = ToyLookScope.of(context);
    return Row(
      children: [
        _Badge(toy: toy, number: number),
        const SizedBox(width: ToySizes.space8),
        Expanded(
          child: Text(
            name ?? '',
            key: const Key('resultName'),
            style: look.type.button.copyWith(color: look.colors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_detail(result) case final detail?)
          Text(
            detail,
            key: const Key('resultDetail'),
            style: look.type.button.copyWith(color: look.colors.ink),
          ),
      ],
    );
  }

  /// The points earned in a night and the night's standings, when the host
  /// sent them.
  List<Widget> _night(BuildContext context, {required int? number}) {
    final look = ToyLookScope.of(context);
    final points = result.points;
    return [
      if (points != null) ...[
        const SizedBox(height: ToySizes.space8),
        Text(
          PhoneText.pointsEarned(points),
          key: const Key('resultPoints'),
          textAlign: TextAlign.center,
          style: look.type.button.copyWith(color: look.colors.good),
        ),
      ],
      if (result.standings.isNotEmpty) ...[
        const SizedBox(height: ToySizes.space12),
        Text(PhoneText.standings, style: look.type.body.copyWith(color: look.colors.inkSoft)),
        const SizedBox(height: ToySizes.space4),
        for (final standing in result.standings) _StandingRow(standing: standing, own: standing.number == number),
      ],
    ];
  }

  /// The mock-up's card width, in logical pixels: wider than a phone's narrow
  /// side, so it sits across the frame as drawn.
  static const _cardWidth = 420.0;

  /// The card's header: the outcome the host sent, with the time when the board
  /// counted one and the outcome alone doesn't say it.
  static String _outcome(ViewResult result) {
    final time = result.timeS;
    return switch (result.outcome) {
      ViewOutcome.win => PhoneText.youWin,
      ViewOutcome.loss => PhoneText.youLose,
      ViewOutcome.draw => PhoneText.draw,
      _ => time == null ? PhoneText.done : PhoneText.doneIn(clock(time)),
    };
  }

  /// What the row says beside the name: the time a won or lost round took, or
  /// what the player counted when the card counts it. A finished board says
  /// its time in the header already.
  static String? _detail(ViewResult result) {
    final time = result.timeS;
    if (time != null && result.outcome != ViewOutcome.done) return clock(time);
    final count = result.count;
    return switch (result.countOf) {
      ViewCount.pieces when count != null => PhoneText.pieces(count),
      ViewCount.coins when count != null => PhoneText.coins(count),
      _ => null,
    };
  }

  /// A round's seconds as the clock says them, rounded down as a clock does.
  static String clock(double seconds) {
    final whole = seconds.floor();
    return PhoneText.clock(whole ~/ _secondsPerMinute, whole % _secondsPerMinute);
  }

  static const _secondsPerMinute = Duration.secondsPerMinute;
}

/// This phone's side's picture as the results' photo (design 3a, M14 r5 5): the
/// board as the last frame drew it, in the field the round played it in, framed
/// exactly as the host's own card frames it. Nothing for a game that has no
/// picture, or one this app can't build yet.
class _Picture extends ConsumerWidget {
  const _Picture();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawn = ref.watch(viewDrawnProvider);
    if (drawn == null || drawn.start.game != shapeRaceModule.id) return const SizedBox.shrink();
    final frame = drawn.frame;
    final puzzleId = drawn.start.setup['puzzle'];
    if (frame is! MatchSnapshot || puzzleId is! String) return const SizedBox.shrink();
    final puzzle = ref.watch(puzzleLibraryProvider).value?.byId(puzzleId);
    if (puzzle == null) return const SizedBox.shrink();
    final side = _sideOf(drawn.start.setup, ref.watch(identityProvider).controllerId);
    final seed = frame.seed;
    // A split round draws this phone's own board; a one-board `phones` round
    // draws the one board both sides play. A board with no layout seed (a
    // one-board screen match) has no field to draw here.
    if (side == null || seed == null) return const SizedBox.shrink();
    final target = drawn.start.setup['layout'] == phonesLayoutName ? LayoutTarget.phones : LayoutTarget.screen;
    final index = frame.split ? side.index : 0;
    if (index >= frame.boards.length) return const SizedBox.shrink();
    final layout = SplitLayout.of(puzzle, seed, target: target);
    return Padding(
      padding: const EdgeInsets.only(bottom: ToySizes.space12),
      child: Center(
        child: PuzzlePhoto(
          key: const Key('resultPhoto'),
          puzzle: puzzle,
          board: frame.boards[index],
          field: side == PuzzleSide.left ? layout.left : layout.right,
        ),
      ),
    );
  }

  /// The side [playerId] plays, from the view setup's teams: null when this
  /// phone plays none, so it has no own board to show.
  static PuzzleSide? _sideOf(Map<String, Object?> setup, String playerId) =>
      switch ((setup['teams'] as Map<String, Object?>?)?[playerId]) {
        'left' => PuzzleSide.left,
        'right' => PuzzleSide.right,
        _ => null,
      };
}

/// The player's own badge on the card: the look's toy disc, wearing the
/// character the host gave them.
class _Badge extends StatelessWidget {
  const _Badge({required this.toy, required this.number});

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
    final name = standing.name;
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
