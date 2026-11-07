import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controls_settings.dart';
import 'device.dart';

final controlsSettingsProvider = NotifierProvider<ControlsSettingsNotifier, ControlsSettings>(
  ControlsSettingsNotifier.new,
);

/// How opaque the controls are over a game (PRD v2 C28), saved between
/// launches.
class ControlsSettingsNotifier extends Notifier<ControlsSettings> {
  @override
  ControlsSettings build() => ControlsSettings.load(ref.watch(prefsProvider));

  void update(ControlsSettings settings) {
    state = settings;
    unawaited(settings.save(ref.read(prefsProvider)));
  }
}
