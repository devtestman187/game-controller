import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'device_status.dart';
import 'discovery.dart';
import 'feedback.dart';
import 'gyro.dart';
import 'haptics.dart';
import 'layout.dart';
import 'local_network.dart';
import 'pad.dart';
import 'phone_metrics.dart';
import 'sticks.dart';
import 'storage.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Overridden in tests to check the iOS-only behavior on Windows.
final isIOSProvider = Provider<bool>((ref) => Platform.isIOS);

/// True on tablets: the screen's shorter side is at least 600 (the whole
/// display, not the window, which can be resized). Overridden in tests.
final isTabletProvider = Provider<bool>((ref) {
  final display = WidgetsBinding.instance.platformDispatcher.displays.firstOrNull;
  if (display == null || display.devicePixelRatio <= 0) return false;
  return isTabletScreen(display.size / display.devicePixelRatio);
});

/// Logical pixels per millimetre, for sizing controls physically (v2 C31).
final pxPerMmProvider = Provider<double>(
  (ref) => pxPerMmFor(isIOS: ref.watch(isIOSProvider), isTablet: ref.watch(isTabletProvider)),
);

final pressFeedbackProvider = NotifierProvider<PressFeedbackNotifier, PressFeedbackSettings>(PressFeedbackNotifier.new);

/// Flash and click for devices without vibration (v2 C33), saved.
class PressFeedbackNotifier extends Notifier<PressFeedbackSettings> {
  @override
  PressFeedbackSettings build() => PressFeedbackSettings.load(ref.watch(prefsProvider));

  void update(PressFeedbackSettings settings) {
    state = settings;
    unawaited(settings.save(ref.read(prefsProvider)));
  }
}

/// Whether controls flash when pressed: the setting, or automatically when
/// the device has no haptics (unknown while the check runs: no flash).
final flashOnPressProvider = Provider<bool>((ref) {
  final caps = ref.watch(hapticsCapabilitiesProvider).value;
  return ref.watch(pressFeedbackProvider).flashes(hasHaptics: caps?.supported ?? true);
});

