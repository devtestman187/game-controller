import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'host_controller.dart';
import 'sound.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final logProvider = Provider<LogBuffer>((ref) {
  final log = LogBuffer();
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
});

final hostControllerProvider = Provider<HostController>((ref) {
  final controller = LiveHostController(prefs: ref.watch(prefsProvider), log: ref.watch(logProvider));
  unawaited(controller.start());
  ref.onDispose(controller.dispose);
  return controller;
});

final hostStateProvider = NotifierProvider<HostStateNotifier, HostViewState>(HostStateNotifier.new);

class HostStateNotifier extends Notifier<HostViewState> {
  @override
  HostViewState build() {
    final controller = ref.watch(hostControllerProvider);
    final sub = controller.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return controller.state;
  }
}

/// The newest log lines, updated as they arrive.
final logLinesProvider = NotifierProvider<LogLinesNotifier, List<LogLine>>(LogLinesNotifier.new);

class LogLinesNotifier extends Notifier<List<LogLine>> {
  @override
  List<LogLine> build() {
    final log = ref.watch(logProvider);
    final sub = log.changes.listen((_) => state = log.lines);
    ref.onDispose(sub.cancel);
    return log.lines;
  }
}

/// The TV's sounds. Overridden in tests with a FakeSoundPlayer.
final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = SoLoudSoundPlayer(log: ref.watch(logProvider).sink('sound'));
  unawaited(player.load());
  ref.onDispose(player.dispose);
  return player;
});

final soundStatusProvider = NotifierProvider<SoundStatusNotifier, SoundStatus>(SoundStatusNotifier.new);

class SoundStatusNotifier extends Notifier<SoundStatus> {
  @override
  SoundStatus build() {
    final player = ref.watch(soundPlayerProvider);
    final sub = player.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return player.status;
  }
}

/// A haptic event the TV fired: what, why, how many controllers got it.
typedef FiredEvent = ({HapticEventMessage message, String source, int reached, DateTime at});

/// Fires haptic events: plays the sound on the TV and sends the event to the
/// controller(s) together, so they always match. The state is the latest one.
final tvEventsProvider = NotifierProvider<TvEventsNotifier, FiredEvent?>(TvEventsNotifier.new);

class TvEventsNotifier extends Notifier<FiredEvent?> {
  @override
  FiredEvent? build() => null;

  /// [source] says what fired it (e.g. "panel", "game: wall"), for the log
  /// and the debug overlay. With no [controllerId] it goes to every
  /// connected controller.
  void fire(HapticEventMessage message, {required String source, String? controllerId}) {
    ref.read(soundPlayerProvider).play(message.event);
    final reached = ref.read(hostControllerProvider).sendHaptic(message, controllerId: controllerId);
    ref
        .read(logProvider)
        .add(
          'haptic',
          '${message.event.name} ${(message.intensity * 100).round()}% ${message.durationMs} ms ($source) '
              '→ ${reached == 0 ? 'no controller' : '$reached controller${reached == 1 ? '' : 's'}'}',
        );
    state = (message: message, source: source, reached: reached, at: DateTime.now());
  }
}
