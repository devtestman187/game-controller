/// What a sound player has been asked for, kept apart from the engine (M13
/// design section 8): a wish made before the sounds are loaded, or before an
/// engine restart after the app was in the background, is carried out once the
/// engine is up.
///
/// Pure, so it can be tested without an audio device: no engine, no clock, no
/// Flutter. One loop at a time: the same name again is no change, so the music
/// never restarts.
final class SoundWish {
  const SoundWish({this.loop, this.volume = fullVolume, this.musicVolume = fullVolume});

  /// The volume of a player nothing has turned down: every sound at the
  /// loudness its file has.
  static const fullVolume = 1.0;

  /// The name of the loop that should be sounding, or null for none.
  final String? loop;

  /// The volume the game's sounds play at, 0 (silence) to [fullVolume].
  final double volume;

  /// The volume the loop (the lobby music) plays at, 0 to [fullVolume]: its
  /// own, so the music and the sounds are set apart (owner, Nov 9, 2026).
  final double musicVolume;

  /// The same wish with [name] looping, or with no loop for null.
  SoundWish withLoop(String? name) => SoundWish(loop: name, volume: volume, musicVolume: musicVolume);

  /// The same wish at [value], clamped to 0..[fullVolume].
  SoundWish withVolume(double value) => SoundWish(loop: loop, volume: _clamp(value), musicVolume: musicVolume);

  /// The same wish with the music at [value], clamped to 0..[fullVolume].
  SoundWish withMusicVolume(double value) => SoundWish(loop: loop, volume: volume, musicVolume: _clamp(value));

  static double _clamp(double value) => value.clamp(0.0, fullVolume).toDouble();

  /// Whether the loop [sounding] must stop before this wish is carried out: it
  /// must when a loop sounds and it isn't the one wanted.
  bool stopsFrom(String? sounding) => sounding != null && sounding != loop;

  /// The loop to start when [sounding] is the loop playing now, or null when
  /// none must start: the wish asks for none, or for the one already playing.
  String? startsFrom(String? sounding) => loop == sounding ? null : loop;

  @override
  bool operator ==(Object other) =>
      other is SoundWish && other.loop == loop && other.volume == volume && other.musicVolume == musicVolume;

  @override
  int get hashCode => Object.hash(loop, volume, musicVolume);
}
