import 'package:game_assets/asset_manifest.dart';

/// What the sound player has loaded, for the screen and the log.
final class SoundStatus {
  const SoundStatus({required this.engine, this.ready = false, this.files = const {}, this.error});

  /// The audio engine's name, e.g. `flutter_soloud`.
  final String engine;

  /// Whether the engine started and every sound was loaded.
  final bool ready;

  /// Per sound: e.g. "hit.ogg, 1.55 s", "no file (silent)" or the load error.
  final Map<SoundKey, String> files;

  /// Set if the audio engine itself couldn't start (everything is silent).
  final String? error;

  /// How many sounds play for real, for the "N of M loaded" line.
  int get loaded => throw UnimplementedError();
}

/// Plays the host's sounds by event name (PRD v2 S5: games ask the game host,
/// which hands the name to this). Game code never touches the audio package,
/// so it can be swapped, and a fake replaces it in tests.
abstract class SoundPlayer {
  /// What is loaded right now.
  SoundStatus get status;

  /// Fires on every change to [status].
  Stream<SoundStatus> get changes;

  /// Starts the audio engine and loads every sound. Never throws: anything
  /// that fails is silent and reported in [status].
  Future<void> load();

  /// Plays the sound for [name] (e.g. `hit`, `snap`, `time_up`). If the same
  /// sound is still playing it starts over instead of layering, so repeated
  /// events stay clear. An unknown name plays nothing.
  void play(String name);

  /// Stops the engine and releases the sounds.
  Future<void> dispose();
}
