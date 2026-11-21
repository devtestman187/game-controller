part of 'puzzle_screen.dart';

/// The room the results card keeps round its content, in frame px: the design's
/// 24 px gutter at the sides (DESIGN section 1, rule 4) and 8 px above and
/// below, as the Arena results' card has it, so a race's rows fit a 540 frame.
const _cardPadding = EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space8);

/// A side's name on the results, in frame px (DESIGN section 4: the puzzle
/// results' names are 24 px, between the frame's body 22 and its button 28).
const _sideNamePx = 24.0;

/// A side's time or pieces, and the row's other words, in frame px (DESIGN
/// section 4: the pieces are 20 px, the frame's floor).
const _detailPx = 20.0;

/// The results over the board (DESIGN section 4): a [HostFrameScreen], so the
/// winner heads a screen with the way on in its footer and nothing scrolls at
/// any of the supported sizes (DESIGN section 1, rules 5 and 6). The card fills
/// the stage: each side's finished picture as a photo (design 3a) at its left,
/// and at its right the round's headline on a chip in its colour (M13 3b), the
/// series' prompt (B-011), each side's time or pieces placed with its best time
/// and any new record (T15), and the controls the footer cannot hold — a
/// series' Shuffle and Play again, and Change teams — as compact buttons.
///
/// The footer holds the way on alone (the S6b decision).
class _Results extends ConsumerWidget {
  const _Results({
    required this.result,
    required this.teams,
    required this.total,
    required this.menu,
    required this.onChangeTeams,
    required this.night,
    required this.lastRound,
    required this.onEndNight,
    required this.puzzle,
    required this.match,
    required this.times,
  });

  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final int total;

  /// What this round's results offer (B-011): its first button, its Play again
  /// and, in a series, the Shuffle switch and the level-done prompt.
  final _ResultMenu menu;
  final VoidCallback onChangeTeams;

  /// The puzzle played, and the round as it left it, for the photos (design
  /// 3a: an unfinished picture shows as it stood). The round's boards give each
  /// photo the field its pieces were placed in.
  final Puzzle puzzle;
  final PuzzleMatch? match;

  /// Whether this round is a night's: its results offer Next alone (design
  /// section 4), and the night's scoreboard follows it.
  final bool night;

  /// Whether the round on the card is the night's last: Next ends the night
  /// then, so End night has nothing left to end (B-021).
  final bool lastRound;

  /// A night's End night: the host ends the night on the round just played
  /// (B-021), before the night's last round.
  final VoidCallback onEndNight;

