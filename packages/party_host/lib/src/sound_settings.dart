import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'look_providers.dart';

/// This device's sound settings (M13 design section 8, L5): how loud its sounds
/// play, and whether the lobby music plays.
///
/// Like the look's settings they are this device's own: a joined phone's volume
/// and music are its own, and a host's are the host's.
final class SoundSettings {
  const SoundSettings({this.volume = defaultVolume, this.music = true});

  /// The volume of a device nothing has turned down: 80%, loud across a room
  /// and quiet enough to talk over.
  static const defaultVolume = 80;

  /// The loudest the volume goes: the setting is a percentage.
  static const maxVolume = 100;

  /// How far one step of the Sound volume slider moves it.
  static const stepPercent = 10;

  /// The master volume, 0 (silence) to [maxVolume].
  final int volume;

  /// Whether the lobby music plays on this device.
  final bool music;

  /// The same settings with the given ones changed; [volume] is clamped to
  /// 0..[maxVolume].
  SoundSettings copyWith({int? volume, bool? music}) =>
      SoundSettings(volume: (volume ?? this.volume).clamp(0, maxVolume).toInt(), music: music ?? this.music);

  @override
  bool operator ==(Object other) => other is SoundSettings && other.volume == volume && other.music == music;

  @override
  int get hashCode => Object.hash(volume, music);
}

/// This device's sound settings, kept on it (M13 design section 8).
final soundSettingsProvider = NotifierProvider<SoundSettingsNotifier, SoundSettings>(SoundSettingsNotifier.new);

/// Loads the sound settings from this device's prefs, and saves each change,
/// as the look's are (lookPrefsProvider): a host phone keeps them with its own
/// settings, and a joined phone with the rest of its app's.
class SoundSettingsNotifier extends Notifier<SoundSettings> {
  /// The prefs keys, beside the look's.
  static const volumeKey = 'sound.volume';
  static const musicKey = 'sound.music';

  @override
  SoundSettings build() {
    // A device that never changed them reads the defaults, and a saved value
    // out of range is clamped like a change is.
    final prefs = ref.watch(lookPrefsProvider);
    return const SoundSettings().copyWith(volume: prefs.getInt(volumeKey), music: prefs.getBool(musicKey));
  }

  /// The Sound volume setting: 0 to 100, clamped.
  void setVolume(int percent) {
    state = state.copyWith(volume: percent);
    unawaited(ref.read(lookPrefsProvider).setInt(volumeKey, state.volume));
  }

  /// The Music setting.
  void setMusic(bool music) {
    state = state.copyWith(music: music);
    unawaited(ref.read(lookPrefsProvider).setBool(musicKey, music));
  }
}
