import 'package:flutter_soloud/flutter_soloud.dart';

/// The engine calls [SoundLoop] makes, named as flutter_soloud names them, so
/// a test can stand in for the audio engine and watch them (M14 B-004).
abstract interface class LoopAudioEngine {
  /// Starts [source] and returns the voice it sounds in.
  SoundHandle play(AudioSource source, {required bool looping, required double volume});

  /// Marks [handle] as one the engine must not steal while a busier voice
  /// wants its slot (M14 B-004).
  void setProtectVoice(SoundHandle handle, bool protect);

  /// Whether [handle] is still a voice the engine knows.
  bool getIsValidVoiceHandle(SoundHandle handle);

  /// Moves [handle] to [position].
  void seek(SoundHandle handle, Duration position);

  /// How long [source] sounds.
  Duration getLength(AudioSource source);

  /// How far [handle] has played.
  Duration getPosition(SoundHandle handle);

  /// Moves [handle] to [to] of its volume over [time].
  void fadeVolume(SoundHandle handle, double to, Duration time);

  /// Stops [handle] at once.
  Future<void> stop(SoundHandle handle);

  /// Holds [handle] where it is, or lets it carry on.
  void setPause(SoundHandle handle, bool pause);

  /// Sets how loud [handle] sounds now.
  void setVolume(SoundHandle handle, double volume);
}

/// [LoopAudioEngine] on the one engine the app runs (flutter_soloud).
class SoLoudLoopEngine implements LoopAudioEngine {
  const SoLoudLoopEngine();

  // Read at each call, not kept: the engine starts, restarts and stops while
  // the loop lives (M14 g3).
  SoLoud get _soloud => SoLoud.instance;

  @override
  SoundHandle play(AudioSource source, {required bool looping, required double volume}) =>
      _soloud.play(source, looping: looping, volume: volume);

  @override
  void setProtectVoice(SoundHandle handle, bool protect) => _soloud.setProtectVoice(handle, protect);

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) => _soloud.getIsValidVoiceHandle(handle);

  @override
  void seek(SoundHandle handle, Duration position) => _soloud.seek(handle, position);

  @override
  Duration getLength(AudioSource source) => _soloud.getLength(source);

  @override
  Duration getPosition(SoundHandle handle) => _soloud.getPosition(handle);

  @override
  void fadeVolume(SoundHandle handle, double to, Duration time) => _soloud.fadeVolume(handle, to, time);

  @override
  Future<void> stop(SoundHandle handle) => _soloud.stop(handle);

  @override
  void setPause(SoundHandle handle, bool pause) => _soloud.setPause(handle, pause);

  @override
  void setVolume(SoundHandle handle, double volume) => _soloud.setVolume(handle, volume);
}
