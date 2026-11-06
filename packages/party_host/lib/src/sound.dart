import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
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
  int get loaded => files.values.where((f) => f.contains(' s')).length;
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

/// Plays through flutter_soloud (SoLoud + miniaudio), which bundles its own
/// OGG and WAV decoders, so Android TV and Windows play the same files with
/// no codecs installed.
class SoLoudSoundPlayer implements SoundPlayer {
  /// [log] gets short lines about the engine and each sound.
  SoLoudSoundPlayer({LogSink? log}) : _log = log ?? ((_) {});

  final LogSink _log;
  final _changes = StreamController<SoundStatus>.broadcast();
  final _sources = <SoundKey, AudioSource>{};
  final _playing = <SoundKey, SoundHandle>{};
  SoundStatus _status = const SoundStatus(engine: 'flutter_soloud');
  Future<void>? _loading;

  @override
  SoundStatus get status => _status;

  @override
  Stream<SoundStatus> get changes => _changes.stream;

  @override
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final soloud = SoLoud.instance;
    try {
      await soloud.init();
    } catch (e) {
      _log('Sound engine could not start, sounds are off: $e');
      _set(SoundStatus(engine: 'flutter_soloud', error: '$e'));
      return;
    }
    final files = <SoundKey, String>{};
    for (final key in SoundKey.values) {
      try {
        final path = await findSound(key);
        if (path == null) {
          files[key] = 'no file (silent)';
          continue;
        }
        final source = await soloud.loadAsset(path);
        _sources[key] = source;
        final seconds = soloud.getLength(source).inMilliseconds / 1000;
        files[key] = '${path.split('/').last}, ${seconds.toStringAsFixed(2)} s';
      } catch (e) {
        files[key] = 'failed: $e';
      }
    }
    _log('Sounds: ${SoundKey.values.map((k) => '${k.eventName} ${files[k]}').join('; ')}');
    _set(SoundStatus(engine: 'flutter_soloud', ready: true, files: files));
  }

  @override
  void play(String name) {
    final key = SoundKey.byEventName(name);
    final source = key == null ? null : _sources[key];
    if (key == null || source == null) return;
    final soloud = SoLoud.instance;
    try {
      final previous = _playing[key];
      if (previous != null && soloud.getIsValidVoiceHandle(previous)) unawaited(soloud.stop(previous));
      _playing[key] = soloud.play(source);
    } catch (e) {
      _log('Could not play the $name sound: $e');
    }
  }

  /// How far the latest [key] sound has played, or null if it isn't playing.
  /// For the on-device sound test.
  Duration? positionOf(SoundKey key) {
    final handle = _playing[key];
    if (handle == null || !SoLoud.instance.getIsValidVoiceHandle(handle)) return null;
    return SoLoud.instance.getPosition(handle);
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
    try {
      await _loading;
      if (SoLoud.instance.isInitialized) SoLoud.instance.deinit();
    } catch (e) {
      _log('Could not shut the sound engine down: $e');
    }
  }

  void _set(SoundStatus s) {
    _status = s;
    if (!_changes.isClosed) _changes.add(s);
  }
}
