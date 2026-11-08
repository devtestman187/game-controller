/// How the Look setting is set (design D1): the device picks a palette itself
/// by its local time, or the player pins one.
///
/// The apps save it by [name], so a saved setting survives a build that adds a
/// choice: [fromName] reads an unknown name as [auto].
enum LookChoice {
  /// Sunny in the day and Night in the evening, by the device's local time.
  auto,

  /// Always the Sunny palette.
  sunny,

  /// Always the Night palette.
  night;

  /// The choice saved as [name], or [auto] for an unknown or a missing name.
  static LookChoice fromName(String? name) {
    for (final choice in values) {
      if (choice.name == name) return choice;
    }
    return auto;
  }
}

/// The two palettes of the look (design section 3). The palette is only colour:
/// every size, shape and outline is the same in both, so each screen is
/// designed once.
enum ToyPalette { sunny, night }

/// The first hour of Auto's Sunny stretch, inclusive (design D1: "Sunny from
/// 7:00 to 19:00, Night otherwise"), on the device's own clock.
const sunnyFromHour = 7;

/// The first hour of Auto's Night stretch, exclusive: 18:59 is still Sunny.
const sunnyUntilHour = 19;

/// The palette a screen shows, for the Look setting [choice] and the device's
/// [localTime] (design D1).
///
/// Nothing here reads a clock: the caller passes the time, because it decides
/// when a screen opens and a round never changes its palette in the middle.
ToyPalette paletteFor(LookChoice choice, DateTime localTime) {
  return switch (choice) {
    LookChoice.sunny => ToyPalette.sunny,
    LookChoice.night => ToyPalette.night,
    LookChoice.auto =>
      localTime.hour >= sunnyFromHour && localTime.hour < sunnyUntilHour ? ToyPalette.sunny : ToyPalette.night,
  };
}
