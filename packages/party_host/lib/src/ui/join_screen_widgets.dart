part of 'join_screen.dart';

/// The ink a side's empty seat's dashed line is drawn in, as a share of the
/// look's ink: faint enough to read as a place waiting for a phone. Its words
/// are the look's soft ink, which keeps 4.5:1.
const _emptySeatAlpha = 0.45;

/// How long a dash of the empty seat's line is, and the gap after it (M13 3b,
/// mock-up `join-screen`).
const _seatDashPx = 8.0;
const _seatGapPx = 7.0;

/// The colour a side's header band takes: the left side is player 1's colour
/// and the right is player 2's, as the mock-up draws them.
Color sideColor(ToyLook look, PuzzleSide side) => look.colors.player(side == PuzzleSide.left ? 1 : 2);

/// One side of the join screen (M13 3b, mock-up `join-screen`): a [ToyCard]
/// whose header band is the side's colour and name, one row for each joined
/// player with their [ToyBadge], and a dashed seat for each phone still to
/// join. On the host phone it is a touch target too (m12-host-touch rule 5): a
/// tap moves the own player here, when the side has room.
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
  String _label(GamePlayer p) => HostText.playerLabel(p.label, simulated: p.simulated, own: p.id == ownPlayerId);

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final card = ToyCard(
      header: side == PuzzleSide.left ? HostText.leftSide : HostText.rightSide,
      headerColor: sideColor(look, side),
      padding: EdgeInsets.all(tight ? _tightPanelPaddingPx : _panelPaddingPx),
      // Scrolls when the screen is too short for a full side (a landscape
      // phone hosting, with its own bar above): on a TV it always fits.
      scrollBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in players) _PlayerRow(label: _label(p), number: p.number),
          for (var i = players.length; i < maxPerSide; i++)
            _EmptySeat(roomLeft: i == players.length ? maxPerSide - players.length : null),
        ],
      ),
    );
    final tap = onTap;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap, child: card);
  }
}

/// One joined player's row: their badge and their name, on the paper.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.label, required this.number});

  final String label;
  final int number;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ToySizes.space4),
      child: Row(
        children: [
          ToyBadge(number: number, diameter: look.sizes.buttonHeight * 0.75),
          const SizedBox(width: ToySizes.space12),
          Expanded(
            child: Text(
              label,
              style: look.type.button.copyWith(color: look.colors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A seat no phone has taken yet: a dashed line across the side's paper, with
/// the room it leaves.
class _EmptySeat extends StatelessWidget {
  const _EmptySeat({required this.roomLeft});

  /// How many more players the whole side has room for, said on its first
  /// empty seat only; null on the others, which keep the line's height.
  final int? roomLeft;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: ToySizes.space4),
      child: CustomPaint(
        painter: EmptySeatPainter(look: look),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ToySizes.space8),
          child: Text(
            roomLeft == null ? '' : HostText.roomFor(roomLeft!),
            textAlign: TextAlign.center,
            style: look.type.body.copyWith(color: look.colors.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// Draws an empty seat's dashed rounded line (M13 3b): [toyShape] would fill
/// it, so the dashes are cut from the rounded rect's path by hand.
class EmptySeatPainter extends CustomPainter {
  const EmptySeatPainter({required this.look});

  /// The look the line is drawn in.
  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(look.sizes.outlineWidth / 2), radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.sizes.outlineWidth
      ..color = look.colors.ink.withValues(alpha: _emptySeatAlpha);
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _seatDashPx + _seatGapPx) {
        canvas.drawPath(metric.extractPath(at, math.min(at + _seatDashPx, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(EmptySeatPainter oldDelegate) => oldDelegate.look != look;
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
          if (i > 0) const SizedBox(width: ToySizes.space16),
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
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Text(
      HostText.notJoined(watching.map((p) => p.label).join(', ')),
      key: const Key('notJoined'),
      style: look.type.body.copyWith(color: look.colors.onBackground),
    );
  }
}

/// What begins the match, in the words for this host (m12 bug 1108c): the TV
/// has a pad that presses A or Start; a phone has a Start button to tap, and
/// when it only shows the game a joined phone still begins with A.
String _beginText({required bool touchFirst, required bool hasOwnPlayer}) {
  if (!touchFirst) return HostText.beginWithPad;
  return hasOwnPlayer ? HostText.beginTouch : HostText.beginTouchOrPad;
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
    final look = ToyLookScope.of(context);
    // A touch-first host has no pad, so the line says what its screen does
    // (m12 bug 1108c); the flag is read here, where the words are chosen.
    final begin = _beginText(touchFirst: ref.watch(hostTouchFirstProvider), hasOwnPlayer: ownPlayerId != null);
    return Row(
      children: [
        HostButton(
          key: const Key('joinStart'),
          label: HostText.start,
          icon: Icons.play_arrow,
          focusNode: startFocus,
          onPressed: onStart,
        ),
        const SizedBox(width: ToySizes.space12),
        HostButton(
          key: const Key('joinBack'),
          label: HostText.back,
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: ToySizes.space24),
        Expanded(
          child: Text(
            teams.isEmpty ? HostText.nobodyJoined : '${HostText.formatName(MatchFormat.of(teams))}. $begin',
            key: const Key('joinFormat'),
            style: teams.isEmpty
                ? look.type.body.copyWith(color: look.colors.onBackground)
                : look.type.button.copyWith(color: look.colors.onBackground),
          ),
        ),
      ],
    );
  }
}
