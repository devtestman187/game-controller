part of 'puzzle_screen.dart';

/// The results' headline and its colour (M13 3b): who won a race, or how a
/// one-board game went. A winning side's header takes its own colour, a draw
/// takes the focus yellow, and a one-board game is good or a caution by whether
/// it finished. The host log says the same words (m12 bug 1107e).
({String title, Color colour}) _resultsHead(ToyLook look, MatchResult result) {
  final colors = look.colors;
  if (!result.format.split) {
    return result.sides.values.single.finished
        ? (title: HostText.done, colour: colors.good)
        : (title: HostText.timeUp, colour: colors.caution);
  }
  return switch (result.winner) {
    PuzzleSide.left => (title: HostText.leftWins, colour: colors.player(1)),
    PuzzleSide.right => (title: HostText.rightWins, colour: colors.player(2)),
    null => (title: HostText.draw, colour: colors.focus),
  };
}

/// The winning side's time for the log, ` (105.9 s)`: nothing when the round
/// ran out of time or drew.
String _endTime(MatchResult result) {
  final side = result.winner ?? (result.format.split ? null : PuzzleSide.left);
  final done = side == null ? null : result.sides[side];
  if (done == null || !done.finished) return '';
  return ' (${done.timeS!.toStringAsFixed(1)} s)';
}

/// How many players a round has, in words: `1 player`, `2 players`.
String _playersLine(int count) => count == 1 ? '1 player' : '$count players';

/// The results' first button (T14): Rematch or Play again for one chosen
/// puzzle, Next puzzle after a round that played `any <level> puzzle` (m12
/// bug 1108e). The focus starts on it, so the remote's OK and a phone's A work
/// at once.
typedef _AgainButton = ({String label, IconData icon, String key, FocusNode focusNode, VoidCallback onPressed});

/// The results over the board: the winner, each side's time or pieces
/// placed, and the first button (Rematch, Play again or Next puzzle), Change
/// teams and Back (T14). A night's round keeps only its Next (M14 c1).
class _Results extends ConsumerWidget {
  const _Results({
    required this.result,
    required this.teams,
    required this.total,
    required this.again,
    required this.onChangeTeams,
    required this.night,
  });

  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final int total;
  final _AgainButton again;
  final VoidCallback onChangeTeams;

  /// Whether this round is a night's: its results offer Next alone (design
  /// section 4), and the night's scoreboard follows it.
  final bool night;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final players = ref.watch(gamePlayersProvider);
    final (:title, :colour) = _resultsHead(look, result);

    return ToyCard(
      key: const Key('puzzleResults'),
      header: title,
      headerKey: const Key('puzzleResultTitle'),
      headerColor: colour,
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space32, vertical: ToySizes.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final side in result.sides.keys)
            _ResultSideRow(side: side, result: result, teams: teams, players: players, total: total),
          const SizedBox(height: ToySizes.space24),
          _ResultButtons(again: again, onChangeTeams: onChangeTeams, night: night),
        ],
      ),
    );
  }
}

/// One side's row on the results: its players, then its time, or how many
/// pieces it placed.
class _ResultSideRow extends StatelessWidget {
  const _ResultSideRow({
    required this.side,
    required this.result,
    required this.teams,
    required this.players,
    required this.total,
  });

  final PuzzleSide side;
  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final List<GamePlayer> players;
  final int total;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final race = result.format.split;
    final badges = [
      for (final p in players)
        if (teams[p.id] == side || (!race && teams.containsKey(p.id))) p,
    ];
    final r = result.sides[side]!;
    final line = r.finished ? HostText.seconds(r.timeS!) : HostText.piecesPlaced(r.placed, total);
    return Padding(
      padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (race)
            SizedBox(
              width: look.sizes.buttonHeight * 2,
              child: Text(
                side == PuzzleSide.left ? HostText.left : HostText.right,
                style: look.type.button.copyWith(color: colors.ink),
              ),
            ),
          for (final p in badges) ...[
            ToyBadge(
              number: p.number,
              diameter: look.sizes.buttonHeight * rowBadgeShare,
              character: ToyCharacter.forPlayer(p.number),
            ),
            const SizedBox(width: ToySizes.space8),
          ],
          const SizedBox(width: ToySizes.space8),
          Text(
            line,
            key: Key('puzzleResultLine-${side.name}'),
            style: look.type.button.copyWith(color: colors.ink),
          ),
          if (r.finished) ...[
            const SizedBox(width: ToySizes.space8),
            Icon(Icons.check, size: look.type.button.fontSize, color: colors.ink),
          ],
        ],
      ),
    );
  }
}

/// The first button (Rematch, Play again or Next puzzle), Change teams and
/// Back; a night's round has the first button alone, Next (M14 c1).
class _ResultButtons extends StatelessWidget {
  const _ResultButtons({required this.again, required this.onChangeTeams, required this.night});

  final _AgainButton again;
  final VoidCallback onChangeTeams;
  final bool night;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HostButton(
        key: Key(again.key),
        label: again.label,
        icon: again.icon,
        focusNode: again.focusNode,
        onPressed: again.onPressed,
      ),
      if (!night) ...[
        const SizedBox(width: ToySizes.space12),
        HostButton(
          key: const Key('changeTeams'),
          label: HostText.changeTeams,
          icon: Icons.group,
          onPressed: onChangeTeams,
        ),
        const SizedBox(width: ToySizes.space12),
        HostButton(
          key: const Key('resultsBack'),
          label: HostText.back,
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ],
  );
}
