import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'host_service.dart';

/// True from the moment the host app is hidden until it's shown again
/// (m12 §2.10). The screens pause the game then, as they do for an open
/// pause menu, without showing it.
///
/// The phone app overrides it with its [HostPresence.away]; the default never
/// goes away, so the TV never pauses this way.
final hostAwayProvider = Provider<ValueListenable<bool>>((ref) => const _NeverAway());

/// Pauses the game while the host app is hidden, and ends the round when it
/// stays hidden longer than [graceS] (m12 §2.10).
///
/// The shell drives it from the app's lifecycle (`hidden` when the app goes
/// to the background or the screen locks, `shown` when it comes back), and
/// supplies [onAbandon], which leaves the round for the game picker (see
/// `abandonRound`).
class HostPresence {
  /// [nowMs] is the clock the hidden time is measured on; [graceS] is how
  /// long the app may stay hidden before the round is abandoned (30 s).
  HostPresence({required this.host, required this.onAbandon, int Function()? nowMs, this.graceS = 30})
    : _nowMs = nowMs ?? _monotonicMs;

  /// The host whose server and advertising [shown] restarts.
  final HostService host;

  /// Ends the round: the host lost sight of it for longer than [graceS].
  final void Function() onAbandon;

  /// How long the app may stay hidden and still keep the round, in s.
  final int graceS;

  final int Function() _nowMs;
  final _away = ValueNotifier<bool>(false);
  int? _hiddenAtMs;
  bool _disposed = false;

  /// True from the moment the app is hidden until it's shown again.
  ValueListenable<bool> get away => _away;

  /// The app went to the background or the screen locked.
  void hidden() {
    if (_disposed || _hiddenAtMs != null) return;
    // One period until it's shown: a second report of the same background
    // doesn't restart the grace period.
    _hiddenAtMs = _nowMs();
    _away.value = true;
  }

  /// The app is back: restarts what the system stopped, then unpauses. Hidden
  /// for longer than [graceS], the round is abandoned instead.
  Future<void> shown() async {
    final at = _hiddenAtMs;
    if (_disposed || at == null) return;
    final awayMs = _nowMs() - at;
    _hiddenAtMs = null;
    // The server and the advertising come back first, while the game is
    // still paused, so a phone can reconnect before the pause ends.
    await host.resume();
    if (_disposed) return;
    // Too long away: the round ends without running another step.
    if (awayMs > graceS * Duration.millisecondsPerSecond) onAbandon();
    _away.value = false;
  }

  /// Stops listening: after it, [hidden] and [shown] do nothing. Calling it
  /// again does nothing.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _hiddenAtMs = null;
    _away.dispose();
  }
}

/// The clock [HostPresence] measures a hidden period on when the shell passes
/// none: monotonic, so a clock change while hidden can't lengthen it.
final _clock = Stopwatch()..start();

int _monotonicMs() => _clock.elapsedMilliseconds;

/// The default [hostAwayProvider] value: a host that never goes away.
final class _NeverAway implements ValueListenable<bool> {
  const _NeverAway();

  @override
  bool get value => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
