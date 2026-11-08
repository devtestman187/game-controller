import 'dart:async';
import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'advertiser.dart';
import 'controls.dart';
import 'host_device_monitor.dart';
import 'host_directories.dart';
import 'host_identity.dart';
import 'host_service.dart';
import 'host_view_state.dart';
import 'local_player_source.dart';
import 'screen_awake.dart';
import 'session_uploader.dart';
import 'sound.dart';
import 'stats_service.dart';
import 'stats_state.dart';

/// The host app's own identity (S-a). Overridden in each app's `main()`: the
/// TV app builds it from `app_info.dart` and the platform, the phone app
/// later from its own.
final hostIdentityProvider = Provider<HostIdentity>(
  (ref) => throw UnimplementedError('hostIdentityProvider must be overridden'),
);

/// Where the host keeps its session files (M12 design §2.6). Overridden in
/// each app's `main()`: the TV app with `path_provider`, the phone app later
/// with its own folders.
final hostDirectoriesProvider = Provider<HostDirectories>(
  (ref) => throw UnimplementedError('hostDirectoriesProvider must be overridden'),
);

/// Overridden in each app's `main()` with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final logProvider = Provider<LogBuffer>(_logBuffer);

/// The host's one log, which [logProvider] keeps for the app's life.
LogBuffer _logBuffer(Ref ref) {
  // Big enough for a 30-minute session with a latency line every 30 s.
  final log = LogBuffer(capacity: 3000);
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
}

/// Finds the host on the network (S-b). The default advertises it with
/// Bonsoir; tests override it with a fake.
final advertiserProvider = Provider<Advertiser>((ref) => BonsoirAdvertiser(log: ref.watch(logProvider).sink('host')));

/// Sends finished sessions to the cloud store (M9). Null when the shell's
/// build has no store set up; each app overrides it with its own.
final sessionUploaderProvider = Provider<SessionUploader?>((ref) => null);

/// Whether the phones that join show the game this host runs (m12-joined-view §0.1). False
/// by default: this host's own screen is the one everyone watches. The dev TV
/// app overrides it with its debug `SHARE_VIEW` define, so a measuring run and
/// the smoke check keep their viewers.
final shareViewProvider = Provider<bool>((ref) => false);

/// How this host runs a game (m12 §3): the frame rate its rounds send frames
/// at. A debug build's start option decides it; the phone app overrides it
/// with its saved "Frame rate (test)" setting.
final hostingSettingsProvider = Provider<HostingSettings>((ref) => HostingSettings.fromEnvironment());

/// How long a round is held for the "Get ready" beat before its first step
/// (m12-host-touch rule 3): the rules and the round's clock stand still while
/// the pad comes up, and the card over the game counts the seconds down. Zero
/// by default, so the TV and the joined phones start as they always did (rule
/// 6); the phone app asks for `Pausable.ready`, 3 s.
final readyCountdownProvider = Provider<Duration>((ref) => Duration.zero);

/// Reads the host device's battery and heat for the session summary (m12
/// §0.1). None by default, so the TV records nothing; the phone app overrides
/// it with an adapter over its `DeviceStatusSource`.
final hostDeviceMonitorProvider = Provider<HostDeviceMonitor>((ref) => const NoHostDeviceMonitor());

/// The host's own player in the round it runs (m12-phone-layout §3): the
/// phone host overrides it with its client's controller ID, so its screen
/// draws its own side of a `phones` match, as a joined phone would. Null on
/// the TV, which draws the whole match as it always has.
final ownPlayerIdProvider = Provider<String?>((ref) => null);

/// Whether this host's screen draws the whole `phones` match instead of one
/// side (m12-phone-layout §0.6): the phone app sets it on a tablet, which has
/// the room for both sides. False by default, so the TV and a phone draw what
/// they always did.
final wholeMatchProvider = Provider<bool>((ref) => false);

