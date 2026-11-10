/// Every word the party night's screens show a player (M14 c1, design section
/// 4), in one place like [HostText] (M13, design section 7): the picker's card,
/// the start card, the round's Next, the scoreboard and its final scores, and
/// the question asked when the host leaves.
///
/// The words are short and common (G5), for a child reading from the couch; a
/// number always stands beside an icon or a word, never alone. They live here
/// rather than in [HostText], which is near its limit and has another job
/// adding to it. The awards' own names and lines are the catalogue's data
/// (`night_awards.dart`), as a game's puzzle names are the puzzle data's.
abstract final class NightText {
  // The game picker's card.
  static const partyNight = 'Party night';
  static const partyNightLine = '3 or 5 rounds, points, awards';

  // The start card.
  static const rounds = 'Rounds';
  static const threeRounds = '3 rounds';
  static const fiveRounds = '5 rounds';
  static const awardsTitle = "The night's three awards";
  static const catLine = "The cat visits the side that's ahead.";
  static const bumperRound = 'Bumper Round';
  static const soon = 'Soon';

  /// Which round the host is about to pick a game for: "Pick round 1".
  static String pickRound(int round) => 'Pick round $round';

  // The results' one button in a night.
  static const next = 'Next';

  // The scoreboard.
  static String roundOf(int round, int of) => 'Round $round of $of';
  static const lastRoundBanner = 'Last round: double points!';
  static const finalScores = 'Final scores';
  static const backToGames = 'Back to games';

  /// What a round added to a player's total: "+7".
  static String roundPoints(int points) => '+$points';

  /// A player's place, shared with the players level with them: "1", "3=".
  static String place(int place, {required bool tied}) => tied ? '$place=' : '$place';

  /// A player's name on a row: their nickname, or their number when they have
  /// none ("P3"). A player the night never met has neither number nor name.
  static String playerName(String? nickname, int number) => nickname ?? 'P$number';

  // Leaving the night.
  static const endNight = 'End the party night?';
  static const yes = 'Yes';
  static const no = 'No';
}
