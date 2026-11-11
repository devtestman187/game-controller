import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../best_times.dart';
import '../providers.dart';
import '../text/host_text.dart';
import '../text/record_text.dart';
import 'host_screen.dart';

/// How wide a board's label ("Solo", "Team") takes, in logical pixels, so the
/// times beside it line up down the card.
const bestTimeLabelWidthPx = 72.0;

/// The best-times board (M14 f1, r5 finding 4; T15, design section 9 N14): the
/// fastest [bestTimesPerBoard] of every puzzle and level, solo and team kept
/// apart, each with the time and the names of the players on that board.
///
/// It is opened from a button on Shape Race's pick and only reads what the host
/// keeps, so a remote works it through the title bar's back arrow and the
/// button that opened it.
class BestTimesScreen extends ConsumerWidget {
  const BestTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(puzzleLibraryProvider);
    final times = ref.watch(bestTimesProvider);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: RecordText.bestTimesTitle,
        body: SafeArea(
          child: switch (library) {
            AsyncData(:final value) => _Board(library: value, times: times),
            AsyncError(:final error) => Center(child: Text(HostText.puzzlesFailed('$error'))),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

/// Each level's played puzzles, or the line that says nothing is kept yet.
class _Board extends ConsumerWidget {
  const _Board({required this.library, required this.times});

  final PuzzleLibrary library;
  final BestTimes times;

  /// The puzzles of [level] with a time on either board: a puzzle nobody has
  /// finished is left off, so the board is a list of records, not of puzzles.
  List<Puzzle> _played(Level level) => [
    for (final puzzle in library.ofLevel(level))
      if (times.boardFor(puzzle.id, team: false).isNotEmpty || times.boardFor(puzzle.id, team: true).isNotEmpty) puzzle,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final cards = [
      for (final level in Level.values)
        if (_played(level) case final puzzles when puzzles.isNotEmpty)
          _LevelBoard(level: level, puzzles: puzzles, times: times),
    ];
    if (cards.isEmpty) {
      return Center(
        child: Text(RecordText.noTimes, style: look.type.title.copyWith(color: look.colors.onBackground)),
      );
    }
    return ListView.separated(
      padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
      itemCount: cards.length,
      separatorBuilder: (context, i) => const SizedBox(height: ToySizes.space24),
      itemBuilder: (context, i) => cards[i],
    );
  }
}

/// One level's card (M13 3b's list): the level's name, then a puzzle's boards
/// under it.
class _LevelBoard extends StatelessWidget {
  const _LevelBoard({required this.level, required this.puzzles, required this.times});

  final Level level;
  final List<Puzzle> puzzles;
  final BestTimes times;

  @override
  Widget build(BuildContext context) {
    return ToyCard(
      header: HostText.level(level),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final puzzle in puzzles) ...[
            _PuzzleBoard(puzzle: puzzle, times: times),
            const SizedBox(height: ToySizes.space16),
          ],
        ],
      ),
    );
  }
}

/// The puzzle's name and the two boards' kept times under it.
class _PuzzleBoard extends StatelessWidget {
  const _PuzzleBoard({required this.puzzle, required this.times});

  final Puzzle puzzle;
  final BestTimes times;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(puzzle.name, style: look.type.button.copyWith(color: look.colors.ink)),
        const SizedBox(height: ToySizes.space4),
        for (final (label, team) in [(RecordText.solo, false), (RecordText.team, true)])
          if (times.boardFor(puzzle.id, team: team) case final board when board.isNotEmpty)
            _TimesRow(label: label, board: board),
      ],
    );
  }
}

/// One board's times ("Solo" or "Team"), fastest first, each with its names.
class _TimesRow extends StatelessWidget {
  const _TimesRow({required this.label, required this.board});

  final String label;
  final List<BestTime> board;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final style = look.type.body.copyWith(color: look.colors.ink);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: bestTimeLabelWidthPx,
          child: Text(label, style: style),
        ),
        Expanded(
          child: Wrap(
            spacing: ToySizes.space16,
            runSpacing: ToySizes.space4,
            children: [for (final time in board) Text(RecordText.entry(time.timeMs, time.names), style: style)],
          ),
        ),
      ],
    );
  }
}
