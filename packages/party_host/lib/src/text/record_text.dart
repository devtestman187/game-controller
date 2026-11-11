/// The best times' words on Shape Race's results (M14 c2, PRD v2 T15, design
/// section 9 N14), in one place like [NightText] and [ArenaText]: the record's
/// chip and the board's best time. They live here rather than in [HostText],
/// which is near its limit and has another job adding to it.
abstract final class RecordText {
  /// The chip a finished board wears when it beat its best.
  static const newRecord = 'New record!';

  /// The board's own name, on the picker's button and its title bar (M14 f1,
  /// r5 finding 4).
  static const bestTimesTitle = 'Best times';

  /// The two boards a puzzle keeps times for (design section 9 N14): a board
  /// played by one player, and one played by a side of two or more.
  static const solo = 'Solo';
  static const team = 'Team';

  /// What the board says on a host that has played nothing yet.
  static const noTimes = 'No times yet';

  /// One kept time as the board lists it: "1:28 · Dad", or a side's names after
  /// it, "1:50 · Mia, Dad".
  static String entry(int timeMs, List<String> names) => '${clock(timeMs)} · ${names.join(', ')}';

  /// A board's best time: "Best 1:45".
  static String best(int timeMs) => 'Best ${clock(timeMs)}';

  /// A time in ms as minutes and whole seconds, as a stopwatch says it:
  /// "0:07", "1:45". A tenth of a second left off: a best time is a quick
  /// glance, not a measurement.
  static String clock(int timeMs) {
    final seconds = timeMs ~/ _msPerS;
    final minute = seconds ~/ _sPerMin;
    final rest = (seconds % _sPerMin).toString().padLeft(_secondDigits, '0');
    return '$minute:$rest';
  }
}

/// One second in milliseconds, the step [RecordText.clock] reads a time in:
/// the game counts in whole milliseconds and reports seconds as a fraction.
const _msPerS = 1000;

/// How many seconds a minute has: where [RecordText.clock] moves to the next
/// minute.
const _sPerMin = 60;

/// How many digits a minute's seconds take: "0:07" rather than "0:7".
const _secondDigits = 2;
