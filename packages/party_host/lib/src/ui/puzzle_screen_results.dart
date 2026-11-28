part of 'puzzle_screen.dart';

/// What the Shape Race results do after the round (T14, M14 c1, B-021): the
/// buttons' routes, the reveal of a night the host ended early, and the Back
/// that records a night's round like Next. Here, not in the screen's own file,
/// for its size.
extension _PuzzleResultsRoute on _PuzzleScreenState {
  /// A night's End night (B-021): the round just played is recorded and the
  /// night ends on it, so the awards' reveal follows, then its final scores.
  void _endNight() {
    final result = _result;
    if (result == null) return;
    _log('Results: ${NightText.endNightNow}');
    ref.read(partyNightProvider.notifier).endNow(result.round);
    _showAfterNight(const NightRevealScreen());
  }

  /// Each frame of the round: its clock, for the music's tempo (M13 design section 8, rule 3), and its present, for
  /// the pop's confetti and the results' line (M17 r3f).
  void _clocked(int timeLeftMs, int warningS) {
    _music.roundScreenClock(this, timeLeftMs: timeLeftMs, warningS: warningS);
    _present.feed(_play.currentState?.match.present);
  }

  /// Replaces every route above the game picker with [screen], so a night of
  /// five rounds leaves a phone five routes, not fifteen.
  void _showAfterNight(Widget screen) =>
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => screen), isGamePickerRoute);

  /// The route asked: on the results the answer is the game picker. A round
  /// that waits for a phone that dropped stays where it is: the away card
  /// blocks the Back and is the way on (m12 code health N1). Only a phone the
  /// round seats counts (M16 item 2): a lobby slot waits on no results.
  void _leaveForGames(bool didPop) {
    final away = ref.read(playersAwayProvider);
    if (didPop || awayInRound(away, widget.teams.keys.toSet()).isNotEmpty) return;
    // A night's round is played and scored: Back records it as Next does, and
    // the scoreboard's Back is the one that asks to end the night.
    if (ref.read(partyNightProvider) != null) return _next();
    _log('Results: back to the games');
    leaveForGamePicker(context);
  }
}
