import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show consentProvider;

import '../gyro.dart';
import '../phone_metrics.dart';
import 'connection.dart';
import 'consent.dart';
import 'device.dart';
import 'feedback.dart';
import 'haptics.dart';

/// The touch metrics (M9). Records while this phone is connected to a TV
/// (or reconnecting to one), not in the demo, and not while the adult has not
/// said yes to usage stats. A new segment starts on every mode or settings
/// change.
final phoneMetricsProvider = Provider<PhoneMetrics>((ref) {
  final client = ref.watch(clientProvider);
  final metrics = PhoneMetrics(send: client.sendMetrics);
  ref.onDispose(metrics.dispose);
  _tellStatsShare(ref, client, metrics);

  ref.listen(gyroProvider.select((g) => g.mode), (_, _) => _updateMetrics(ref, metrics));
  ref.listen(stickSettingsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(gyroSettingsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(hapticSettingsProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(pressFeedbackProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(demoProvider, (_, _) => _updateMetrics(ref, metrics));
  ref.listen(clientStateProvider, (prev, next) {
    if ((prev?.isConnected ?? false) && !next.isConnected) metrics.disconnected();
    _updateMetrics(ref, metrics);
  });
  final haptics = client.hapticEvents.listen((e) => metrics.haptic(e.event.name));
  ref.onDispose(haptics.cancel);
  _updateMetrics(ref, metrics);
  return metrics;
});

/// Tells the host whether this phone's player shares their stats (design
/// sentry-consent.md, stats option B): at start and on every change, the
/// answer itself being what notifies at once. A host that hears nothing counts
/// the player as not sharing, and the client keeps the answer to state again
/// after each pairing.
///
/// The same answer starts and stops this phone's recording at once (the run's
/// review: it did not reach the recorder): turning stats off in Settings ends
/// the segment that is recording, and a yes starts the next one, without
/// waiting for another setting or the connection.
void _tellStatsShare(Ref ref, ControllerClient client, PhoneMetrics metrics) {
  client.setStatsShare(ref.read(shareStatsProvider));
  ref.listen(consentProvider.select((consent) => consent.stats == true), (_, share) {
    client.setStatsShare(share);
    _updateMetrics(ref, metrics);
  });
}

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
