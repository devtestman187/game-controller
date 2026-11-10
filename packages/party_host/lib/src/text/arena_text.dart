/// Every word the Arena's own screens show a player (M14 b2, design sections
/// 7 and 8): the waiting card, its map picker and Robo's line, the Bumper
/// Round's results card, and the night's "joins next round". They live here
/// rather than in [HostText], which is near its limit and has another job
/// adding to it, as the night's words live in [NightText].
///
/// The words are short and common (G5), for a child reading from the couch. A
/// game's name is [HostText]'s (`Arena`, and the modes' own names are here
/// because the picker only ever says them), and a level's name is
/// [HostText.easy], [HostText.medium] and [HostText.hard].
abstract final class ArenaText {
  // The waiting card.
  static const bumper = 'Bumper';
  static const race = 'Race';
  static const code = 'Code';
  static const ready = "Press A when you're ready.";
  static const map = 'Map';
  static const surpriseMe = 'Surprise me';

  // Robo, while one player is joined (design section 7a).
  static const robo = 'Robo';
  static const roboJoins = 'Robo joins you';
  static const roboLevel = 'Robo:';

  // A player who joined while a Bumper Round runs (design section 8).
  static String joinsNextRound(String name) => '$name joins next round';

  // The results card.
  static const changeMode = 'Change mode';

  /// The coins a player took: "4 coins", or "1 coin".
  static String coins(int count) => count == 1 ? '1 coin' : '$count coins';

  /// Who won the round: "P1 Mia wins!".
  static String wins(String name) => '$name wins!';
}
