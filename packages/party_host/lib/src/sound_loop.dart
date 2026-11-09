import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:game_assets/asset_manifest.dart';

/// The one loop the sound engine keeps sounding (M13 design section 8): the
/// host's music, started at a share of itself, paused where it is, and
/// cross-faded into another tempo at the same share. [SoLoudSoundPlayer] owns
/// one and carries out the wish it is given; this is only the engine's side.
///
/// A tempo change starts the new loop in a second voice and fades the old one
/// out, so the two never cut each other off; the old voice is stopped when its
/// fade is done, by a timer this class owns and cancels.
class SoundLoop {
  /// [sources] is where the player keeps the sounds it loaded, [volume] the
  /// music volume to start and fade to (read each time), and [log] where
  /// engine trouble goes.
  SoundLoop({required this.sources, required this.volume, required this.log});

  /// Where each sound is loaded, or missing if it isn't.
  final Map<SoundKey, AudioSource> sources;

  /// The volume the music plays at, 0 to 1.
  final double Function() volume;

  /// Where engine trouble goes.
  final LogSink log;

  /// How long the fade's timer may run past the fade before the voice stops:
  /// stopping it a frame late costs nothing, since it is silent by then.
  static const _fadeSlack = Duration(milliseconds: 16);

  SoundHandle? _handle;
  String? _name;

  /// Whether the loop is paused (a round that stands still, M13 section 8). It
  /// survives a [reset], so a restart after the app was hidden comes back as
  /// the round left it.
  bool _paused = false;

  /// The voices fading out, and the timer that stops each.
  final _fading = <SoundHandle, Timer>{};

  /// The name of the loop sounding now, or null.
  String? get name => _name;

  /// Starts [name] from [at], the share of the loop (0 to 1) to begin at: a
  /// tempo change starts the new loop at the place the old one had reached
  /// (M13 design section 8, rule 3). With a [fade] it fades in over it, and a
  /// voice still sounding is stopped at once: the player stops the old loop
  /// with the same fade first, so the two cross-fade.
  void play(String name, {double at = 0, Duration fade = Duration.zero}) {
    final source = _source(name);
    if (source == null) return;
    final soloud = SoLoud.instance;
    try {
      final old = _handle;
      final fades = fade > Duration.zero;
      final handle = soloud.play(source, looping: true, volume: fades ? 0 : volume());
      _handle = handle;
      _name = name;
      _seek(handle, source, at);
      if (old != null) _fadeOut(old, Duration.zero);
      if (fades) soloud.fadeVolume(handle, volume(), fade);
      if (_paused) soloud.setPause(handle, true);
    } catch (e) {
      log('Could not play the $name loop: $e');
    }
  }

  /// Stops the loop, over [fade] when one is given: the results' 300 ms, so
  /// `time_up` and `success` are heard clearly (M13 design section 8, rule 2).
  void stop({Duration fade = Duration.zero}) {
    final handle = _handle;
    final paused = _paused;
    _handle = null;
    _name = null;
    _paused = false;
    if (handle == null) return;
    // A pause left the voice waiting: it carries on for the fade, so the
    // results hear the music go rather than silence (design section 8, rule 2).
    if (paused) _pauseVoice(handle, false);
    _fadeOut(handle, fade);
  }

  /// Pauses the loop where it is: a round that stands still keeps its music.
  void pause() {
    _paused = true;
    _setPaused(true);
  }

  /// Carries on where [pause] left the loop.
  void resume() {
    _paused = false;
    _setPaused(false);
  }

  /// Sets the loop's volume now: a Music volume change reaches it as it plays.
  void setVolume(double value) {
    final handle = _handle;
    if (handle == null) return;
    final soloud = SoLoud.instance;
    try {
      if (soloud.getIsValidVoiceHandle(handle)) soloud.setVolume(handle, value);
    } catch (e) {
      log('Could not set the music volume: $e');
    }
  }

  /// How far the loop has played, 0 to 1, or null when none plays: the share a
  /// tempo change keeps.
  double? get share {
    final handle = _handle;
    final name = _name;
    if (handle == null || name == null) return null;
    final source = _source(name);
    if (source == null) return null;
    final soloud = SoLoud.instance;
    try {
      if (!soloud.getIsValidVoiceHandle(handle)) return null;
      final lengthMs = soloud.getLength(source).inMilliseconds;
      if (lengthMs <= 0) return null;
      return (soloud.getPosition(handle).inMilliseconds / lengthMs).clamp(0.0, 1.0).toDouble();
    } catch (e) {
      log('Could not read the $name loop\'s place: $e');
      return null;
    }
  }

  /// The engine is starting over, so its voices are gone: the loop with them.
  /// The paused state stays, so a restart comes back as the round left it.
  void reset() {
    for (final timer in _fading.values) {
      timer.cancel();
    }
    _fading.clear();
    _handle = null;
    _name = null;
  }

  /// Stops every timer this loop keeps.
  void dispose() => reset();

  AudioSource? _source(String name) {
    final key = SoundKey.byEventName(name);
    return key == null ? null : sources[key];
  }

  /// Starts [handle] at [at] of [source]: a tempo change keeps the place.
  void _seek(SoundHandle handle, AudioSource source, double at) {
    final share = at.clamp(0.0, 1.0).toDouble();
    if (share <= 0) return;
    final soloud = SoLoud.instance;
    try {
      soloud.seek(handle, soloud.getLength(source) * share);
    } catch (e) {
      log('Could not move the ${_name ?? 'music'} loop: $e');
    }
  }

  /// Fades [handle] to silence over [fade] and stops it when it is there; with
  /// no fade it stops at once.
  void _fadeOut(SoundHandle handle, Duration fade) {
    final soloud = SoLoud.instance;
    try {
      if (!soloud.getIsValidVoiceHandle(handle)) return;
      if (fade <= Duration.zero) {
        unawaited(soloud.stop(handle));
        return;
      }
      soloud.fadeVolume(handle, 0, fade);
      _fading[handle] = Timer(fade + _fadeSlack, () {
        _fading.remove(handle);
        _stopVoice(handle);
      });
    } catch (e) {
      log('Could not stop the loop: $e');
    }
  }

  void _stopVoice(SoundHandle handle) {
    final soloud = SoLoud.instance;
    try {
      if (soloud.getIsValidVoiceHandle(handle)) unawaited(soloud.stop(handle));
    } catch (e) {
      log('Could not stop the loop: $e');
    }
  }

  void _setPaused(bool paused) {
    final handle = _handle;
    if (handle != null) _pauseVoice(handle, paused);
  }

  void _pauseVoice(SoundHandle handle, bool paused) {
    final soloud = SoLoud.instance;
    try {
      if (soloud.getIsValidVoiceHandle(handle)) soloud.setPause(handle, paused);
    } catch (e) {
      log('Could not ${paused ? 'pause' : 'resume'} the music: $e');
    }
  }
}
