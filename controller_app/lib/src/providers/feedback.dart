import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback.dart';
import 'device.dart';
import 'haptics.dart';

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
