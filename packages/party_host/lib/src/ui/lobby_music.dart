import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music_loop.dart';
import '../providers.dart';
import '../sound.dart';
import '../sound_settings.dart';
import 'round_palette_hold.dart';
import 'round_phase.dart';

part 'lobby_music_widgets.dart';

/// The host's music (M13 design section 8): the lobby's loop while a lobby is
/// open and no round is, and the round's own loop from the round's "go" to its
/// results, which speeds up as Shape Race's clock runs out.
///
/// A lobby is open while the game picker is ([LobbyHold]): anything pushed over
/// it still counts, so the Shape Race list, the puzzle settings, the join
/// screen, the stats and the settings keep it. A round is open while its screen
/// is ([RoundHold]): `PuzzleScreen` or `GameScreen`, their results and pause
/// included. So a round stops the lobby music the moment it opens; Play again
/// keeps it off; and it comes back when the round's screens close to the join
/// screen or the picker, Change teams included. The two never play together.
///
/// The round's music starts at the round's "go" ([RoundPhase.playing], which
/// `Pausable` publishes after the 3-2-1, or at once where there is no beat) and
/// follows the round's clock: `round`, then `round_hurry` at the puzzle's
/// `warningS` left, then `round_final` at `warningS / 3` ([MusicLoop.forRound]).
/// The round's screen reports its clock and its results ([roundScreenOpened]
/// and the like); a tempo change starts the new loop at the same share and
/// cross-fades, so it sounds like the band speeding up.
///
/// A round that stands still (the beat, the pause menu, the host away, a phone
/// it waits for, all [RoundPhase.none] or [RoundPhase.ready]) pauses the music
/// where it is, and coming back carries on. The results end it with a short
/// fade instead, so `time_up` and `success` are heard clearly.
///
/// It is wanted when the Music setting isn't 0 and the app is shown: hidden or
/// paused it stops at once (Android would play it in the background
/// otherwise), and coming back may start it again. Mute doesn't stop it: it
/// silences it through the volume, so unmuting carries on where the music is.
/// Changes settle after the frame, and only a change of what is wanted reaches
/// the player, so a route replaced in one frame (Play again, Change teams)
/// never stops and restarts the music.
///
/// It is a provider, disposed with the host's scope, and a loop still playing
/// stops with it, so the TV app and the phone host share it. Joined phones
/// mount neither the picker nor a round's screen, so they never play it.
class HostMusic {
  HostMusic(this._ref) {
    _shown = _isShown(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(onStateChange: _onState);
    _phase = _ref.read(roundPhaseProvider)..addListener(_onPhase);
  }

  /// A tempo change cross-fades over this long, so it sounds like the band
  /// speeding up rather than a new song (M13 design section 8, rule 3).
  static const switchFade = Duration(milliseconds: 120);

  /// The round's music fades out over this long when the results come, so
  /// `time_up` and `success` are heard clearly (design section 8, rule 2).
  static const resultsFade = Duration(milliseconds: 300);

  final Ref _ref;
  late final AppLifecycleListener _lifecycle;
  late final RoundPhaseSignal _phase;

  /// How many pickers ([LobbyHold]) and rounds ([RoundHold]) are open.
  int _lobbies = 0;
  int _rounds = 0;

  /// The round's screen that reports its clock and its end, and what it last
  /// said: the time left, the puzzle's warning, and whether the results are up.
  /// A screen on its way out (Play again) says nothing over its replacement.
  Object? _roundWriter;
  int? _timeLeftMs;
  int _warningS = 0;
  bool _roundEnded = false;

  /// Whether the app is shown.
  bool _shown = true;

  /// The loop the player was given, or null when no music plays, and whether
  /// it is paused where it is.
  MusicLoop? _current;
  bool _paused = false;

  /// A settle waits for the frame's end: another change this frame joins it.
  bool _settling = false;

  /// The scope is gone: a settle still on its way has nothing left to tell.
  bool _disposed = false;

  /// The player the music is on, so [dispose] can stop it: once the scope is
  /// gone the provider may not be read.
  SoundPlayer? _playingOn;

  /// A picker opened: the music may start.
  void openLobby() {
    if (_disposed) return;
    _lobbies++;
    settle();
  }

  /// A picker went: with no other open, the music may stop.
  void closeLobby() {
    if (_disposed) return;
    if (_lobbies > 0) _lobbies--;
    settle();
  }

  /// A round opened: the lobby's music stops, and the round's may start at its
  /// "go".
  void openRound() {
    if (_disposed) return;
    _rounds++;
    settle();
  }

  /// A round went: back on a lobby, the lobby's music may start again.
  void closeRound() {
    if (_disposed) return;
    if (_rounds > 0) _rounds--;
    settle();
  }

  /// A round's screen opened: its clock and its end are [writer]'s to report
  /// from here. The round's music starts at the round's own "go", so a Play
  /// again's round waits for its 3-2-1 like any other.
  void roundScreenOpened(Object writer) {
    if (_disposed) return;
    _roundWriter = writer;
    _roundEnded = false;
    _timeLeftMs = null;
    _warningS = 0;
    settle();
  }

  /// [writer]'s round has [timeLeftMs] left on its clock and the puzzle's
  /// [warningS] warning: the tempo follows them (M13 design section 8, rule 3).
  /// The round's screen calls this every frame; only a change of tempo reaches
  /// the player.
  void roundScreenClock(Object writer, {required int timeLeftMs, required int warningS}) {
    if (_disposed || _roundEnded || !identical(writer, _roundWriter)) return;
    final before = _roundLoop;
    _timeLeftMs = timeLeftMs;
    _warningS = warningS;
    if (_roundLoop != before) _apply();
  }

  /// [writer]'s round ended (the results): its music fades out rather than
  /// pausing, so `time_up` and `success` are heard clearly.
  void roundEnded(Object writer) {
    if (_disposed || _roundEnded || !identical(writer, _roundWriter)) return;
    _roundEnded = true;
    _apply();
  }

  /// [writer]'s round's screen went: nothing of it speaks for the music again.
  void roundScreenClosed(Object writer) {
    if (_disposed || !identical(writer, _roundWriter)) return;
    _roundWriter = null;
    _timeLeftMs = null;
    _warningS = 0;
    settle();
  }

  /// Applies a change after the frame, once the whole frame has said what it
  /// wants: the music stops and starts only when what is wanted changed.
  void settle() {
    if (_settling || _disposed) return;
    _settling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settling = false;
      _apply();
    });
    // A frame to settle in: a lifecycle change need not come with one.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Disposed with the host's scope: a loop still playing stops with it, rather
  /// than waiting on the engine's own teardown (M13 design section 8).
  void dispose() {
    _disposed = true;
    _phase.removeListener(_onPhase);
    _lifecycle.dispose();
    _playingOn?.stopLoop();
    _playingOn = null;
  }