/// The host service and everything it runs, built from the providers above so
/// an app only supplies its own inputs.
final hostServiceProvider = Provider<HostService>((ref) {
  final service = LiveHostService(
    prefs: ref.watch(prefsProvider),
    log: ref.watch(logProvider),
    identity: ref.watch(hostIdentityProvider),
    directories: ref.watch(hostDirectoriesProvider),
    advertiser: ref.watch(advertiserProvider),
    uploader: ref.watch(sessionUploaderProvider),
    shareView: ref.watch(shareViewProvider),
    monitor: ref.watch(hostDeviceMonitorProvider),
  );
  unawaited(service.start());
  ref.onDispose(service.dispose);
  return service;
});

final hostStateProvider = NotifierProvider<HostStateNotifier, HostViewState>(HostStateNotifier.new);

/// Keeps the latest host state, for the screens that show it.
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

/// Keeps the player list in step with the game host.
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

/// Keeps the latest stats state, for the Stats screen.
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

/// Keeps the log panel's lines current.
class LogLinesNotifier extends Notifier<List<LogLine>> {
  @override
  List<LogLine> build() {
    final log = ref.watch(logProvider);
    final sub = log.changes.listen((_) => state = log.lines);
    ref.onDispose(sub.cancel);
    return log.lines;
  }
}

/// The host's sounds. Overridden in tests with a FakeSoundPlayer.
final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = SoLoudSoundPlayer(log: ref.watch(logProvider).sink('sound'));
  unawaited(player.load());
  ref.onDispose(player.dispose);
  return player;
});

final soundStatusProvider = NotifierProvider<SoundStatusNotifier, SoundStatus>(SoundStatusNotifier.new);

/// Keeps the sound player's status, for the home screen and the panel.
class SoundStatusNotifier extends Notifier<SoundStatus> {
  @override
  SoundStatus build() {
    final player = ref.watch(soundPlayerProvider);
    final sub = player.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return player.status;
  }
}

/// A haptic event the host fired: what, why, how many controllers got it.
typedef FiredEvent = ({HapticEventMessage message, String source, int reached, DateTime at});

/// Fires haptic events: plays the sound on the host and sends the event to
/// the controller(s) together, so they always match. The state is the latest
/// one.
final tvEventsProvider = NotifierProvider<TvEventsNotifier, FiredEvent?>(TvEventsNotifier.new);

/// The host's last haptic event, and firing a new one.
class TvEventsNotifier extends Notifier<FiredEvent?> {
  @override
  FiredEvent? build() => null;

  /// [source] says what fired it (e.g. "panel", "game: wall"), for the log
  /// and the debug overlay. With no [controllerId] it goes to every
  /// connected controller.
  void fire(HapticEventMessage message, {required String source, String? controllerId}) {
    ref.read(soundPlayerProvider).play(message.event.name);
    final host = ref.read(gameHostProvider);
    // A phone that is away can't feel it (m12 bug 1107d).
    final targets = controllerId != null
        ? [controllerId]
        : [
            for (final p in host.players)
              if (!p.away) p.id,
          ];
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

/// Keeps the screen on while any controller is connected (PRD T5).
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

/// The screens' claims on the controllers, newest on top (PRD v2 T21). With
/// none, the controllers work the menus.
final controlsClaimsProvider = Provider<ControlsClaims>((ref) => ControlsClaims());

/// Builds the local player for this host (S-c). The default offers none; the
/// TV app overrides it with its keyboard player on a desktop.
final localPlayerSourceProvider = Provider<LocalPlayerSourceFactory>(
  (ref) =>
      (host, {onJoined}) => const NoLocalPlayerSource(),
);

/// Every puzzle, from the puzzle package's data files.
final puzzleLibraryProvider = FutureProvider<PuzzleLibrary>((ref) => PuzzleLibrary.load());

/// The puzzle's playtest settings (PRD v2 T16), saved on the host.
final puzzleSettingsProvider = NotifierProvider<PuzzleSettingsNotifier, PuzzleSettings>(PuzzleSettingsNotifier.new);

/// Saves and resets the puzzle's playtest settings.
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
