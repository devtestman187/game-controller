import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_status.dart';
import 'discovery.dart';
import 'haptics.dart';
import 'local_network.dart';
import 'pad.dart';
import 'sticks.dart';
import 'storage.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Overridden in tests to check the iOS-only behavior on Windows.
final isIOSProvider = Provider<bool>((ref) => Platform.isIOS);

final logProvider = Provider<LogBuffer>((ref) {
  final log = LogBuffer();
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
});

final storeProvider = Provider<ConnectionStore>((ref) => ConnectionStore(ref.watch(prefsProvider)));

final identityProvider = Provider<ControllerIdentity>((ref) => loadIdentity(ref.watch(prefsProvider)));

final discoveryProvider = Provider<HostDiscovery>((ref) {
  final discovery = BonsoirHostDiscovery(log: ref.watch(logProvider).sink('discovery'));
  unawaited(discovery.start());
  ref.onDispose(discovery.dispose);
  return discovery;
});

final discoveryStateProvider = NotifierProvider<DiscoveryStateNotifier, DiscoveryState>(DiscoveryStateNotifier.new);

class DiscoveryStateNotifier extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() {
    final discovery = ref.watch(discoveryProvider);
    final sub = discovery.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return discovery.state;
  }
}

final clientProvider = Provider<ControllerClient>((ref) {
  final store = ref.watch(storeProvider);
  final identity = ref.watch(identityProvider);
  final log = ref.watch(logProvider);
  log.add(
    'app',
    'Controller ${identity.appVersion} on ${identity.platform}, ID ${identity.controllerId.substring(0, 6)}',
  );
  final client = ControllerClient(
    identity: identity,
    tokens: store.tokens,
    onTokenChanged: store.setToken,
    log: log.sink('client'),
  );
  // Remember the TV once paired (with its ID, even if it was typed in), so
  // the app reconnects to it on the next launch.
  final sub = client.changes.listen((s) {
    if (s.isConnected) store.lastHost = s.target;
  });
  ref.onDispose(() async {
    await sub.cancel();
    await client.dispose();
  });
  return client;
});

final clientStateProvider = NotifierProvider<ClientStateNotifier, ClientSnapshot>(ClientStateNotifier.new);

class ClientStateNotifier extends Notifier<ClientSnapshot> {
  @override
  ClientSnapshot build() {
    final client = ref.watch(clientProvider);
    final sub = client.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return client.snapshot;
  }
}

/// True once the phone has been connected to a TV since launch.
final everConnectedProvider = NotifierProvider<EverConnectedNotifier, bool>(EverConnectedNotifier.new);

class EverConnectedNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(clientStateProvider, (_, next) {
      if (next.isConnected) state = true;
    });
    return ref.read(clientStateProvider).isConnected;
  }
}

final localNetworkStatusProvider = Provider<LocalNetworkStatus>(
  (ref) => localNetworkStatus(
    isIOS: ref.watch(isIOSProvider),
    discovery: ref.watch(discoveryStateProvider),
    client: ref.watch(clientStateProvider),
    everConnected: ref.watch(everConnectedProvider),
  ),
);

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

/// What the screens do. Keeps "remember the last TV" next to connecting.
final connectionActionsProvider = Provider<ConnectionActions>(
  (ref) => ConnectionActions(ref.watch(clientProvider), ref.watch(storeProvider)),
);

class ConnectionActions {
  ConnectionActions(this._client, this._store);

  final ControllerClient _client;
  final ConnectionStore _store;

  void connect(HostAddress host, {String? code}) => _client.connect(host, code: code);

  void submitCode(String code) => _client.submitCode(code);

  /// Disconnects and forgets the last TV, so the next launch doesn't
  /// reconnect on its own.
  void disconnect() {
    _store.lastHost = null;
    _client.disconnect();
  }

