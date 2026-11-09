import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:game_assets/asset_manifest.dart';

import 'host_start_log.dart';
import 'sound_loop.dart';
import 'sound_wish.dart';

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

  /// Starts the engine again after the app was in the background, because iOS
  /// stops the app's sound when the phone locks or another app takes it and
  /// the engine doesn't come back by itself. A restart already running is
  /// shared, not doubled.
  Future<void> restart();

  /// Plays the sound for [name] (e.g. `hit`, `snap`, `time_up`). If the same
  /// sound is still playing it starts over instead of layering, so repeated
  /// events stay clear. An unknown name plays nothing.
  void play(String name);

  /// Starts [name] looping until [stopLoop] (the host's music, M13 section 8).
  /// There is one loop at a time: asking for the loop that is already playing
  /// does nothing, so the music never restarts, and another name stops the old
  /// loop first. A loop asked for before [load] finishes starts once the sounds
  /// are in, and one wanted across a [restart] starts again after it.
  ///
  /// [at] is the share of the loop (0 to 1) to start at, and [fade] how long to
  /// fade in over, while the old loop fades out over it: a round's tempo
  /// change keeps the place and cross-fades, so it sounds like the band
  /// speeding up rather than a new song (design section 8, rule 3).
  void playLoop(String name, {double at = 0, Duration fade = Duration.zero});

  /// Pauses the loop where it is: a round that stands still keeps its music,
  /// silent (M13 design section 8, rule 2). Nothing happens if none plays.
  void pauseLoop();

  /// Carries on from where [pauseLoop] paused the loop, if one is.
  void resumeLoop();

  /// Stops the loop, if one is playing, over [fade] when one is given: the
  /// results' short fade, so `time_up` and `success` are heard clearly (M13
  /// design section 8, rule 2).
  void stopLoop({Duration fade = Duration.zero});

  /// How far the loop has played, 0 to 1, or null when none plays: the share a
  /// tempo change starts the new loop at.
  double? get loopShare;

  /// Stops the sound for [name] if it is still playing: the 3-2-1 stops when a
  /// round stands still, so no "go" sounds over it.
  void stop(String name);

  /// The volume the game's sounds play at: 0 is silence, 1 the files' own
  /// loudness. It stays as it was set across a [load] and a [restart].
  double get volume;
  set volume(double value);

  /// The volume the loop (the host's music, the lobby's or the round's) plays
  /// at, apart from the sounds' (owner, Nov 9, 2026: one volume for the music
  /// and one for the sounds). A change reaches a loop already playing.
  double get musicVolume;
  set musicVolume(double value);

  /// Stops the engine and releases the sounds.
  Future<void> dispose();
}

/// Plays through flutter_soloud (SoLoud + miniaudio), which bundles its own
/// OGG and WAV decoders, so Android TV and Windows play the same files with
/// no codecs installed.
class SoLoudSoundPlayer implements SoundPlayer {
  /// [log] gets short lines about the engine and each sound. [start] is the
  /// log of the host's start this player belongs to (m12 bug 1108b): its first
  /// load adds when the engine came up and when the sounds were in, so a phone
  /// that froze while it started names that step too.
  SoLoudSoundPlayer({LogSink? log, HostStartLog? start}) : this._(log ?? ((_) {}), start);

  SoLoudSoundPlayer._(this._log, this._start);

  final LogSink _log;

  /// The start's log, for this player's first load only (see [_load]).
  final HostStartLog? _start;
  final _changes = StreamController<SoundStatus>.broadcast();
  final _sources = <SoundKey, AudioSource>{};
  final _playing = <SoundKey, SoundHandle>{};
  SoundStatus _status = const SoundStatus(engine: 'flutter_soloud');
  Future<void>? _loading;
  Future<void>? _restarting;

  /// What this player has been asked for, whatever the engine can do now (M13
  /// section 8): the loop wanted and the volume. It survives a load and a
  /// restart, so both are carried out once the engine is up.
  SoundWish _wish = const SoundWish();

