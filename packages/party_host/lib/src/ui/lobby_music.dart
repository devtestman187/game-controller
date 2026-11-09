import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';

import '../providers.dart';
import '../sound.dart';
import '../sound_settings.dart';
import 'round_palette_hold.dart';

part 'lobby_music_widgets.dart';

/// The lobby music (M13 design section 8): the host plays it while a lobby is
/// open and no round is, and it carries on unbroken from the game picker to the
/// join screen.
///
/// A lobby is open while the game picker is ([LobbyHold]): anything pushed over
/// it still counts, so the Shape Race list, the puzzle settings, the join
/// screen, the stats and the settings keep it. A round is open while its screen
/// is ([RoundHold]): `PuzzleScreen` or `GameScreen`, their results and pause
/// included. So a round stops the music the moment it opens; Play again keeps
/// it off; and it comes back when the round's screens close to the join screen
/// or the picker, Change teams included.
///
/// It is wanted when a lobby is open, no round is, the Music setting is on, and
/// the app is shown: hidden or paused it stops (Android would play it in the
/// background otherwise), and coming back may start it again. Changes settle
/// after the frame, and only a change of what is wanted reaches the player, so
/// a route replaced in one frame (Play again, Change teams) never stops and
/// restarts the music. A hidden app draws no frame to settle in, so there the
/// music stops at once instead of playing on in the background.
///
/// It is a provider, disposed with the host's scope, and a loop still playing
/// stops with it, so the TV app and the phone host share it. Joined phones
/// never mount the picker, so they never play it.
class LobbyMusic {
  LobbyMusic(this._ref) {
    _shown = _isShown(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(onStateChange: _onState);
  }

  final Ref _ref;
  late final AppLifecycleListener _lifecycle;

  /// How many pickers ([LobbyHold]) and rounds ([RoundHold]) are open.
  int _lobbies = 0;
  int _rounds = 0;

  /// Whether the app is shown, and whether the music plays now.
  bool _shown = true;
  bool _playing = false;

  /// A settle waits for the frame's end: another change this frame joins it.
  bool _settling = false;

  /// The scope is gone: a settle still on its way has nothing left to tell.
  bool _disposed = false;

  /// The player the loop is playing on, so [dispose] can stop it: once the
  /// scope is gone the provider may not be read.
  SoundPlayer? _looping;

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

  /// A round opened: the music stops.
  void openRound() {
    if (_disposed) return;
    _rounds++;
    settle();
  }

  /// A round went: back on a lobby, the music may start again.
  void closeRound() {
    if (_disposed) return;
    if (_rounds > 0) _rounds--;
    settle();
  }

  /// The music is wanted now: a lobby is open, no round is, the Music volume
  /// isn't 0, and the app is shown. Mute doesn't stop it: it silences it
  /// through the volume, so unmuting carries on where the music is.
  bool get isWanted => _lobbies > 0 && _rounds == 0 && _shown && _ref.read(soundSettingsProvider).musicVolume > 0;

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
    _lifecycle.dispose();
    _looping?.stopLoop();
    _looping = null;
  }

  /// Starts or stops the music now, if what is wanted changed.
  void _apply() {
    if (_disposed) return;
    final wanted = isWanted;
    if (wanted == _playing) return;
    _playing = wanted;
    final player = _ref.read(soundPlayerProvider);
    if (wanted) {
      player.playLoop(SoundKey.lobby.eventName);
      _looping = player;
    } else {
      player.stopLoop();
      _looping = null;
    }
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

/// The lobby music, for the host's screens: the TV app and the phone host share
/// it, and it is disposed with the host's scope.
final lobbyMusicProvider = Provider<LobbyMusic>((ref) {
  final music = LobbyMusic(ref);
  // Music turned to 0 stops it on the picker, and turned up starts it again.
  ref.listen(soundSettingsProvider.select((s) => s.musicVolume > 0), (_, _) => music.settle());
  ref.onDispose(music.dispose);
  return music;
});