  /// Whether the device may hear music now: the Music setting isn't 0 and the
  /// app is shown. Mute is the player's volume, so it leaves the music playing.
  bool get _heard => _shown && _ref.read(soundSettingsProvider).musicVolume > 0;

  /// The round's loop for the clock as it stands: [MusicLoop.round] while the
  /// round has no clock (the Arena) or no warning.
  MusicLoop get _roundLoop => MusicLoop.forRound(timeLeftMs: _timeLeftMs, warningS: _warningS);

  /// The loop wanted now, or null for no music: a round's while its round runs
  /// and isn't over, the lobby's while a lobby is open and no round is.
  MusicLoop? get _wanted {
    if (_rounds > 0) return _roundEnded || !_isPlayingRound ? null : _roundLoop;
    return _lobbies > 0 ? MusicLoop.lobby : null;
  }

  /// Whether the round runs: from its "go" ([RoundPhase.playing]) until the
  /// countdown, a pause, a wait or the results stop it.
  bool get _isPlayingRound => _phase.value == RoundPhase.playing;

  /// Whether [loop] is one of the round's three tempos.
  static bool _isRoundLoop(MusicLoop? loop) =>
      loop == MusicLoop.round || loop == MusicLoop.roundHurry || loop == MusicLoop.roundFinal;

