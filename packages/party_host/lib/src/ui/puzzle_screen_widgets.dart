part of 'puzzle_screen.dart';

/// The results' headline and its colour: who won a race, or how a one-board
/// game went. The host log says the same words (m12 bug 1107e).
({String title, Color colour}) _resultsHead(MatchResult result) => result.format.split
    ? switch (result.winner) {
        PuzzleSide.left => (title: 'Left wins!', colour: Colors.greenAccent),
        PuzzleSide.right => (title: 'Right wins!', colour: Colors.greenAccent),
        null => (title: 'Draw!', colour: Colors.amberAccent),
      }
    : result.sides.values.single.finished
    ? (title: 'Done!', colour: Colors.greenAccent)
    : (title: 'Time\'s up!', colour: Colors.amberAccent);

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

/// The line at the bottom right: how to play, to pause and to leave.
class _PlayHint extends StatelessWidget {
  const _PlayHint({required this.keyboard});

  final LocalPlayerSource keyboard;

  @override
  Widget build(BuildContext context) => Positioned(
    right: 12,
    bottom: 6,
    child: Text(
      keyboard.available && !keyboard.hasPlayer
          ? 'Arrows, Space, X and Z: play on the keyboard · Start on a phone: pause · '
                'Esc: leave'
          : 'Start on a phone: pause · Back: leave',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
    ),
  );
}

/// The results over the board: the winner, each side's time or pieces
/// placed, and Rematch (Play again), Change teams and Back (T14).
class _Results extends ConsumerWidget {
  const _Results({
    required this.result,
    required this.teams,
    required this.total,
    required this.againFocus,
    required this.onAgain,
    required this.onChangeTeams,
  });

  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final int total;
  final FocusNode againFocus;
  final VoidCallback onAgain;
  final VoidCallback onChangeTeams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final players = ref.watch(gamePlayersProvider);
    final race = result.format.split;
    final (:title, :colour) = _resultsHead(result);

    return DecoratedBox(
      key: const Key('puzzleResults'),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              key: const Key('puzzleResultTitle'),
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: colour),
            ),
            const SizedBox(height: 8),
            for (final side in result.sides.keys)
              _ResultSideRow(side: side, result: result, teams: teams, players: players, total: total),
            const SizedBox(height: 24),
            _ResultButtons(race: race, againFocus: againFocus, onAgain: onAgain, onChangeTeams: onChangeTeams),
          ],
        ),
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
    final text = Theme.of(context).textTheme;
    final race = result.format.split;
    final badges = [
      for (final p in players)
        if (teams[p.id] == side || (!race && teams.containsKey(p.id))) p,
    ];
    final r = result.sides[side]!;
    final line = r.finished ? '${r.timeS!.toStringAsFixed(1)} seconds' : '${r.placed} of $total pieces placed';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (race)
            SizedBox(width: 80, child: Text(side == PuzzleSide.left ? 'Left' : 'Right', style: text.titleLarge)),
          for (final p in badges) ...[PlayerBadge(number: p.number, size: 30), const SizedBox(width: 6)],
          const SizedBox(width: 8),
          Text(
            line,
            key: Key('puzzleResultLine-${side.name}'),
            style: text.headlineSmall?.copyWith(
              color: race && result.winner == side ? Colors.greenAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rematch (Play again on one board), Change teams and Back.
class _ResultButtons extends StatelessWidget {
  const _ResultButtons({
    required this.race,
    required this.againFocus,
    required this.onAgain,
    required this.onChangeTeams,
  });

  final bool race;
  final FocusNode againFocus;
  final VoidCallback onAgain;
  final VoidCallback onChangeTeams;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HostButton(
        key: Key(race ? 'rematch' : 'playAgain'),
        label: race ? 'Rematch' : 'Play again',
        icon: Icons.replay,
        focusNode: againFocus,
        onPressed: onAgain,
      ),
      const SizedBox(width: 12),
      HostButton(key: const Key('changeTeams'), label: 'Change teams', icon: Icons.group, onPressed: onChangeTeams),
      const SizedBox(width: 12),
      HostButton(
        key: const Key('resultsBack'),
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}
