/// Keeps the screen on. While people play with their phones nobody touches
/// the TV remote, so without this Android TV dims, starts its screensaver or
/// goes to sleep mid-game (seen in the M6 long-session run after about 10
/// minutes), which also drops every controller. A fake replaces it in tests;
/// the platform adapter (`WakelockScreenAwake`) arrives at G3.
abstract class ScreenAwake {
  /// Turns the keep-awake on or off.
  Future<void> set(bool on);
}
