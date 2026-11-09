import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'look_providers.dart';

/// This device's sound settings (M13 design section 8, L5; owner, Nov 9,
/// 2026): a volume for the game's sounds, a volume for the music (the lobby's
/// and the round's alike), and Mute, which silences both ("a mute switch should
/// mute volume and sound").
///
/// Like the look's settings they are this device's own: a joined phone's are
/// its own, and a host's are the host's.
final class SoundSettings {
  const SoundSettings({
    this.soundVolume = defaultSoundVolume,
    this.musicVolume = defaultMusicVolume,
    this.muted = false,
  });

  /// The sounds of a device nothing has turned down: 80%, loud across a room
  /// and quiet enough to talk over.
  static const defaultSoundVolume = 80;

  /// The music of a device nothing has turned down: 60%, under the sounds, so
  /// a lobby can talk over it.
  static const defaultMusicVolume = 60;

  /// The loudest a volume goes: the settings are percentages.
  static const maxVolume = 100;

  /// How far one step of a volume slider moves it.
  static const stepPercent = 10;

  /// The game's sounds, 0 (silence) to [maxVolume].
  final int soundVolume;

  /// The music, 0 (none) to [maxVolume]. At 0 the music doesn't play.
  final int musicVolume;

  /// Whether this device is silent: the sounds and the music alike. Both
  /// volumes are kept, so unmuting brings them back.
  final bool muted;

  /// The volume the player plays the sounds at, 0 to 1: silence while [muted].
  double get soundLevel => muted ? 0 : soundVolume / maxVolume;

  /// The volume the player plays the music at, 0 to 1: silence while [muted].
  double get musicLevel => muted ? 0 : musicVolume / maxVolume;

  /// The same settings with the given ones changed; the volumes are clamped to
  /// 0..[maxVolume].
  SoundSettings copyWith({int? soundVolume, int? musicVolume, bool? muted}) => SoundSettings(
    soundVolume: (soundVolume ?? this.soundVolume).clamp(0, maxVolume).toInt(),
    musicVolume: (musicVolume ?? this.musicVolume).clamp(0, maxVolume).toInt(),
    muted: muted ?? this.muted,
  );

  @override
  bool operator ==(Object other) =>
      other is SoundSettings &&
      other.soundVolume == soundVolume &&
      other.musicVolume == musicVolume &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(soundVolume, musicVolume, muted);
}

/// This device's sound settings, kept on it (M13 design section 8).
final soundSettingsProvider = NotifierProvider<SoundSettingsNotifier, SoundSettings>(SoundSettingsNotifier.new);

/// Loads the sound settings from this device's prefs, and saves each change,
/// as the look's are (lookPrefsProvider): a host phone keeps them with its own
/// settings, and a joined phone with the rest of its app's.
class SoundSettingsNotifier extends Notifier<SoundSettings> {
  /// The prefs keys, beside the look's.
  static const soundVolumeKey = 'sound.volume';
  static const musicVolumeKey = 'sound.musicVolume';
  static const mutedKey = 'sound.muted';

  @override
  SoundSettings build() {
    // A device that never changed them reads the defaults, and a saved value
    // out of range is clamped like a change is.
    final prefs = ref.watch(lookPrefsProvider);
    return const SoundSettings().copyWith(
      soundVolume: prefs.getInt(soundVolumeKey),
      musicVolume: prefs.getInt(musicVolumeKey),
      muted: prefs.getBool(mutedKey),
    );
  }

  /// The Sounds setting: 0 to 100, clamped.
  void setSoundVolume(int percent) {
    state = state.copyWith(soundVolume: percent);
    unawaited(ref.read(lookPrefsProvider).setInt(soundVolumeKey, state.soundVolume));
  }

  /// The Music setting: 0 to 100, clamped; 0 is no music.
  void setMusicVolume(int percent) {
    state = state.copyWith(musicVolume: percent);
    unawaited(ref.read(lookPrefsProvider).setInt(musicVolumeKey, state.musicVolume));
  }

  /// The Mute setting: silences the sounds and the music on this device.
  void setMuted(bool muted) {
    state = state.copyWith(muted: muted);
    unawaited(ref.read(lookPrefsProvider).setBool(mutedKey, muted));
  }
}
