/// The race's words on the host's settings screen (M17 race1a f1e). Kept out of
/// host_text.dart, which is at its 380-line gate.
const playersPerSideLabel = 'Players per side';

/// The players-per-side value as a plain number: no unit, unlike the seconds.
String playersPerSideValue(num v) => '${v.round()}';
