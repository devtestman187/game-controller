import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

import '../host_grace.dart';
import '../providers.dart';

/// Every game this app version can draw (m12 §4): the registry the joined
/// view looks a `view_start`'s module up in. A game this app doesn't know is
/// shown as "Update the app" instead.
final gameRegistryProvider = Provider<GameRegistry>((ref) => GameRegistry([shapeRaceModule, arenaModule]));

/// Whether the host is showing this phone a game (m12 §5): true from a
/// [ViewStarted] until a [ViewEnded], or until the link to the host goes down.
///
/// It goes back to false whenever the client changes, because the notifier is
/// rebuilt for the new client and starts over: a phone that stops joining a
/// host (its own player takes the screens, m12 §3) shows no game, whatever
/// the last connection was showing.
final viewActiveProvider = NotifierProvider<ViewActiveNotifier, bool>(ViewActiveNotifier.new);

class ViewActiveNotifier extends Notifier<bool> {
  @override
  bool build() {
    final client = ref.watch(clientProvider);
    final sub = client.view.listen((event) {
      switch (event) {
        case ViewStarted():
          state = true;
        case ViewEnded():
          state = false;
        case ViewFrame() || HostAway() || HostBack():
          // A frame is only drawn while a view is on, and the away messages
          // don't change whether there is one (m12 §0.3).
          break;
      }
    });
    ref.onDispose(sub.cancel);
    // A link that goes down ends the view, whatever it drew last: a round that
    // finished while the phone was away must not stay on screen once it is
    // back (1107d Q3). The host starts the view again for a round that still
    // runs, and the last frame stays drawn under the card in the meantime
    // ([hostWaitProvider], m12-joined-view §0.3).
    ref.listen(clientStateProvider, (previous, next) {
      if (!next.isConnected) state = false;
    });
    return false;
  }
}

/// Which of the two waits a phone that shows a game is in (m12-joined-view
/// §0.3).
enum HostWaitKind {
  /// The host said it is away ([HostAway]) and counted the round down.
  hostAway,

  /// The link to the host dropped; the phone reconnects on its own.
  dropped,
}

/// What a phone that shows a game waits for (m12-joined-view §0.3): the kind
/// of wait, and how many seconds the round still runs from [sinceMs] on the
/// client's clock when the host gave a number.
typedef HostWait = ({HostWaitKind kind, int? secondsLeft, int sinceMs});

/// The wait a phone that shows a game is in (m12-joined-view §0.3), for the
/// card over the game: null when it waits for nothing.
///
/// Two things start a wait. A [HostAway] says how long the round still runs,
/// and the countdown runs from when it arrived. A link that drops while a view
/// is on is the other: an iOS host that is suspended can't say anything, so
/// the phone reconnects and gives it [hostGraceS] from the moment it noticed.
/// A host back, a new view, the end of the view or an [ClientStatus.idle]
/// client ends either; a reconnected link ends only the one the drop started,
/// so an away message keeps its countdown until the host says it is back.
final hostWaitProvider = NotifierProvider<HostWaitNotifier, HostWait?>(HostWaitNotifier.new);

class HostWaitNotifier extends Notifier<HostWait?> {
  HostWait? _away;
  HostWait? _dropped;
  bool _hasView = false;

  @override
  HostWait? build() {
    // A new client starts over, as the view does (m12 §5).
    _away = null;
    _dropped = null;
    _hasView = false;
    final client = ref.watch(clientProvider);
    final sub = client.view.listen(_onViewEvent);
    ref.onDispose(sub.cancel);
    ref.listen(clientStateProvider, _onClientState);
    return null;
  }

  void _onViewEvent(ViewEvent event) {
    switch (event) {
      case HostAway(:final secondsLeft, :final arrivedAtMs):
        _away = (kind: HostWaitKind.hostAway, secondsLeft: secondsLeft, sinceMs: arrivedAtMs);
      case HostBack():
        _away = null;
      case ViewStarted():
        _hasView = true;
        _away = null;
        _dropped = null;
      case ViewEnded():
        _hasView = false;
        _away = null;
        _dropped = null;
      case ViewFrame():
        return;
    }
    _publish();
  }

  void _onClientState(ClientSnapshot? previous, ClientSnapshot next) {
    if (next.isConnected) {
      _dropped = null;
    } else if (next.status == ClientStatus.idle) {
      // The player left, from Stop or Leave game: nothing is waited for, and
      // the next thing they see is the Connect screen (m12-joined-view §0.3).
      _away = null;
      _dropped = null;
      _hasView = false;
    } else if (_hasView && _dropped == null) {
      // The drop ended the view ([viewActiveProvider]); the card stands in for
      // it until the link is back, and the phone reconnects by itself.
      _dropped = (kind: HostWaitKind.dropped, secondsLeft: null, sinceMs: ref.read(clientProvider).nowMs);
      _hasView = false;
    }
    _publish();
  }

  void _publish() => state = _away ?? _dropped;
}

/// How long "the host was away too long" stays over the controls (m12 §0.5).
const abandonedNoticeDuration = Duration(seconds: 4);

/// Whether the phone says the host was away too long (m12 §0.5): a
/// [ViewEnded] with reason `abandoned` says so for
/// [abandonedNoticeDuration], and every other end or a new view hides it.
final abandonedNoticeProvider = NotifierProvider<AbandonedNoticeNotifier, bool>(AbandonedNoticeNotifier.new);

class AbandonedNoticeNotifier extends Notifier<bool> {
  Timer? _hide;

  @override
  bool build() {
    ref.onDispose(_cancel);
    final client = ref.watch(clientProvider);
    final sub = client.view.listen((event) {
      switch (event) {
        case ViewEnded(:final end):
          if (end.reason == ViewEndReason.abandoned) {
            _show();
          } else {
            _hideNow();
          }
        case ViewStarted():
          _hideNow();
        case ViewFrame() || HostAway() || HostBack():
          break;
      }
    });
    ref.onDispose(sub.cancel);
    return false;
  }

  void _show() {
    _cancel();
    state = true;
    _hide = Timer(abandonedNoticeDuration, _hideNow);
  }

  void _hideNow() {
    _cancel();
    if (state) state = false;
  }

  void _cancel() {
    _hide?.cancel();
    _hide = null;
  }
}
