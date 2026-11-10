part of 'puzzle_screen.dart';

/// The results over the board: the winner, each side's finished picture as a
/// photo (design 3a), its time or pieces placed, its best time and any new
/// record (T15), and the first button (Rematch, Play again or Next puzzle),
/// Change teams and Back (T14). A night's round keeps only its Next (M14 c1).
class _Results extends ConsumerWidget {
  const _Results({
    required this.result,
    required this.teams,
    required this.total,
    required this.again,
    required this.onChangeTeams,
    required this.night,
    required this.puzzle,
    required this.match,
    required this.times,
  });

  final MatchResult result;
  final Map<String, PuzzleSide> teams;
  final int total;
  final _AgainButton again;
  final VoidCallback onChangeTeams;

  /// The puzzle played, and the round as it left it, for the photos (design
  /// 3a: an unfinished picture shows as it stood). The round's boards give each
  /// photo the field its pieces were placed in.
  final Puzzle puzzle;
  final PuzzleMatch? match;

  /// Whether this round is a night's: its results offer Next alone (design
  /// section 4), and the night's scoreboard follows it.
  final bool night;

  /// What this round did to each finished side's best time (T15): the chip
  /// says which boards beat theirs.
  final Map<PuzzleSide, BestTimeResult> times;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final players = ref.watch(gamePlayersProvider);
    final bestTimes = ref.watch(bestTimesProvider);
    final (:title, :colour) = _resultsHead(look, result);
    final photos = _photos();

    return ToyCard(
      key: const Key('puzzleResults'),
      header: title,
      headerKey: const Key('puzzleResultTitle'),
      headerColor: colour,
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space32, vertical: ToySizes.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (photos.isNotEmpty) ...[
            Row(mainAxisSize: MainAxisSize.min, children: photos),
            const SizedBox(height: ToySizes.space16),
          ],
          for (final side in result.sides.keys)
            _ResultSideRow(
              side: side,
              result: result,
              teams: teams,
              players: players,
              total: total,
              best: bestTimes.bestFor(puzzle.id, team: playersOn(side, result.format, teams, players).length > 1),
              isRecord: times[side]?.isRecord ?? false,
            ),
          const SizedBox(height: ToySizes.space24),
          _ResultButtons(again: again, onChangeTeams: onChangeTeams, night: night),
        ],
      ),
    );
  }

  /// Each side's picture as the round left it, side by side under the header
  /// (design 3a): its own board of a race, else the one board.
  List<Widget> _photos() {
    final round = match;
    if (round == null) return const [];
    final boards = round.snapshot().boards;
    final photos = <Widget>[];
    for (final side in result.sides.keys) {
      final index = result.format.split ? side.index : 0;
      if (index >= boards.length) continue;
      if (photos.isNotEmpty) photos.add(const SizedBox(width: ToySizes.space8));
      photos.add(
        _Photo(
          key: Key('puzzlePhoto-${side.name}'),
          side: side,
          puzzle: puzzle,
          board: boards[index],
          field: round.gameOf(side).field,
        ),
      );
    }
    return photos;
  }
}

/// One side's row on the results: its players, its time, or how many pieces it
/// placed, then the board's best time and the "New record!" chip when it beat
/// it (design 3a places a photo of each side's picture beside these rows; T15
/// adds the times, on the row so a small phone's card still fits).
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
              character: ToyCharacter.of(p.character, p.number),
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
          if (r.finished && boardBest != null) ...[
            const SizedBox(width: ToySizes.space12),
            Text(
              RecordText.best(boardBest.timeMs),
              key: Key('bestTime-${side.name}'),
              style: look.type.body.copyWith(color: colors.inkSoft),
            ),
            if (isRecord) ...[const SizedBox(width: ToySizes.space8), const _NewRecordChip()],
          ],
        ],
      ),
    );
  }
}

/// The chip a finished board wears when it beat its best (T15, frame 14):
/// "New record!", in the focus yellow with a star, so the words carry it too.
class _NewRecordChip extends StatelessWidget {
  const _NewRecordChip();

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Container(
      key: const Key('newRecord'),
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8, vertical: ToySizes.space4),
      decoration: BoxDecoration(
        color: colors.focus,
        border: Border.all(color: colors.ink, width: look.sizes.outlineWidth),
        borderRadius: BorderRadius.circular(ToySizes.cardCorner),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: look.type.body.fontSize, color: colors.ink),
          const SizedBox(width: ToySizes.space4),
          Text(RecordText.newRecord, style: look.type.body.copyWith(color: colors.ink)),
        ],
      ),
    );
  }
}