  /// Starts, pauses, resumes, switches or stops the music now, if what is
  /// wanted changed.
  void _apply() {
    if (_disposed) return;
    final player = _ref.read(soundPlayerProvider);
    if (!_heard) return _stop(player, fade: Duration.zero);
    if (_held(player)) return;
    final wanted = _wanted;
    if (wanted == _current) return _resume(player);
    if (wanted == null) {
      return _stop(player, fade: _roundEnded && _isRoundLoop(_current) ? resultsFade : Duration.zero);
    }
    _start(player, wanted);
  }

  /// A round that stands still (the beat, a pause, a wait, the host away) keeps
  /// its music, paused where it is: true when the music is left as it is. The
  /// results are not a pause but the end ([_apply] stops them), and the lobby's
  /// loop is not the round's to keep.
  bool _held(SoundPlayer player) {
    if (_rounds == 0 || _roundEnded || _isPlayingRound || !_isRoundLoop(_current)) return false;
    if (_paused) return true;
    player.pauseLoop();
    _paused = true;
    _playingOn = player;
    return true;
  }

  /// The loop wanted is the one playing: a pause left it, so it carries on.
  void _resume(SoundPlayer player) {
    if (!_paused) return;
    player.resumeLoop();
    _paused = false;
    _playingOn = player;
  }

  /// Starts [loop], at the place the old one had reached and cross-faded when
  /// it is another of the round's tempos (design section 8, rule 3).
  void _start(SoundPlayer player, MusicLoop loop) {
    final switching = _isRoundLoop(_current) && _isRoundLoop(loop);
    // The lobby's loop and the round's never play together: the one leaving
    // stops before the other starts.
    if (_current != null && !switching) player.stopLoop();
    final double at = switching ? player.loopShare ?? 0 : 0;
    player.playLoop(loop.eventName, at: at, fade: switching ? switchFade : Duration.zero);
    _current = loop;
    _paused = false;
    _playingOn = player;
  }

  void _stop(SoundPlayer player, {required Duration fade}) {
    if (_current == null && !_paused) return;
    player.stopLoop(fade: fade);
    _current = null;
    _paused = false;
    _playingOn = null;
  }

  /// The round's phase changed: the music starts, pauses or carries on with it.
  void _onPhase() {
    if (_disposed) return;
    _apply();
  }

  void _onState(AppLifecycleState state) {
    final shown = _isShown(state);
    if (shown == _shown) return;
    _shown = shown;
    if (shown) {
      settle();
      return;
    }
    // No frame is drawn while the app is hidden, so a stop left to the frame's
    // end would never come and the music would play on in the background (M13
    // section 8, Android): it stops at once.
    _apply();
  }

  /// Whether the app is shown in [state]: hidden, paused and detached are not.
  /// No state yet means the app has not said otherwise, so it is shown.
  static bool _isShown(AppLifecycleState? state) =>
      state != AppLifecycleState.hidden && state != AppLifecycleState.paused && state != AppLifecycleState.detached;
}

/// The host's music, for the host's screens: the TV app and the phone host
/// share it, and it is disposed with the host's scope. It keeps the lobby
/// music's provider name, its first job (M13 step 7).
final lobbyMusicProvider = Provider<HostMusic>((ref) {
  final music = HostMusic(ref);
  // Music turned to 0 stops it (in a lobby or a round), and turned up starts
  // it again.
  ref.listen(soundSettingsProvider.select((s) => s.musicVolume > 0), (_, _) => music.settle());
  ref.onDispose(music.dispose);
  return music;
});
