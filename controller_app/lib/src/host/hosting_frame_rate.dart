import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';

import '../providers.dart';

/// The rates "Frame rate (test)" offers (m12 §0.5): 60, 30 and 20 frames a
/// second. All three are inside [HostingSettings]'s own range.
const hostingFrameRates = [60, 30, 20];

/// The rate a hosted game runs at until the player picks another (m12 §0.5):
/// the usual 60, as a TV runs.
const defaultHostingFrameRateHz = HostingSettings.defaultFrameRateHz;

/// The rate this phone hosts games at (m12 §0.5), saved under
/// `hostingFrameRateHz`. A round reads it when it starts, so a change applies
/// from the next round.
final hostingFrameRateProvider = NotifierProvider<HostingFrameRateNotifier, int>(HostingFrameRateNotifier.new);

/// Reads and saves this phone's test frame rate.
class HostingFrameRateNotifier extends Notifier<int> {
  static const _key = 'hostingFrameRateHz';

  @override
  int build() {
    final hz = ref.watch(prefsProvider).getInt(_key);
    return hz == null || !hostingFrameRates.contains(hz) ? defaultHostingFrameRateHz : hz;
  }

  /// Saves [hz] for the rounds after this one.
  void set(int hz) {
    if (!hostingFrameRates.contains(hz)) {
      throw ArgumentError.value(hz, 'hz', 'hostingFrameRates is $hostingFrameRates');
    }
    state = hz;
    unawaited(ref.read(prefsProvider).setInt(_key, hz));
  }
}

/// The host's settings at the saved test rate (m12 §0.5), the value
/// `hostingSettingsProvider` takes on this phone.
HostingSettings hostingSettingsAt(int hz) => HostingSettings(frameRateHz: hz);
