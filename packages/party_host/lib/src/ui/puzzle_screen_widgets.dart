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
