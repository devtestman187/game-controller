/// Robo's level (M14 design section 7a), picked on the Arena's waiting card
/// while Robo is in: Easy the first time, remembered on the host.
///
/// The level is one table of numbers in the CPU's pilot, and the pilot is job
/// b3: the session's Robo seat takes this level and adds Robo's input to the
/// same map of inputs the phones fill, so the rules never learn that Robo is a
/// CPU. Until then the waiting card shows the choice and the host stores it;
/// this type is the one named place b3 reads it from.
enum RoboLevel {
  /// A child around 8 wins about 4 rounds in 5.
  easy,

  /// About even with a child.
  medium,

  /// An adult has to try.
  hard,
}

/// Robo's id in the round's inputs and snapshot (party-night §7a, M14 b3): the
/// session adds a marble under this id from [CpuPilot], so the rules, the
/// frames and every viewer treat Robo as a seat — and the host's player list
/// never holds it, so awards and stats never count it.
const roboPlayerId = 'robo';

/// The name Robo wears on the host and on joined phones (design section 7a).
const roboName = 'Robo';

/// The player number Robo's colour comes from: the lowest number in [numbers]
/// that no player has (design section 7a: Robo wears the next free player
/// colour, and no number of its own). The host's cards and every viewer's
/// roster ask this, so Robo's disc is one colour on every screen.
int roboNumberFor(Iterable<int> numbers) {
  final used = {for (final number in numbers) number};
  var number = 1;
  while (used.contains(number)) {
    number++;
  }
  return number;
}

/// Robo's level with the name [json] holds, for the host's saved settings;
/// null when it names none (the settings then keep their own default).
RoboLevel? roboLevelOf(Object? json) => switch (json) {
  'easy' => RoboLevel.easy,
  'medium' => RoboLevel.medium,
  'hard' => RoboLevel.hard,
  _ => null,
};
