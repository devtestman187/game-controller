import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../haptics.dart';
import '../providers.dart';

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