/// Plays the click (v2 C33). Overridden in tests to count clicks.
final clickSoundProvider = Provider<void Function()>(
  (ref) =>
      () => unawaited(SystemSound.play(SystemSoundType.click)),
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

final storeProvider = Provider<ConnectionStore>((ref) => ConnectionStore(ref.watch(prefsProvider)));

final identityProvider = Provider<ControllerIdentity>((ref) {
  final display = WidgetsBinding.instance.platformDispatcher.displays.firstOrNull;
  final mm = ref.watch(pxPerMmProvider);
  final screen = display == null || display.devicePixelRatio <= 0 ? null : display.size / display.devicePixelRatio / mm;
  return loadIdentity(ref.watch(prefsProvider), isTablet: ref.watch(isTabletProvider), screenMm: screen);
});

/// The device model and OS version from the native side (M9), or nulls
/// where it can't say (tests, older builds).
final deviceDetailsProvider = FutureProvider<({String? model, String? os})>((ref) async {
  try {
    final map = await const MethodChannel('com.thumbparty.app/haptics').invokeMapMethod<String, Object?>('deviceInfo');
    return (model: map?['model'] as String?, os: map?['os'] as String?);
  } on MissingPluginException {
    return (model: null, os: null);
  } on PlatformException {
    return (model: null, os: null);
  }
});

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
  log.add('app', 'Thumb Party $versionLabel on ${identity.platform}, ID ${identity.controllerId.substring(0, 6)}');
  final client = ControllerClient(
    identity: identity,
    tokens: store.tokens,
    onTokenChanged: store.setToken,
    log: log.sink('client'),
  );
  // The model, OS and haptics go into the next hello once known.
  unawaited(() async {
    final details = await ref.read(deviceDetailsProvider.future);
    if (!ref.mounted) return;
    bool? haptics;
    try {
      haptics = (await ref.read(hapticsCapabilitiesProvider.future)).supported;
    } catch (_) {}
    if (!ref.mounted) return;
    client.identity = withDeviceDetails(client.identity, model: details.model, os: details.os, haptics: haptics);
  }());
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

/// "Try without a TV" (v2 C23): the controls work with no host, and the
/// screen shows what a TV would receive. For app reviewers and new testers.
/// Ends by itself once a TV connects.
final demoProvider = NotifierProvider<DemoNotifier, bool>(DemoNotifier.new);

class DemoNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(clientStateProvider, (_, next) {
      if (next.isConnected) state = false;
    });
    return false;
  }

  void start() => state = true;

  void stop() => state = false;
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
    // Start the capability check before the first tick. Listening (not
    // watching) keeps it alive without rebuilding this notifier when it
    // finishes.
    ref.listen(hapticsCapabilitiesProvider, (_, _) {});
    // A cancelled cooldown must also be cleared: if it stayed set, every
    // later stick or tilt move would wait for a timer that never fires, and
    // only buttons would reach the TV (found on the Pixel Tablet in M8).
    ref.onDispose(() {
      _cooldown?.cancel();
      _cooldown = null;
      _pending = false;
    });
    return _tracker.current;
  }

  void dpad(int pointer, (int, int) direction) => _apply(_tracker.dpad(pointer, direction));

  void button(int pointer, ControllerButton? button) {
    // A finger that was on a button and is now on none slid off it (M9).
    final before = _tracker.buttonUnder(pointer);
    if (before != null && button == null) ref.read(phoneMetricsProvider).slideOff(before.name);
    _apply(_tracker.button(pointer, button));
  }

  void up(int pointer) => _apply(_tracker.up(pointer));

  /// Called when the app leaves the foreground, so nothing stays held.
  void releaseAll() {
    _leftTouched = false;
    _rightTouched = false;
    _apply(_tracker.releaseAll());
  }

  /// Gyro tilt from gyro mode (about 60 per second).
  void tilt(double ax, double ay) {
    ref.read(phoneMetricsProvider).tilt(ax, ay);
    _apply(_tracker.tilt(ax, ay));
  }

  /// A stick moved, or was let go ([stickCenter], [touched] false).
  void stick(StickSide side, Stick value, {bool touched = true}) {
    final left = side == StickSide.left;
    if (left) {
      _leftTouched = touched;
    } else {
      _rightTouched = touched;
    }
    ref.read(phoneMetricsProvider).stick(left ? 'ls' : 'rs', value.x, value.y, touched: touched);
    _apply(_tracker.stick(side, value), force: true);
  }

  bool _leftTouched = false;
  bool _rightTouched = false;

  /// A new mode starts: nothing from the old layout stays held.
  void switchMode({required bool tilt, required bool sticks}) {
    _leftTouched = false;
    _rightTouched = false;
    _apply(_tracker.switchMode(tilt: tilt, sticks: sticks));
  }

  /// At most one send per [analogInterval] for stick and tilt movement.
  static const analogInterval = Duration(milliseconds: 16);
  Timer? _cooldown;
  bool _pending = false;

  void _apply(PadChange change, {bool force = false}) {
    if (!change.changed) {
      if (force) _recordHeld(change.after);
      return;
    }
    state = change.after;
    _recordHeld(change.after);
    final strength = change.tickStrength;
    if (strength > 0) unawaited(ref.read(hapticsPlayerProvider).tick(strength: strength));
    // The optional click (v2 C33): presses and new directions, not releases.
    if (strength == 1 && ref.read(pressFeedbackProvider).click) ref.read(clickSoundProvider)();

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

  /// What is held, for the touch metrics (M9).
  void _recordHeld(PadInput input) => ref
      .read(phoneMetricsProvider)
      .held(
        heldControls(
          input.buttons,
          dpad: input.dx != 0 || input.dy != 0,
          left: _leftTouched && input.left != null,
          right: _rightTouched && input.right != null,
        ),
      );

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

/// "Share control stats with the TV" in Settings (PRD v2 privacy rules),
/// on by default and saved. Off: this phone sends no touch metrics.
final shareStatsProvider = NotifierProvider<ShareStatsNotifier, bool>(ShareStatsNotifier.new);

class ShareStatsNotifier extends Notifier<bool> {
  static const _key = 'shareStats';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? true;

  void set(bool on) {
    state = on;
    unawaited(ref.read(prefsProvider).setBool(_key, on));
  }
}

/// The touch metrics (M9). Records while this phone is connected to a TV
/// (or reconnecting to one), not in the demo, and not opted out. A new
/// segment starts on every mode or settings change.
final phoneMetricsProvider = Provider<PhoneMetrics>((ref) {
  final client = ref.watch(clientProvider);
  final metrics = PhoneMetrics(send: client.sendMetrics);
  ref.onDispose(metrics.dispose);

  void update() {
    final mode = ref.read(gyroProvider).mode;
    final haptics = ref.read(hapticSettingsProvider);
    final feedback = ref.read(pressFeedbackProvider);
    metrics.setMode(
      mode.name,
      metricsSettings(
        mode: mode,
        sticks: ref.read(stickSettingsProvider),
        gyro: ref.read(gyroSettingsProvider),
        hapticsOn: haptics.enabled,
        hapticIntensity: haptics.intensity,
        flash: ref.read(flashOnPressProvider),
        click: feedback.click,
        tablet: ref.read(isTabletProvider),
      ),
    );
    final client = ref.read(clientStateProvider);
    final inSession = client.isConnected || client.status == ClientStatus.reconnecting;
    metrics.setActive(inSession && !ref.read(demoProvider) && ref.read(shareStatsProvider));
  }

  ref.listen(gyroProvider.select((g) => g.mode), (_, _) => update());
  ref.listen(stickSettingsProvider, (_, _) => update());
  ref.listen(gyroSettingsProvider, (_, _) => update());
  ref.listen(hapticSettingsProvider, (_, _) => update());
  ref.listen(pressFeedbackProvider, (_, _) => update());
  ref.listen(demoProvider, (_, _) => update());
  ref.listen(shareStatsProvider, (_, _) => update());
  ref.listen(clientStateProvider, (prev, next) {
    if ((prev?.isConnected ?? false) && !next.isConnected) metrics.disconnected();
    update();
  });
  final haptics = client.hapticEvents.listen((e) => metrics.haptic(e.event.name));
  ref.onDispose(haptics.cancel);
  update();
  return metrics;
});

/// The TV's latest "How did the controls feel?" prompt (M9), until it's
/// answered or skipped. The controller screen shows it.
final ratingPromptProvider = NotifierProvider<RatingPromptNotifier, RatingAskMessage?>(RatingPromptNotifier.new);

class RatingPromptNotifier extends Notifier<RatingAskMessage?> {
  @override
  RatingAskMessage? build() {
    final client = ref.watch(clientProvider);
    final sub = client.ratingAsks.listen((ask) => state = ask);
    ref.onDispose(sub.cancel);
    return null;
  }

  /// Sends the answer. A null [face] means skipped.
  void answer(RatingFace? face, {List<String> tags = const []}) {
    final ask = state;
    if (ask == null) return;
    state = null;
    ref.read(clientProvider).sendRating(RatingMessage(id: ask.id, face: face, tags: tags));
    ref.read(logProvider).add('rating', face == null ? 'Skipped the rating' : 'Rated ${face.name} ${tags.join(' ')}');
  }
}
