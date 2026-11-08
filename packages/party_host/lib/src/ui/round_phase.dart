import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a round on this device is doing (m12-host-touch rules 1–3). The host
/// phone reads it for its own pad and its top bar; the TV and the joined
/// phones never do (rule 6).
enum RoundPhase {
  /// No round is on: the game picker, a game's own screens, the join screen,
  /// the results, or a round that stands still (the pause menu, the away card,
  /// the host app away).
  none,

  /// The round is up and held for the "Get ready" beat (m12-host-touch rule 3);
  /// s10c writes it.
  ready,

  /// The round is running.
  playing,
}

/// The round's phase, as the round's screen writes it: [Pausable] says
/// [RoundPhase.playing] while its round runs and clears it to
/// [RoundPhase.none] as the round's screen goes.
///
/// A [ValueNotifier] in a provider and not a provider's state, so the screen
/// may still write it while it is disposed (a provider changed from a widget's
/// dispose is refused, see `hosting.dart`).
class RoundPhaseSignal extends ValueNotifier<RoundPhase> {
  RoundPhaseSignal() : super(RoundPhase.none);

  /// The screen whose round this is.
  Object? _writer;

  /// The scope this signal lived in is gone: a change still on its way has
  /// nothing left to tell.
  bool _disposed = false;

  /// [writer]'s round owns the phase from here. The screen that replaces it
  /// (Play again) claims first and the old one is disposed after it (M10), so
  /// the old one's [release] leaves the new round's phase alone.
  void claim(Object writer) => _writer = writer;

  /// [writer]'s round is [phase]. Only the round that claimed the phase last
  /// speaks for it: a screen that is still on its way out publishes over
  /// nothing (M10).
  void publish(Object writer, RoundPhase phase) {
    if (!identical(_writer, writer)) return;
    value = phase;
  }

  /// [writer]'s round is gone: [RoundPhase.none], unless a screen has claimed
  /// the phase since. A round whose screen goes while it runs (the app was
  /// away too long) is disposed with the widget tree locked, so the change
  /// comes a frame later, as every other phase change does (M10).
  void release(Object writer) {
    if (!identical(_writer, writer)) return;
    _writer = null;
    if (value == RoundPhase.none) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A screen that replaced this round says its own phase: leave it be.
      if (_disposed || _writer != null) return;
      value = RoundPhase.none;
    });
    // A frame to say it in: nothing else may be drawing here.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The round's phase, for the host phone's own screens (m12-host-touch rules
/// 1–3): the pad is not built while it is [RoundPhase.none], and the top bar
/// is the full one. Disposed with the scope.
final roundPhaseProvider = Provider<RoundPhaseSignal>((ref) {
  final signal = RoundPhaseSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
