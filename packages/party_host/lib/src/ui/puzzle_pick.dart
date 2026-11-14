part of 'puzzle_screen.dart';

/// Which puzzle a round plays, and which one plays after it (B-009, m12 bug
/// 1108e, M14 c1): the round draws its level's next puzzle from the bag, and
/// the results' first button picks the one after it, from the same bag.
extension _PuzzlePick on _PuzzleScreenState {
  /// Picks the puzzle this round plays (B-009), once, as the screen opens: the
  /// round's own match when the caller passes one, else the level's next from
  /// its bag. It waits for the library, because a draw moves the bag's
  /// provider and a build may not change one.
  Future<Puzzle?> _pickedPuzzle() async {
    if (widget.match != null) return null;
    final PuzzleLibrary library;
    try {
      library = await ref.read(puzzleLibraryProvider.future);
    } catch (error) {
      // Reading the puzzles' files is the one boundary here: a build that
      // can't read them leaves the round on its spinner, as it always did.
      _log('Puzzle library: $error');
      return null;
    }
    return _picked(library);
  }

  /// What [library] plays this round: [PuzzleScreen.choice]'s own puzzle when
  /// it names one, else the next id of its level's bag.
  ///
  /// A chosen puzzle draws nothing from the bag; it only leaves it, so
  /// `any <level>` doesn't come back to it before the level's other puzzles.
  Puzzle? _picked(PuzzleLibrary library) {
    final choice = widget.choice;
    final id = choice.puzzleId;
    final bag = ref.read(puzzleBagProvider.notifier);
    if (id != null) {
      final chosen = library.byId(id);
      if (chosen != null) bag.played(choice.level, id);
      return chosen;
    }
    final ids = [for (final puzzle in library.ofLevel(choice.level)) puzzle.id];
    final drawn = bag.draw(level: choice.level, ids: ids, random: _random, avoidId: widget.avoidPuzzleId);
    return drawn == null ? null : library.byId(drawn);
  }

  /// The first button on the results (m12 bug 1108e), by what this round
  /// played: a round that found its puzzle from `any <level> puzzle` plays
  /// another of the level, so its button says Next puzzle; a round of one
  /// chosen puzzle, or of a level that holds only this one, plays it again, as
  /// Rematch in a race and Play again on one board.
  ///
  /// A night's round has one button, Next (M14 c1, design section 4): the
  /// round is over and the night goes on, so there is nothing to play again
  /// and the teams are picked in the next round's join screen anyway.
  _AgainButton get _again {
    if (ref.read(partyNightProvider) != null) {
      return (label: NightText.next, icon: Icons.skip_next, key: 'next', focusNode: _againFocus, onPressed: _next);
    }
    final race = _result?.format.split ?? false;
    final level = widget.choice.level;
    final another = (ref.read(puzzleLibraryProvider).whenOrNull(data: (l) => l.ofLevel(level).length) ?? 0) > 1;
    final (label, icon, key) = widget.choice.puzzleId == null && another
        ? (HostText.nextPuzzle, Icons.skip_next, 'nextPuzzle')
        : race
        ? (HostText.rematch, Icons.replay, 'rematch')
        : (HostText.playAgain, Icons.replay, 'playAgain');
    return (label: label, icon: icon, key: key, focusNode: _againFocus, onPressed: _rematch);
  }

  /// The first button's press: the same teams; a random puzzle becomes
  /// another one of the level.
  void _rematch() {
    _log('Results: ${_again.label}');
    _replaceWith(
      PuzzleScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard, avoidPuzzleId: _puzzle?.id),
    );
  }

  void _changeTeams() => _replaceWith(JoinScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard));
}
