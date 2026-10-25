import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on. While people play with their phones nobody touches
/// the TV remote, so without this Android TV dims, starts its screensaver or
/// goes to sleep mid-game (seen in the M6 long-session run after about 10
/// minutes), which also drops every controller. A fake replaces it in tests.
abstract class ScreenAwake {
  Future<void> set(bool on);
}

/// FLAG_KEEP_SCREEN_ON on Android, SetThreadExecutionState on Windows.
class WakelockScreenAwake implements ScreenAwake {
  @override
  Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Not available (e.g. in tests without the plugin): the app still works.
    }
  }
}
