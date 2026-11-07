part of 'join_screen.dart';

/// One side of the join screen: its name and the players on it.
class _SidePanel extends StatelessWidget {
  const _SidePanel({super.key, required this.side, required this.players});

  final PuzzleSide side;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              side == PuzzleSide.left ? '◀ Left' : 'Right ▶',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final p in players)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    PlayerBadge(number: p.number, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${p.label}${p.simulated ? ' (simulated)' : ''}',
                        style: text.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (players.length < maxPerSide)
              Text('Room for ${maxPerSide - players.length} more', style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// Both sides, side by side.
class _Sides extends StatelessWidget {
  const _Sides({required this.players, required this.teams});

  final List<GamePlayer> players;
  final Map<String, PuzzleSide> teams;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, side) in PuzzleSide.values.indexed) ...[
        if (i > 0) const SizedBox(width: 16),
        Expanded(
          child: _SidePanel(
            key: Key('side-${side.name}'),
            side: side,
            players: [
              for (final p in players)
                if (teams[p.id] == side) p,
            ],
          ),
        ),
      ],
    ],
  );
}

/// The players who haven't picked a side yet.
class _NotJoined extends StatelessWidget {
  const _NotJoined({required this.watching});

  final List<GamePlayer> watching;

  @override
  Widget build(BuildContext context) => Text(
    'Not joined: ${watching.map((p) => p.label).join(', ')}',
    key: const Key('notJoined'),
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

/// Start, Back, and the format the joined players make.
class _JoinButtons extends StatelessWidget {
  const _JoinButtons({required this.teams, required this.startFocus, required this.onStart});

  final Map<String, PuzzleSide> teams;
  final FocusNode startFocus;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        HostButton(
          key: const Key('joinStart'),
          label: 'Start',
          icon: Icons.play_arrow,
          focusNode: startFocus,
          onPressed: onStart,
        ),
        const SizedBox(width: 12),
        HostButton(
          key: const Key('joinBack'),
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            teams.isEmpty
                ? 'Nobody has joined yet.'
                : '${formatName(MatchFormat.of(teams))}. Press A or Start to begin.',
            key: const Key('joinFormat'),
            style: teams.isEmpty
                ? text.titleMedium
                : text.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
