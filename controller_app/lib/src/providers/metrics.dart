import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gyro.dart';
import '../phone_metrics.dart';
import 'connection.dart';
import 'device.dart';
import 'feedback.dart';
import 'haptics.dart';

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

  ref.listen(gyroProvider.select((g) => g.mode), (_, _) => _updateMetrics(ref, metrics));
  ref.listen(stickSettingsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(gyroSettingsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(hapticSettingsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(pressFeedbackProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(demoProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(shareStatsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(clientStateProvider, (prev, next) {
    if ((prev?.isConnected ?? false) && !next.isConnected) metrics.disconnected();
    _updateMetrics(ref, metrics);
  });
  final haptics = client.hapticEvents.listen((e) => metrics.haptic(e.event.name));
  ref.onDispose(haptics.cancel);
  _updateMetrics(ref, metrics);
  return metrics;
});

/// The mode, the settings and whether recording is on, as things stand now.
void _updateMetrics(Ref ref, PhoneMetrics metrics) {
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
