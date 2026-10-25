import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:protocol/protocol.dart';

/// What the sound player has loaded, for the screen and the log.
final class SoundStatus {
  const SoundStatus({required this.engine, this.ready = false, this.files = const {}, this.error});

  final String engine;
  final bool ready;

  /// Per event: e.g. "hit.ogg, 1.55 s", "no file (silent)" or the load error.
  final Map<HapticEvent, String> files;

  /// Set if the audio engine itself couldn't start (everything is silent).
  final String? error;

  int get loaded => files.values.where((f) => f.contains(' s')).length;
}

/// Plays the TV's sound for a haptic event (one sound per event, from the
/// asset manifest). Game code only calls [play], so the audio package can be
/// swapped without touching it.
abstract class SoundPlayer {
  SoundStatus get status;
  Stream<SoundStatus> get changes;

  /// Starts the audio engine and loads every sound. Never throws: anything
  /// that fails is silent and reported in [status].
  Future<void> load();

  /// Plays [event]'s sound. If the same sound is still playing it starts over
  /// instead of layering, so repeated events stay clear.
  void play(HapticEvent event);

  Future<void> dispose();
}

/// Plays through flutter_soloud (SoLoud + miniaudio), which bundles its own
/// OGG and WAV decoders, so Android TV and Windows play the same files with
/// no codecs installed.
class SoLoudSoundPlayer implements SoundPlayer {
  SoLoudSoundPlayer({LogSink? log}) : _log = log ?? ((_) {});

  final LogSink _log;
  final _changes = StreamController<SoundStatus>.broadcast();
  final _sources = <HapticEvent, AudioSource>{};
  final _playing = <HapticEvent, SoundHandle>{};
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
    final files = <HapticEvent, String>{};
    for (final event in HapticEvent.values) {
      final key = SoundKey.values.byName(event.name);
      try {
        final path = await findSound(key);
        if (path == null) {
          files[event] = 'no file (silent)';
          continue;
        }
        final source = await soloud.loadAsset(path);
        _sources[event] = source;
        final seconds = soloud.getLength(source).inMilliseconds / 1000;
        files[event] = '${path.split('/').last}, ${seconds.toStringAsFixed(2)} s';
      } catch (e) {
        files[event] = 'failed: $e';
      }
    }
    _log('Sounds: ${HapticEvent.values.map((e) => '${e.name} ${files[e]}').join('; ')}');
    _set(SoundStatus(engine: 'flutter_soloud', ready: true, files: files));
  }

  @override
  void play(HapticEvent event) {
    final source = _sources[event];
    if (source == null) return;
    final soloud = SoLoud.instance;
    try {
      final previous = _playing[event];
      if (previous != null && soloud.getIsValidVoiceHandle(previous)) unawaited(soloud.stop(previous));
      _playing[event] = soloud.play(source);
    } catch (e) {
      _log('Could not play the ${event.name} sound: $e');
    }
  }

  /// How far the latest [event] sound has played, or null if it isn't
  /// playing. For the on-device sound test.
  Duration? positionOf(HapticEvent event) {
    final handle = _playing[event];
    if (handle == null || !SoLoud.instance.getIsValidVoiceHandle(handle)) return null;
    return SoLoud.instance.getPosition(handle);
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
    try {
      await _loading;
      if (SoLoud.instance.isInitialized) SoLoud.instance.deinit();
    } catch (_) {}
  }

  void _set(SoundStatus s) {
    _status = s;
    if (!_changes.isClosed) _changes.add(s);
  }
}

/// Plays nothing and records what it was asked to play. For tests.
class FakeSoundPlayer implements SoundPlayer {
  final played = <HapticEvent>[];
  final _changes = StreamController<SoundStatus>.broadcast();

  @override
  SoundStatus status = SoundStatus(
    engine: 'fake',
    ready: true,
    files: {for (final e in HapticEvent.values) e: '${e.name}.ogg, 1.00 s'},
  );

  @override
  Stream<SoundStatus> get changes => _changes.stream;

  @override
  Future<void> load() async {}

  @override
  void play(HapticEvent event) => played.add(event);

  @override
  Future<void> dispose() => _changes.close();
}