  /// What this round did to each finished side's best time (T15): the chip
  /// says which boards beat theirs.
  final Map<PuzzleSide, BestTimeResult> times;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final (:title, :colour) = _resultsHead(look, result);
    return HostFrameScreen(
      // The frame's header names the screen; the round's own headline stays on
      // the card, with the words the results have always said.
      title: HostText.shapeRace,
      body: _card(context, ref, title: title, colour: colour),
      footer: _footer(context),
    );
  }

  /// The card the body fills the stage with (DESIGN section 1, rule 4): the
  /// pictures at its left, the round's words and controls at its right.
  Widget _card(BuildContext context, WidgetRef ref, {required String title, required Color colour}) {
    final look = ToyLookScope.of(context);
    final players = ref.watch(gamePlayersProvider);
    final bestTimes = ref.watch(bestTimesProvider);
    final prompt = menu.series?.prompt;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        child: ToyCard(
          key: const Key('puzzleResults'),
          padding: _cardPadding,
          popIn: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: _photos()),
              const SizedBox(width: ToySizes.space24),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headline(look, title, colour),
                    if (prompt != null) ...[
                      const SizedBox(height: ToySizes.space8),
                      Text(
                        prompt,
                        key: const Key('seriesPrompt'),
                        style: look.type.body.copyWith(color: look.colors.ink),
                      ),
                    ],
                    for (final side in result.sides.keys)
                      _ResultSideRow(
                        side: side,
                        result: result,
                        teams: teams,
                        players: players,
                        total: total,
                        best: bestTimes.bestFor(
                          puzzle.id,
                          team: playersOn(side, result.format, teams, players).length > 1,
                        ),
                        isRecord: times[side]?.isRecord ?? false,
                      ),
                    ..._controls(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The round's headline on a chip in its colour (M13 3b: a race's winner's
  /// colour, the focus yellow for a draw, good or caution for one board).
  Widget _headline(ToyLook look, String title, Color colour) => Container(
    key: const Key('puzzleResultChip'),
    padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12, vertical: ToySizes.space4),
    decoration: BoxDecoration(
      color: colour,
      border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
      borderRadius: BorderRadius.circular(ToySizes.cardCorner),
    ),
    child: Text(
      title,
      key: const Key('puzzleResultTitle'),
      style: look.type.button.copyWith(color: look.colors.ink),
    ),
  );

  /// The footer's way on (DESIGN section 1, rule 5): the round's first button
  /// with Back, or a night's Next, with End night before the night's last round
  /// (B-021). The first button and Back go without their icons: with them the
  /// pair wants more than the 480 frame px the footer keeps beside Thumby's
  /// corner, as the Arena results' pair found, and their words say what they
  /// do. A night's two buttons keep theirs.
  List<Widget> _footer(BuildContext context) {
    final again = menu.again;
    if (night) {
      return [
        HostButton(
          key: Key(again.key),
          label: again.label,
          icon: again.icon,
          focusNode: again.focusNode,
          onPressed: again.onPressed,
        ),
        // The night's last round needs no button for it, since Next ends it.
        if (!lastRound)
          HostButton(key: const Key('endNight'), label: NightText.endNightNow, icon: Icons.flag, onPressed: onEndNight),
      ];
    }
    return [
      HostButton(key: Key(again.key), label: again.label, focusNode: again.focusNode, onPressed: again.onPressed),
      HostButton(
        key: const Key('resultsBack'),
        label: HostText.back,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ];
  }

  /// The controls the 84 px footer cannot hold (the S6b decision): a series'
  /// Shuffle and its replay, and Change teams, as compact buttons under the rows
  /// in the card's right column, with the keys they have always had. A night's
  /// round draws none (its next teams are picked on the next join screen), and
  /// an `any <level>` round only Change teams.
  ///
  /// Each button's share of the row is the width it wants ([_controlFlexPx]):
  /// equal shares cut Change teams at the 960-wide frames (222 wanted in 207,
  /// M16 phonehost3); a narrower card shrinks all labels alike and never scrolls.
  List<Widget> _controls(BuildContext context) {
    final look = ToyLookScope.of(context);
    final series = menu.series;
    final replay = menu.replay;
    final buttons = <Widget>[
      if (series?.shuffle != null) _ShuffleSwitch(shuffle: series!.shuffle!, compact: true),
      if (replay != null)
        HostButton(
          key: Key(replay.key),
          label: replay.label,
          icon: replay.icon,
          compact: true,
          onPressed: replay.onPressed,
        ),
      if (!night)
        HostButton(
          key: const Key('changeTeams'),
          label: HostText.changeTeams,
          icon: Icons.group,
          compact: true,
          onPressed: onChangeTeams,
        ),
    ];
    // In step with [buttons]: each button's share is the width its words want.
    final labels = [
      if (series?.shuffle != null) HostText.shuffle,
      if (replay != null) replay.label,
      if (!night) HostText.changeTeams,
    ];
    if (buttons.isEmpty) return const [];
    return [
      const SizedBox(height: ToySizes.space12),
      Row(
        spacing: ToySizes.space12,
        children: [
          for (var i = 0; i < buttons.length; i++)
            Flexible(flex: _controlFlexPx(context, look, labels[i]), child: buttons[i]),
        ],
      ),
    ];
  }

  /// The flex a compact control's share of the row gets, in frame px: its words
  /// in the type [ToyButton] draws (button family, body size), [ToySizes.space24]
  /// of padding a side, and the icon at the words' size with [ToySizes.space8].
  int _controlFlexPx(BuildContext context, ToyLook look, String label) {
    final style = look.type.button.copyWith(fontSize: look.type.body.fontSize);
    final words = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
    )..layout();
    final flex = (words.width + 2 * ToySizes.space24 + style.fontSize! + ToySizes.space8).ceil();
    words.dispose();
    return flex;
  }

  /// Each side's picture as the round left it (design 3a): its own board, else the one.
  List<Widget> _photos() {
    final round = match;
    if (round == null) return const [];
    final boards = round.snapshot().boards;
    final photos = <Widget>[];
    for (final side in result.sides.keys) {
      final index = result.format.split ? side.index : 0;
      if (index >= boards.length) continue;
      if (photos.isNotEmpty) photos.add(const SizedBox(width: ToySizes.space8));
      // The same photo a joined phone's card shows (M14 r5 5).
      photos.add(
        PuzzlePhoto(
          key: Key('puzzlePhoto-${side.name}'),
          puzzle: puzzle,
          board: boards[index],
          field: round.gameOf(side).field,
        ),
      );
    }
    return photos;
  }
}

