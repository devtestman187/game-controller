/// Every word the "Try the shop" demo screen shows (phone shop, owner decision Nov 26), in one place like
/// [NightText]: the title, the cards, the countdown and each player's row.
///
/// The words are short and common (G5), for a child reading from the couch. They live here rather than in
/// [HostText], which is at its 380-line limit and has another job adding to it.
abstract final class ShopText {
  static const title = 'Spend your Bolts';
  static const currency = 'Bolts';

  // The cards.
  static const build = 'Build';
  static const save = 'Save +2';
  static const roadworks = 'Roadworks';

  // The line shown instead of a round when no phone has joined.
  static const needsPhones = 'Join with phones to try the shop';

  // A player's row while the round runs, and once it ends.
  static const lockedIn = 'locked in';
  static const choosing = 'choosing...';
  static const timeUp = 'Time is up';
  static const nothing = 'Nothing';
  static const byDefault = ' (by default)';

  /// The countdown: "12 s left".
  static String secondsLeft(int seconds) => '$seconds s left';

  /// One player's row: "Ann: Build 2 = 6 Bolts".
  static String row(String name, String what) => '$name: $what';

  /// What a stacked card came to: "Build 2 = 6 Bolts".
  static String counted(String title, int count, int total, String unit) => '$title $count = $total $unit';
}