  /// The loop sounding now, if one is (the host's music, M13 section 8).
  late final SoundLoop _loop = SoundLoop(sources: _sources, volume: () => _wish.musicVolume, log: _log);

  @override
  SoundStatus get status => _status;

  @override
  Stream<SoundStatus> get changes => _changes.stream;

  @override
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    // A restart after the app was hidden is not a start: its engine's time
    // would read as a frame frozen minutes after the tap (m12 bug 1108b).
    final start = _restarting == null ? _start : null;
    final soloud = SoLoud.instance;
    try {
      await soloud.init();
    } catch (e) {
      _log('Sound engine could not start, sounds are off: $e');
      _set(SoundStatus(engine: 'flutter_soloud', error: '$e'));
      return;
    }
    start?.step(HostStartStep.soundEngineInit);
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
    start?.step(HostStartStep.soundsLoaded);
    _set(SoundStatus(engine: 'flutter_soloud', ready: true, files: files));
    // What was asked for while the sounds were loading, or before a restart:
    // the loop that should be playing, at the music's volume (M13 section 8).
    _applyLoop();
  }

  @override
  Future<void> restart() => _restarting ??= _restart().whenComplete(() => _restarting = null);

  Future<void> _restart() async {
    // A load still running would put back the sources this restart replaces.
    await _loading;
    try {
      if (SoLoud.instance.isInitialized) SoLoud.instance.deinit();
    } catch (e) {
      // Loading below starts the engine over, whatever state it stopped in.
      _log('Could not stop the sound engine to restart it: $e');
    }
    _sources.clear();
    _playing.clear();
    // The engine's handles die with it; the wish below outlives them, so the
    // loop and the volume come back with the new engine.
    _loop.reset();
    _loading = null;
    await load();
    _log('Sound engine restarted (${_status.loaded} of ${SoundKey.values.length} sounds)');
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
      _playing[key] = soloud.play(source, volume: _wish.volume);
    } catch (e) {
      _log('Could not play the $name sound: $e');
    }
  }

  @override
  void playLoop(String name, {double at = 0, Duration fade = Duration.zero}) {
    _wish = _wish.withLoop(name);
    _applyLoop(at: at, fade: fade);
  }

  @override
  void pauseLoop() => _loop.pause();

  @override
  void resumeLoop() => _loop.resume();

  @override
  void stopLoop({Duration fade = Duration.zero}) {
    _wish = _wish.withLoop(null);
    _applyLoop(fade: fade);
  }

  @override
  double? get loopShare => _loop.share;

  @override
  void stop(String name) {
    final key = SoundKey.byEventName(name);
    final handle = key == null ? null : _playing.remove(key);
    if (handle == null) return;
    final soloud = SoLoud.instance;
    try {
      if (soloud.getIsValidVoiceHandle(handle)) unawaited(soloud.stop(handle));
    } catch (e) {
      _log('Could not stop the $name sound: $e');
    }
  }

  @override
  double get volume => _wish.volume;

  @override
  set volume(double value) => _wish = _wish.withVolume(value);

  @override
  double get musicVolume => _wish.musicVolume;

  @override
  set musicVolume(double value) {
    _wish = _wish.withMusicVolume(value);
    _loop.setVolume(_wish.musicVolume);
  }

  /// Makes the engine play the loop this player has been asked for (M13 section
  /// 8): the old loop stops first when it isn't the one wanted, over the same
  /// fade the new one fades in over, and nothing happens while no sounds are
  /// in, because the load applies the wish when it ends.
  void _applyLoop({double at = 0, Duration fade = Duration.zero}) {
    if (!_status.ready) return;
    final sounding = _loop.name;
    if (_wish.stopsFrom(sounding)) _loop.stop(fade: fade);
    final start = _wish.startsFrom(sounding);
    if (start != null) _loop.play(start, at: at, fade: fade);
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
    _loop.dispose();
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