/// One side's row on the results: its name in a race, its players' badges, its
/// time or how many pieces it placed, then the board's best time and the "New
/// record!" chip when it beat it (T15). Its parts are a [Wrap], so a crowded
/// row — two players a side with a best time and a new record — takes a second
/// line in the card's column rather than overflowing it (DESIGN rule 6).
class _ResultSideRow extends StatelessWidget {
  const _ResultSideRow({
    required this.side,
    required this.result,
    required this.teams,
    required this.players,
    required this.total,
    required this.best,
    required this.isRecord,
  });

  final PuzzleSide side;
  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final List<GamePlayer> players;
  final int total;

  /// The board's best time, or null when it has none yet.
  final BestTime? best;

  /// Whether this side's time beat the board's best.
  final bool isRecord;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final race = result.format.split;
    final badges = playersOn(side, result.format, teams, players);
    final r = result.sides[side]!;
    final line = r.finished ? HostText.seconds(r.timeS!) : HostText.piecesPlaced(r.placed, total);
    final boardBest = best;
    final detail = look.type.body.copyWith(fontSize: _detailPx, color: colors.ink);
    return Padding(
      padding: EdgeInsets.only(top: rowBadgeHeadroom(look), bottom: ToySizes.space4),
      child: Wrap(
        spacing: ToySizes.space8,
        runSpacing: ToySizes.space4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (race)
            SizedBox(
              width: look.sizes.buttonHeight * 2,
              child: Text(
                side == PuzzleSide.left ? HostText.left : HostText.right,
                style: look.type.button.copyWith(fontSize: _sideNamePx, color: colors.ink),
              ),
            ),
          for (final p in badges)
            PlayerBadge(number: p.number, size: look.sizes.buttonHeight * rowBadgeShare, character: p.character),
          Text(line, key: Key('puzzleResultLine-${side.name}'), style: detail),
          if (r.finished) Icon(Icons.check, size: _detailPx, color: colors.ink),
          if (r.finished && boardBest != null) ...[
            Text(
              RecordText.best(boardBest.timeMs),
              key: Key('bestTime-${side.name}'),
              style: detail.copyWith(color: colors.inkSoft),
            ),
            if (isRecord) const _NewRecordChip(),
          ],
        ],
      ),
    );
  }
}

/// The chip a finished board wears when it beat its best (T15, frame 14): the words with a star, in the focus yellow.
class _NewRecordChip extends StatelessWidget {
  const _NewRecordChip();

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Container(
      key: const Key('newRecord'),
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8, vertical: ToySizes.space4),
      decoration: BoxDecoration(
        color: look.colors.focus,
        border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
        borderRadius: BorderRadius.circular(ToySizes.cardCorner),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: look.type.body.fontSize, color: look.colors.ink),
          const SizedBox(width: ToySizes.space4),
          Text(RecordText.newRecord, style: look.type.body.copyWith(color: look.colors.ink)),
        ],
      ),
    );
  }
}
