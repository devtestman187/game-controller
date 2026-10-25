import 'package:flutter/services.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptic_patterns.dart';

/// What the phone's vibration hardware can do.
final class HapticsCapabilities {
  const HapticsCapabilities({
    required this.supported,
    required this.intensityControl,
    required this.engine,
    this.detail,
  });

  /// For platforms without the native channel (tests, desktop).
  static const none = HapticsCapabilities(supported: false, intensityControl: false, engine: 'none');

  factory HapticsCapabilities.fromMap(Map<Object?, Object?> map) => HapticsCapabilities(
    supported: map['supported'] == true,
    intensityControl: map['intensityControl'] == true,
    engine: map['engine'] as String? ?? 'unknown',
    detail: map['detail'] as String?,
  );

  final bool supported;

  /// False when the hardware can only buzz on or off, so the intensity
  /// slider has no effect.
  final bool intensityControl;

  /// What plays the ticks, e.g. "Core Haptics" or "VibrationEffect composition".
  final String engine;

  /// The last native error, if any.
  final String? detail;
}

/// Plays haptics. The real one talks to native code (Core Haptics on iOS,
/// VibrationEffect on Android). Tests use [FakeHaptics].
abstract class Haptics {
  Future<HapticsCapabilities> capabilities();

  /// A short tick at [intensity] from 0 to 1.
  Future<void> tick(double intensity);

  /// A haptic event from the TV (M5). [event] lets the native side pick a
  /// fallback when it can't play patterns.
  Future<void> play(HapticEvent event, HapticPattern pattern);
}

/// The native implementation, behind one small platform channel:
/// `ios/Runner/AppDelegate.swift` and `android/.../Haptics.kt`.
class PlatformHaptics implements Haptics {
  static const _channel = MethodChannel('com.gamecontrollerdev.controller/haptics');

  @override
  Future<HapticsCapabilities> capabilities() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('capabilities');
      return map == null ? HapticsCapabilities.none : HapticsCapabilities.fromMap(map);
    } on MissingPluginException {
      return HapticsCapabilities.none;
    }
  }

  @override
  Future<void> tick(double intensity) => _channel.invokeMethod<void>('tick', {'intensity': intensity});

  @override
  Future<void> play(HapticEvent event, HapticPattern pattern) =>
      _channel.invokeMethod<void>('play', {'event': event.name, 'segments': pattern.toWire()});
}

/// Records ticks instead of playing them.
class FakeHaptics implements Haptics {
  FakeHaptics({this.caps = const HapticsCapabilities(supported: true, intensityControl: true, engine: 'fake')});

  HapticsCapabilities caps;
  final ticks = <double>[];
  final played = <(HapticEvent, HapticPattern)>[];

  /// When set, every tick throws this, to test that errors don't break input.
  Object? failWith;

  @override
  Future<HapticsCapabilities> capabilities() async => caps;

  @override
  Future<void> tick(double intensity) async {
    final error = failWith;
    if (error != null) throw error;
    ticks.add(intensity);
  }

  @override
  Future<void> play(HapticEvent event, HapticPattern pattern) async {
    final error = failWith;
    if (error != null) throw error;
    played.add((event, pattern));
  }
}

/// The user's haptic choices.
final class HapticSettings {
  const HapticSettings({this.enabled = true, this.intensity = 0.7});

  final bool enabled;

  /// 0.1 to 1.
  final double intensity;

  HapticSettings copyWith({bool? enabled, double? intensity}) =>
      HapticSettings(enabled: enabled ?? this.enabled, intensity: intensity ?? this.intensity);

  static HapticSettings load(SharedPreferences prefs) => HapticSettings(
    enabled: prefs.getBool(_enabledKey) ?? true,
    intensity: (prefs.getDouble(_intensityKey) ?? 0.7).clamp(0.1, 1.0),
  );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setDouble(_intensityKey, intensity);
  }
}

const _enabledKey = 'hapticsEnabled';
const _intensityKey = 'hapticsIntensity';

/// Applies the settings and the hardware's limits, and never lets a haptics
/// error reach the input code.
class HapticsPlayer {
  HapticsPlayer(this._haptics, {void Function(String)? log}) : _log = log ?? ((_) {});

  final Haptics _haptics;
  final void Function(String) _log;
  HapticSettings settings = const HapticSettings();
  HapticsCapabilities capabilities = HapticsCapabilities.none;

  /// The last error from the native side, for Diagnostics.
  String? lastError;
  int played = 0;

  /// Haptic events from the TV played since launch, and the latest one.
  int eventsPlayed = 0;
  HapticEventMessage? lastEvent;

  /// True while the app isn't in the foreground: TV events are skipped, since
  /// the phone can't (iOS) or shouldn't (Android) vibrate from the background.
  bool paused = false;

  Future<void> load() async {
    capabilities = await _haptics.capabilities();
    _log(
      'Haptics: ${capabilities.supported ? 'supported' : 'not supported'} (${capabilities.engine}'
      '${capabilities.intensityControl ? ', intensity control' : ''})',
    );
  }

  /// Plays a tick scaled by [strength] (presses 1, lighter for releases).
  Future<void> tick({double strength = 1}) async {
    if (!settings.enabled || !capabilities.supported) return;
    final intensity = (settings.intensity * strength).clamp(0.05, 1.0);
    try {
      await _haptics.tick(intensity);
      played++;
    } catch (e) {
      _failed(e);
    }
  }

  /// Plays a haptic event sent by the TV (PRD C6). The haptics switch
  /// silences it too, and the intensity setting scales it like the ticks.
  /// Returns whether it was played.
  Future<bool> event(HapticEventMessage message) async {
    lastEvent = message;
    if (!settings.enabled || !capabilities.supported || paused) return false;
    final pattern = HapticPattern.forEvent(
      message.event,
      intensity: message.intensity * settings.intensity,
      durationMs: message.durationMs,
    );
    try {
      await _haptics.play(message.event, pattern);
      eventsPlayed++;
      return true;
    } catch (e) {
      _failed(e);
      return false;
    }
  }

  void _failed(Object e) {
    if (lastError == null) _log('Haptics error (further ones not logged): $e');
    lastError = '$e';
  }
}
