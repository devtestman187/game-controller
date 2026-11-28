part of 'join_screen.dart';

/// The pairing code in the frame's header (M16 item 3, PRD v2's
/// acceptance: "the 4-digit code is visible where a player looks"): the paper
/// chip the Arena's waiting card shows, with the word and the four figures.
/// It only says the code: a tap does nothing and it takes no focus.
class _JoinCode extends ConsumerWidget {
  const _JoinCode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final code = ref.watch(hostStateProvider.select((s) => s.host.pairingCode));
    return ToyCard(
      key: const Key('joinCode'),
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12, vertical: ToySizes.space8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(HostText.code, style: look.type.body.copyWith(color: look.colors.inkSoft)),
          const SizedBox(width: ToySizes.space8),
          Text(
            code,
            style: look.type.button.copyWith(
              color: look.colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The players who haven't picked a side yet.
class _NotJoined extends StatelessWidget {
  const _NotJoined({required this.watching, required this.full});

  final List<GamePlayer> watching;

  /// Both sides are full: the line says "Game full" (e0e).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Text(
      HostText.notJoined(watching.map((p) => p.label).join(', '), full: full),
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

/// The screen's way on, in the frame's footer (DESIGN section 1, rule 5):
/// Start, with the focus the remote's OK presses, and Back.
class _JoinButtons extends StatelessWidget {
  const _JoinButtons({required this.startFocus, required this.onStart});

  /// The focus Start takes on entry, so a remote's OK begins the match.
  final FocusNode startFocus;

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
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
    ],
  );
}

/// The format the joined players make, under the sides ("2 vs 2. Press A or
/// Start to begin."): the way on is the footer's, so the line has the body's
/// width for its words where the buttons would have taken it.
class _FormatLine extends ConsumerWidget {
  const _FormatLine({required this.teams, required this.ownPlayerId});

  final Map<String, PuzzleSide> teams;

  /// The host phone's own player in the match, when it plays here ("Play on
  /// this phone"); null on a TV and on a phone that only shows the game.
  final String? ownPlayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    // A touch-first host has no pad, so the line says what its screen does
    // (m12 bug 1108c); the flag is read here, where the words are chosen.
    final begin = _beginText(touchFirst: ref.watch(hostTouchFirstProvider), hasOwnPlayer: ownPlayerId != null);
    return Text(
      teams.isEmpty ? HostText.nobodyJoined : '${HostText.formatName(MatchFormat.of(teams))}. $begin',
      key: const Key('joinFormat'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: teams.isEmpty
          ? look.type.body.copyWith(color: look.colors.onBackground)
          : look.type.button.copyWith(color: look.colors.onBackground),
    );
  }
}

/// The join screen's instructions, and after them, on the same lines, how to
/// pause and leave the round (owner, Nov 8, 2026: "Is that text necessary when
/// a game is in progress?"): said here so nothing is drawn over the boards in
/// play, and set inline after the instructions' last word, where the line has
/// room, so the sides keep their height (Claude's 4c review). [keyboard] is
/// null only where no keyboard can play.
class _JoinHint extends StatelessWidget {
  const _JoinHint({required this.text, required this.keyboard});

  final String text;
  final LocalPlayerSource? keyboard;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final keys = keyboard;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (keys != null) ...[
            const TextSpan(text: '  '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: PlayHint(puzzlePlayHint(keyboardAvailable: keys.available, keyboardHasPlayer: keys.hasPlayer)),
            ),
          ],
        ],
      ),
      style: look.type.button.copyWith(color: look.colors.onBackground),
    );
  }
}

/// The join screen's body (DESIGN section 1 rule 5): the hint, the two side
/// cards, the line naming the players who haven't joined and, under the cards,
/// the format line.
class _JoinBody extends StatelessWidget {
  const _JoinBody({
    required this.hint,
    required this.keyboard,
    required this.players,
    required this.teams,
    required this.seats,
    required this.ownPlayerId,
    required this.onPick,
    required this.watching,
    required this.ownHere,
    required this.full,
  });

  final String hint;
  final LocalPlayerSource? keyboard;
  final List<GamePlayer> players;
  final Map<String, PuzzleSide> teams;

  /// How many seats each side draws: the cap the state computes.
  final int seats;
  final String? ownPlayerId;
  final void Function(PuzzleSide side)? onPick;
  final List<GamePlayer> watching;
  final String? ownHere;

  /// Both sides are full, so the watching line says "Game full" (e0e).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JoinHint(text: hint, keyboard: keyboard),
        const SizedBox(height: _hintGapPx),
        Expanded(
          child: _Sides(players: players, teams: teams, seats: seats, ownPlayerId: ownPlayerId, onPick: onPick),
        ),
        if (watching.isNotEmpty) ...[const SizedBox(height: _lineGapPx), _NotJoined(watching: watching, full: full)],
        const SizedBox(height: _lineGapPx),
        _FormatLine(teams: teams, ownPlayerId: ownHere),
      ],
    );
    return LayoutBuilder(
      builder: (context, room) {
        // The body fills the frame's room, which is at least
        // [_frameBodyFloorPx] (DESIGN section 1 rule 7). A host that draws the
        // screen without the frame gives it less: the body is then drawn at its
        // floor and scaled down, never overflowed.
        if (room.maxHeight >= _frameBodyFloorPx) return content;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(height: _frameBodyFloorPx, width: room.maxWidth, child: content),
        );
      },
    );
  }
}
