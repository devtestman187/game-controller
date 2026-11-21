part of 'join_screen.dart';

/// How much of a dropped player's row shows while their side is held for them
/// (M16 item 2, mock-up frame 1): dimmed, but in their slot.
const _awayRowOpacity = 0.45;

/// The ink a side's empty seat's dashed line is drawn in, as a share of the
/// look's ink: faint enough to read as a place waiting for a phone. Its words
/// are the look's soft ink, which keeps 4.5:1.
const _emptySeatAlpha = 0.45;

/// How long a dash of the empty seat's line is, and the gap after it (M13 3b,
/// mock-up `join-screen`).
const _seatDashPx = 8.0;
const _seatGapPx = 7.0;

/// The side card's header band, in frame px: a short band, so a full side is
/// three 52 px seats and this (DESIGN section 4's scoreboard rows; S8j's
/// short sides). The look's card header is a button's line tall, which the
/// frame's 392 px body has no room for once a side is full.
const _sideHeaderPx = 28.0;

/// The room above a side's first seat, in frame px: a badge's accessory is
/// drawn above its box (M13 4c), and this keeps it on the card's paper inside
/// the card rather than over the header's ink line.
const _seatHeadroomPx = 12.0;

/// The colour a side's header band takes: the left side is player 1's colour
/// and the right is player 2's, as the mock-up draws them.
Color sideColor(ToyLook look, PuzzleSide side) => look.colors.player(side == PuzzleSide.left ? 1 : 2);

/// Both sides, side by side. [players] is the whole roster, so an away player
/// who has a side keeps it (M16 item 2).
class _Sides extends StatelessWidget {
  const _Sides({required this.players, required this.teams, this.ownPlayerId, this.onPick});

  final List<GamePlayer> players;
  final Map<String, PuzzleSide> teams;

  /// The host phone's own player, marked on its side; null on a TV.
  final String? ownPlayerId;

  /// Moves the own player to the tapped side; null on a TV, whose panels are
  /// then not tappable at all.
  final void Function(PuzzleSide side)? onPick;

  @override
  Widget build(BuildContext context) {
    final pick = onPick;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              onTap: pick == null ? null : () => pick(side),
            ),
          ),
        ],
      ],
    );
  }
}

/// One side of the join screen (M13 3b, mock-up `join-screen`): a [ToyCard]
/// whose short header band is the side's colour and name, one 52 px seat for
/// each joined player with their badge (a dropped player's row stays, dimmed,
/// while their side is held: M16 item 2), and a dashed seat for each phone
/// still to join. On the host phone it is a touch target too (m12-host-touch
/// rule 5): a tap moves the own player here, when the side has room.
///
/// A side never scrolls (DESIGN section 1, rule 6): [maxPerSide] seats and the
/// band fit the frame's body at every device size, so the card has no
/// scrollable at all (S8j).
class _SidePanel extends StatelessWidget {
  const _SidePanel({super.key, required this.side, required this.players, this.ownPlayerId, this.onTap});

  final PuzzleSide side;
  final List<GamePlayer> players;

  /// The host phone's own player, marked "(you)" on its row; null on a TV.
  final String? ownPlayerId;

  /// A tap moves the own player to this side; null when there is no own
  /// player here.
  final VoidCallback? onTap;

  /// A player's name, and "(you)" for the host phone's own player; a dropped
  /// player's phone is away, and their side is held for them (M16 item 2).
  String _label(GamePlayer p) {
    final label = HostText.playerLabel(p.label, simulated: p.simulated, own: p.id == ownPlayerId);
    return p.away ? HostText.awayLabel(label) : label;
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final card = ToyCard(
      // The band is the card's own, so it can be the short 28 px one: the
      // look's card header is a button's line tall.
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideHeader(side: side, color: sideColor(look, side)),
          Padding(
            padding: const EdgeInsets.only(top: _seatHeadroomPx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in players)
                  Opacity(
                    opacity: p.away ? _awayRowOpacity : 1,
                    child: _PlayerRow(label: _label(p), number: p.number, character: p.character),
                  ),
                for (var i = players.length; i < maxPerSide; i++)
                  _EmptySeat(roomLeft: i == players.length ? maxPerSide - players.length : null),
              ],
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap, child: card);
  }
}

/// The side's header band: its name on the side's colour, in the frame's
/// smallest type, with the look's ink line under it.
class _SideHeader extends StatelessWidget {
  const _SideHeader({required this.side, required this.color});

  final PuzzleSide side;

  /// The side's colour: the band's fill.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return DecoratedBox(
      key: Key('sideHeader-${side.name}'),
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
        ),
      ),
      child: SizedBox(
        height: _sideHeaderPx,
        child: Center(
          child: Text(
            side == PuzzleSide.left ? HostText.leftSide : HostText.rightSide,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // A line box of 1.2 x 20 = 24 px, with the band's own 2 above and
            // below: 28, its height.
            style: ToyType.frameSmall.copyWith(color: look.colors.ink, height: 1.2),
          ),
        ),
      ),
    );
  }
}

/// One joined player's seat: their badge, wearing their character (M13 4c),
/// and their name, on one 52 px line (DESIGN section 4's scoreboard row, so a
/// full side is short enough for the frame's body). The name ellipsises rather
/// than wrap, and the row's room keeps the accessory's reach clear of the
/// card's edge.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.label, required this.number, this.character});

  final String label;
  final int number;

  /// The character the host gave them (M14 L7), or null for the default.
  final PlayerCharacter? character;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return SizedBox(
      height: scoreRowHeightPx,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12),
        child: Row(
          children: [
            PlayerBadge(number: number, size: scoreRowBadgePx, character: character),
            const SizedBox(width: ToySizes.space12),
            Expanded(
              child: Text(
                label,
                style: look.type.body.copyWith(color: look.colors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A seat no phone has taken yet: a dashed line across the side's paper, with
/// the room it leaves, on a seat's line.
class _EmptySeat extends StatelessWidget {
  const _EmptySeat({required this.roomLeft});

  /// How many more players the whole side has room for, said on its first
  /// empty seat only; null on the others, which keep the line's height.
  final int? roomLeft;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return SizedBox(
      height: scoreRowHeightPx,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12, vertical: ToySizes.space8),
        child: CustomPaint(
          painter: EmptySeatPainter(look: look),
          child: Center(
            child: Text(
              roomLeft == null ? '' : HostText.roomFor(roomLeft!),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: look.type.body.copyWith(color: look.colors.inkSoft),
            ),
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
