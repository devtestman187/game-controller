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

/// Robo's level with the name [json] holds, for the host's saved settings;
/// null when it names none (the settings then keep their own default).
RoboLevel? roboLevelOf(Object? json) => switch (json) {
  'easy' => RoboLevel.easy,
  'medium' => RoboLevel.medium,
  'hard' => RoboLevel.hard,
  _ => null,
};
