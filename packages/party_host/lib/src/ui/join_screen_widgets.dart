part of 'join_screen.dart';

/// One side of the join screen: its name and the players on it. On the host
/// phone it is a touch target too (m12-host-touch rule 5): a tap moves the
/// own player here, when the side has room.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    super.key,
    required this.side,
    required this.players,
    this.ownPlayerId,
    this.tight = false,
    this.onTap,
  });

  final PuzzleSide side;
  final List<GamePlayer> players;

  /// The host phone's own player, marked "(you)" on its row; null on a TV.
  final String? ownPlayerId;

  /// Less room inside, under the phone's own bar (bug 1107f).
  final bool tight;

  /// A tap moves the own player to this side; null when there is no own
  /// player here.
  final VoidCallback? onTap;

  /// A player's name, and "(you)" for the host phone's own player.
  String _label(GamePlayer p) => '${p.label}${p.simulated ? ' (simulated)' : ''}${p.id == ownPlayerId ? ' (you)' : ''}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Scrolls when the screen is too short for a full side (a landscape
        // phone hosting, with its own bar above): on a TV it always fits.
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tight ? _tightPanelPaddingPx : _panelPaddingPx),
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
                        child: Text(_label(p), style: text.titleLarge, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              if (players.length < maxPerSide)
                Text('Room for ${maxPerSide - players.length} more', style: text.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Both sides, side by side.
class _Sides extends StatelessWidget {
  const _Sides({required this.players, required this.teams, this.ownPlayerId, this.tight = false, this.onPick});

  final List<GamePlayer> players;
  final Map<String, PuzzleSide> teams;

  /// The host phone's own player, marked on its side; null on a TV.
  final String? ownPlayerId;

  /// Less room inside the panels, under the phone's own bar (bug 1107f).
  final bool tight;

  /// Moves the own player to the tapped side; null on a TV, whose panels are
  /// then not tappable at all.
  final void Function(PuzzleSide side)? onPick;

  @override
  Widget build(BuildContext context) {
    final pick = onPick;
    return Row(
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
              ownPlayerId: ownPlayerId,
              tight: tight,
              onTap: pick == null ? null : () => pick(side),
            ),
          ),
        ],
      ],
    );
  }
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

/// What begins the match, in the words for this host (m12 bug 1108c): the TV
/// has a pad that presses A or Start; a phone has a Start button to tap, and
/// when it only shows the game a joined phone still begins with A.
String _beginText({required bool touchFirst, required bool hasOwnPlayer}) {
  if (!touchFirst) return 'Press A or Start to begin.';
  return hasOwnPlayer ? 'Tap Start to begin.' : 'Tap Start, or press A on a phone, to begin.';
}

/// Start, Back, and the format the joined players make.
class _JoinButtons extends ConsumerWidget {
  const _JoinButtons({required this.teams, required this.ownPlayerId, required this.startFocus, required this.onStart});

  final Map<String, PuzzleSide> teams;

  /// The host phone's own player in the match, when it plays here ("Play on
  /// this phone"); null on a TV and on a phone that only shows the game.
  final String? ownPlayerId;

  final FocusNode startFocus;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // A touch-first host has no pad, so the line says what its screen does
    // (m12 bug 1108c); the flag is read here, where the words are chosen.
    final begin = _beginText(touchFirst: ref.watch(hostTouchFirstProvider), hasOwnPlayer: ownPlayerId != null);
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
            teams.isEmpty ? 'Nobody has joined yet.' : '${formatName(MatchFormat.of(teams))}. $begin',
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