  /// On launch: reconnect to the last TV if this phone is still paired with
  /// it. Returns false if there is nothing to reconnect to.
  bool reconnectToLastHost() {
    final last = _store.lastHost;
    final id = last?.hostId;
    if (last == null || id == null || !_client.tokens.containsKey(id)) return false;
    _client.connect(last);
    return true;
  }
}

/// Overridden in tests with a FakeHaptics.
final hapticsProvider = Provider<Haptics>((ref) => PlatformHaptics());

final hapticsPlayerProvider = Provider<HapticsPlayer>((ref) {
  final player = HapticsPlayer(ref.watch(hapticsProvider), log: ref.watch(logProvider).sink('haptics'));
  player.settings = HapticSettings.load(ref.watch(prefsProvider));
  return player;
});

/// What the hardware can do, checked once at startup.
final hapticsCapabilitiesProvider = FutureProvider<HapticsCapabilities>((ref) async {
  final player = ref.watch(hapticsPlayerProvider);
  await player.load();
  return player.capabilities;
});

final hapticSettingsProvider = NotifierProvider<HapticSettingsNotifier, HapticSettings>(HapticSettingsNotifier.new);

/// The haptics on/off switch and intensity, saved between launches.
class HapticSettingsNotifier extends Notifier<HapticSettings> {
  @override
  HapticSettings build() => ref.watch(hapticsPlayerProvider).settings;

  void update(HapticSettings settings) {
    state = settings;
    ref.read(hapticsPlayerProvider).settings = settings;
    unawaited(settings.save(ref.read(prefsProvider)));
  }

  /// Plays one tick at the current settings, for the "Try" button.
  void test() => unawaited(ref.read(hapticsPlayerProvider).tick());

  /// Plays a TV event at its current strength, for its "Try" button.
  void tryEvent(HapticEvent event) => unawaited(ref.read(hapticsPlayerProvider).tryEvent(event));
}

/// Overridden in tests with a fake.
final deviceStatusSourceProvider = Provider<DeviceStatusSource>((ref) => PlatformDeviceStatus());

/// Battery, CPU and send rate since launch (PRD M6 long-session check). It
/// samples every 10 s from the moment the controller screen starts it.
final sessionMonitorProvider = Provider<SessionMonitor>((ref) {
  final client = ref.watch(clientProvider);
  final monitor = SessionMonitor(ref.watch(deviceStatusSourceProvider), inputsSent: () => client.inputsSent);
  ref.onDispose(monitor.dispose);
  return monitor;
});

final sessionStatsProvider = NotifierProvider<SessionStatsNotifier, SessionStats?>(SessionStatsNotifier.new);

class SessionStatsNotifier extends Notifier<SessionStats?> {
  @override
  SessionStats? build() {
    final monitor = ref.watch(sessionMonitorProvider);
    final sub = monitor.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return monitor.stats;
  }
}

/// One time the connection dropped and came back (or hasn't yet).
typedef Outage = ({DateTime from, Duration? length, String reason});

/// The latest connection drops, newest first, for Diagnostics: how long
/// each one took to recover (PRD M6 reconnect hardening).
final outagesProvider = NotifierProvider<OutagesNotifier, List<Outage>>(OutagesNotifier.new);

class OutagesNotifier extends Notifier<List<Outage>> {
  static const keep = 10;

  @override
  List<Outage> build() {
    ref.listen(clientStateProvider, (prev, next) {
      final wasUp = prev?.isConnected ?? false;
      if (wasUp && next.status == ClientStatus.reconnecting) {
        final reason = next.detail ?? next.problem?.name ?? 'connection lost';
        state = [(from: DateTime.now(), length: null, reason: reason), ...state].take(keep).toList();
      } else if (next.isConnected && state.isNotEmpty && state.first.length == null) {
        final o = state.first;
        state = [(from: o.from, length: DateTime.now().difference(o.from), reason: o.reason), ...state.skip(1)];
        ref
            .read(logProvider)
            .add('client', 'Back after ${(state.first.length!.inMilliseconds / 1000).toStringAsFixed(1)} s');
      }
    });
    return const [];
  }
}

