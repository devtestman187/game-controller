import 'dart:async';
import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tv_host_setup.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final logProvider = Provider<LogBuffer>((ref) {
  // Big enough for a 30-minute session with a latency line every 30 s.
  final log = LogBuffer(capacity: 3000);
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
});

final hostServiceProvider = Provider<HostService>((ref) {
  final log = ref.watch(logProvider);
  final service = LiveHostService(
    prefs: ref.watch(prefsProvider),
    log: log,
    identity: tvHostIdentity(),
    directories: const TvDirectories(),
    advertiser: BonsoirAdvertiser(log: log.sink('tv')),
    uploader: tvUploader(),
  );
  unawaited(service.start());
  ref.onDispose(service.dispose);
  return service;
});

final hostStateProvider = NotifierProvider<HostStateNotifier, HostViewState>(HostStateNotifier.new);

class HostStateNotifier extends Notifier<HostViewState> {
  @override
  HostViewState build() {
    final controller = ref.watch(hostServiceProvider);
    final sub = controller.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return controller.state;
  }
}

/// The game host (PRD v2 P3): what the game and the test screens use.
final gameHostProvider = Provider<GameHost>((ref) => ref.watch(hostServiceProvider).gameHost);

/// The players in the game, by number: phones and local players (S2).
final gamePlayersProvider = NotifierProvider<GamePlayersNotifier, List<GamePlayer>>(GamePlayersNotifier.new);

class GamePlayersNotifier extends Notifier<List<GamePlayer>> {
  @override
  List<GamePlayer> build() {
    final host = ref.watch(gameHostProvider);
    final sub = host.playersChanged.listen((p) => state = p);
    ref.onDispose(sub.cancel);
    // Host state changes (a phone joins or switches mode) can also change
    // the list; reading it again keeps it in step.
    ref.listen(hostStateProvider, (_, _) {
      final now = host.players;
      if (!_same(now, state)) state = now;
    });
    return host.players;
  }

  static bool _same(List<GamePlayer> a, List<GamePlayer> b) =>
      a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);
}

/// Plays every sound a game asks for (PRD v2 S5). The home screen keeps it
/// running.
final gameSoundsProvider = Provider<void>((ref) {
  final player = ref.watch(soundPlayerProvider);
  final sub = ref.watch(hostServiceProvider).gameSounds.listen(player.play);
  ref.onDispose(sub.cancel);
});

/// Analytics (M9): the session files, consent and upload.
final statsServiceProvider = Provider<StatsService>((ref) => ref.watch(hostServiceProvider).stats);

final statsStateProvider = NotifierProvider<StatsStateNotifier, StatsState>(StatsStateNotifier.new);

class StatsStateNotifier extends Notifier<StatsState> {
  @override
  StatsState build() {
    final stats = ref.watch(statsServiceProvider);
    final sub = stats.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return stats.state;
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
    ref.read(soundPlayerProvider).play(message.event.name);
    final host = ref.read(gameHostProvider);
    final targets = controllerId != null ? [controllerId] : [for (final p in host.players) p.id];
    var reached = 0;
    for (final id in targets) {
      if (host.haptic(id, message)) reached++;
    }
    note(message, source: source, reached: reached);
  }

  /// Records an event a game already sent and played through the game host
  /// (S5), for the log and the debug overlay.
  void note(HapticEventMessage message, {required String source, required int reached}) {
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

/// Overridden in tests with a fake.
final screenAwakeProvider = Provider<ScreenAwake>((ref) => WakelockScreenAwake());

/// True while the screen is kept on: whenever a controller is connected (the
/// home screen keeps this alive).
final keepAwakeProvider = NotifierProvider<KeepAwakeNotifier, bool>(KeepAwakeNotifier.new);

class KeepAwakeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final on = ref.watch(hostStateProvider.select((s) => s.host.connected.isNotEmpty));
    final before = stateOrNull;
    if (before != on) {
      unawaited(ref.read(screenAwakeProvider).set(on));
      if (before != null || on) {
        ref
            .read(logProvider)
            .add('tv', on ? 'Keeping the screen on while controllers are connected' : 'The screen may sleep again');
      }
    }
    return on;
  }
}

/// Every puzzle, from the puzzle package's data files.
final puzzleLibraryProvider = FutureProvider<PuzzleLibrary>((ref) => PuzzleLibrary.load());

/// The puzzle's playtest settings (PRD v2 T16), saved on the TV.
final puzzleSettingsProvider = NotifierProvider<PuzzleSettingsNotifier, PuzzleSettings>(PuzzleSettingsNotifier.new);

class PuzzleSettingsNotifier extends Notifier<PuzzleSettings> {
  static const _key = 'puzzleSettings';

  @override
  PuzzleSettings build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return PuzzleSettings.defaults;
    try {
      return PuzzleSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return PuzzleSettings.defaults;
    }
  }

  void set(PuzzleSettings settings) {
    state = settings;
    unawaited(ref.read(prefsProvider).setString(_key, jsonEncode(settings.toJson())));
  }

  void reset() => set(PuzzleSettings.defaults);
}
