import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device_status.dart';
import '../layout.dart';
import '../storage.dart';
import 'connection.dart';
import 'profile.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Overridden in tests to check the iOS-only behavior on Windows.
final isIOSProvider = Provider<bool>((ref) => Platform.isIOS);

/// True on tablets: the screen's shorter side is at least 600 (the whole
/// display, not the window, which can be resized). Overridden in tests.
final isTabletProvider = Provider<bool>((ref) => _isTablet());

bool _isTablet() {
  final display = WidgetsBinding.instance.platformDispatcher.displays.firstOrNull;
  if (display == null || display.devicePixelRatio <= 0) return false;
  return isTabletScreen(display.size / display.devicePixelRatio);
}

/// Logical pixels per millimetre, for sizing controls physically (v2 C31).
final pxPerMmProvider = Provider<double>(
  (ref) => pxPerMmFor(isIOS: ref.watch(isIOSProvider), isTablet: ref.watch(isTabletProvider)),
);

final storeProvider = Provider<ConnectionStore>((ref) => ConnectionStore(ref.watch(prefsProvider)));

/// This phone's identity, with the player's saved nickname and character (M14
/// N13, section 9). A new profile rebuilds it, so a client made from now on (a
/// host's own player, say) carries it; a client already made is updated in
/// place by [ProfileNotifier].
final identityProvider = Provider<ControllerIdentity>((ref) {
  final display = WidgetsBinding.instance.platformDispatcher.displays.firstOrNull;
  final mm = ref.watch(pxPerMmProvider);
  final screen = display == null || display.devicePixelRatio <= 0 ? null : display.size / display.devicePixelRatio / mm;
  return loadIdentity(
    ref.watch(prefsProvider),
    isTablet: ref.watch(isTabletProvider),
    screenMm: screen,
    profile: ref.watch(profileProvider),
  );
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