/// Haptic events from the TV (M5): how many arrived and were played, and
/// the latest, for Diagnostics.
typedef TvHaptics = ({int received, int played, HapticEventMessage? last});

final tvHapticsProvider = NotifierProvider<TvHapticsNotifier, TvHaptics>(TvHapticsNotifier.new);

/// Plays every haptic event the TV sends, in any input mode. The controller
/// screen keeps it alive.
class TvHapticsNotifier extends Notifier<TvHaptics> {
  @override
  TvHaptics build() {
    // Make sure the capability check has run before the first event.
    ref.watch(hapticsCapabilitiesProvider);
    final client = ref.watch(clientProvider);
    final player = ref.watch(hapticsPlayerProvider);
    final sub = client.hapticEvents.listen((message) async {
      await player.event(message);
      if (ref.mounted) state = (received: client.hapticsReceived, played: player.eventsPlayed, last: message);
    });
    ref.onDispose(sub.cancel);
    return (received: client.hapticsReceived, played: player.eventsPlayed, last: player.lastEvent);
  }
}

final padProvider = NotifierProvider<PadNotifier, PadInput>(PadNotifier.new);

/// The pad's input: tracks fingers, sends every change to the TV and plays a
/// tick for every press, release and direction change.
class PadNotifier extends Notifier<PadInput> {
  final _tracker = PadTracker();

  @override
  PadInput build() {
    // Make sure the capability check has run before the first tick.
    ref.watch(hapticsCapabilitiesProvider);
    ref.onDispose(() => _cooldown?.cancel());
    return _tracker.current;
  }

  void dpad(int pointer, (int, int) direction) => _apply(_tracker.dpad(pointer, direction));

  void button(int pointer, ControllerButton? button) => _apply(_tracker.button(pointer, button));

  void up(int pointer) => _apply(_tracker.up(pointer));

  /// Called when the app leaves the foreground, so nothing stays held.
  void releaseAll() => _apply(_tracker.releaseAll());

  /// Gyro tilt from gyro mode (about 60 per second).
  void tilt(double ax, double ay) => _apply(_tracker.tilt(ax, ay));

  /// A stick moved, or was let go ([stickCenter]).
  void stick(StickSide side, Stick value) => _apply(_tracker.stick(side, value));

  /// A new mode starts: nothing from the old layout stays held.
  void switchMode({required bool tilt, required bool sticks}) =>
      _apply(_tracker.switchMode(tilt: tilt, sticks: sticks));

  /// At most one send per [analogInterval] for stick and tilt movement.
  static const analogInterval = Duration(milliseconds: 16);
  Timer? _cooldown;
  bool _pending = false;

  void _apply(PadChange change) {
    if (!change.changed) return;
    state = change.after;
    final strength = change.tickStrength;
    if (strength > 0) unawaited(ref.read(hapticsPlayerProvider).tick(strength: strength));

    // Buttons, the D-pad, mode changes and a stick returning to center go
    // out at once. Analog movement is capped at about 60 per second, always
    // sending the latest value.
    final before = change.before;
    final after = change.after;
    final onlyAnalogMoved =
        strength == 0 &&
        before.buttons.length == after.buttons.length &&
        (before.ax == null) == (after.ax == null) &&
        (before.left == null) == (after.left == null) &&
        !_recentered(before.left, after.left) &&
        !_recentered(before.right, after.right);
    if (!onlyAnalogMoved) {
      _send();
    } else if (_cooldown == null) {
      _send();
    } else {
      _pending = true;
    }
  }

  static bool _recentered(Stick? before, Stick? after) => after == stickCenter && before != stickCenter;

  void _send() {
    _pending = false;
    final a = state;
    ref.read(clientProvider).sendInput(a.buttons, dx: a.dx, dy: a.dy, ax: a.ax, ay: a.ay, left: a.left, right: a.right);
    _cooldown ??= Timer(analogInterval, () {
      _cooldown = null;
      if (_pending) _send();
    });
  }
}
