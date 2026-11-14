part of 'puzzle_screen.dart';

/// Which puzzle a round plays, and which one plays after it (B-009, m12 bug
/// 1108e, M14 c1, B-011): the round draws its level's next puzzle from the bag,
/// and the results' buttons pick the one after it: the same bag for a round of
/// `any <level> puzzle`, the series' own played ids for a hand-picked one.
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

  /// The series this screen starts, when its choice names a puzzle (B-011):
  /// the picked id is its first round, and the round shows it in [_showPuzzle].
  PuzzleSeries? _startedSeries() {
    final choice = widget.choice;
    final id = choice.puzzleId;
    return id == null ? null : PuzzleSeries.start(choice.level).withPlayed(id);
  }

  /// What this round's results offer (B-011): a night's one Next (M14 c1,
  /// design section 4 — the round is over, the night goes on, and the teams are
  /// picked in the next round's join screen anyway), an `any <level> puzzle`
  /// round's own next (m12 bug 1108e), or a series round's menu.
  _ResultMenu get _menu {
    if (ref.read(partyNightProvider) != null) {
      return (
        again: (label: NightText.next, icon: Icons.skip_next, key: 'next', focusNode: _againFocus, onPressed: _next),
        replay: null,
        series: null,
      );
    }
    final series = _series;
    return series == null ? (again: _anyPuzzleAgain(), replay: null, series: null) : _seriesMenu(series);
  }

  /// The first button after an `any <level> puzzle` round (m12 bug 1108e): Next
  /// puzzle when the level has another one, else the round-again button, which
  /// its own replay serves.
  _AgainButton _anyPuzzleAgain() {
    final level = widget.choice.level;
    final another = (ref.read(puzzleLibraryProvider).whenOrNull(data: (l) => l.ofLevel(level).length) ?? 0) > 1;
    final words = another ? (label: HostText.nextPuzzle, icon: Icons.skip_next, key: 'nextPuzzle') : _replayWords();
    return (
      label: words.label,
      icon: words.icon,
      key: words.key,
      focusNode: _againFocus,
      onPressed: () => _rematch(words.label),
    );
  }

  /// A series round's results (B-011, design items 2 and 3): Next puzzle with
  /// the Shuffle switch and Play again beside it; once every puzzle of the
  /// level has played, the prompt's Continue to the next level takes Next
  /// puzzle's place; on the last level Play again is the first button and
  /// nothing leads on.
  _ResultMenu _seriesMenu(PuzzleSeries series) {
    final level = series.level;
    final shuffle = (isOn: series.isShuffled, onChanged: _shuffle);
    final next = series.nextId(ids: _levelIds(level), current: _puzzle?.id, random: _random);
    if (next != null) {
      return (
        again: _firstButton(HostText.nextPuzzle, 'nextPuzzle', () => _nextInSeries(series, level, next)),
        replay: _replayButton(),
        series: (shuffle: shuffle, prompt: null),
      );
    }
    final prompt = HostText.playedEvery(HostText.level(level));
    final after = _nextLevel(level);
    if (after == null) {
      return (again: _firstReplay(), replay: null, series: (shuffle: null, prompt: prompt));
    }
    return (
      again: _firstButton(
        HostText.continueTo(HostText.level(after)),
        'continueLevel',
        () => _continueTo(series, after),
      ),
      replay: _replayButton(),
      series: (shuffle: shuffle, prompt: prompt),
    );
  }

  /// A results' first button that holds the focus, so the phone's A and the
  /// remote's OK work at once (B-011).
  _AgainButton _firstButton(String label, String key, VoidCallback onPressed) =>
      (label: label, icon: Icons.skip_next, key: key, focusNode: _againFocus, onPressed: onPressed);

  /// The round-again button beside the first one (B-011): no focus of its own,
  /// since the pad reaches it with a right.
  _MenuButton _replayButton() {
    final words = _replayWords();
    return (label: words.label, icon: words.icon, key: words.key, onPressed: () => _replay(words.label));
  }

  /// Play again as the first button, on the level that has nothing after it
  /// (B-011): the pad's OK then starts the series' puzzle again.
  _AgainButton _firstReplay() {
    final words = _replayWords();
    return (
      label: words.label,
      icon: words.icon,
      key: words.key,
      focusNode: _againFocus,
      onPressed: () => _replay(words.label),
    );
  }

  /// The words of the round-again button: Rematch in a race, Play again on one
  /// board, with the keys the results' tests and the host's log know.
  ({String label, IconData icon, String key}) _replayWords() => (_result?.format.split ?? false)
      ? (label: HostText.rematch, icon: Icons.replay, key: 'rematch')
      : (label: HostText.playAgain, icon: Icons.replay, key: 'playAgain');

  /// The first button's press after an `any <level> puzzle` round: the same
  /// teams; a random puzzle becomes another one of the level.
  void _rematch(String label) {
    _log('Results: $label');
    _replaceWith(
      PuzzleScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard, avoidPuzzleId: _puzzle?.id),
    );
  }

  /// Play again in a series (B-011): the same puzzle and the same teams, and
  /// the series goes on, with its played ids and its Shuffle.
  void _replay(String label) {
    _log('Results: $label');
    _replaceWith(PuzzleScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard, series: _series));
  }

  /// Next puzzle in a series (B-011): [id] of [level], the first one not
  /// played, with the same teams and the series.
  void _nextInSeries(PuzzleSeries series, Level level, String id) {
    _log('Results: ${HostText.nextPuzzle}');
    _replaceWith(
      PuzzleScreen(
        choice: PuzzleChoice(level: level, puzzleId: id),
        teams: widget.teams,
        keyboard: _keyboard,
        series: series,
      ),
    );
  }

  /// Continue to the next level once a series has played every puzzle of its
  /// level (B-011, design item 3): that level's first puzzle, or a random one
  /// while Shuffle is on, with a fresh played set.
  void _continueTo(PuzzleSeries series, Level level) {
    _log('Results: ${HostText.continueTo(HostText.level(level))}');
    final ids = _levelIds(level);
    if (ids.isEmpty) return;
    final moved = series.atLevel(level);
    final id = moved.nextId(ids: ids, random: _random);
    if (id == null) return;
    _replaceWith(
      PuzzleScreen(
        choice: PuzzleChoice(level: level, puzzleId: id),
        teams: widget.teams,
        keyboard: _keyboard,
        series: moved,
      ),
    );
  }

  /// The ids of [level] in the library's order, the order Next puzzle walks.
  List<String> _levelIds(Level level) => [for (final puzzle in _library?.ofLevel(level) ?? const <Puzzle>[]) puzzle.id];

  /// The next level a series can go on to (B-011), or null on the last one.
  Level? _nextLevel(Level level) {
    final library = _library;
    return library == null ? null : PuzzleSeries.levelAfter(library, level);
  }

  /// The puzzle library as the results read it, once it has loaded.
  PuzzleLibrary? get _library => ref.read(puzzleLibraryProvider).whenOrNull(data: (library) => library);

  /// A night's Next (M14 c1, design section 4): the round is recorded, and the
  /// scoreboard follows — or, after the night's last round, the awards' reveal,
  /// whose final scores take the scoreboard's place (job c2). Everything above
  /// the game picker goes, so a night of five rounds leaves a phone five routes,
  /// not fifteen.
  void _next() {
    final result = _result;
    if (result == null) return;
    _log('Results: ${NightText.next}');
    ref.read(partyNightProvider.notifier).recordRound(result.round);
    final over = ref.read(partyNightProvider)?.isOver ?? false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => over ? const NightRevealScreen() : const NightScoreboardScreen()),
      isGamePickerRoute,
    );
  }

  void _changeTeams() => _replaceWith(JoinScreen(choice: widget.choice, teams: widget.teams, keyboard: _keyboard));
}
