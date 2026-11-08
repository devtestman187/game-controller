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
        case ViewFrame() || HostAway() || HostBack() || PlayerAway() || PlayerBack():
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

/// Which of the waits a phone that shows a game is in (m12-joined-view §0.3,
/// m12 bug 1107d).
enum HostWaitKind {
  /// The host said it is away ([HostAway]) and counted the round down.
  hostAway,

  /// The link to the host dropped; the phone reconnects on its own.
  dropped,

  /// The game holds a place for a player who dropped ([PlayerAway]): the card
  /// says which players, and how long the round waits for them.
  playerAway,
}

/// A player the host waits for (m12 bug 1107d): the player number the host
/// gave it, and the seconds the round still waits for it, counted from when
/// the message arrived on this phone's clock.
typedef AwayWait = ({String playerId, int number, int secondsLeft, int sinceMs});

/// What a phone that shows a game waits for (m12-joined-view §0.3, m12 bug
/// 1107d): the kind of wait, how many seconds the round still runs from
/// [sinceMs] on the client's clock when the host gave a number, and, for
/// [HostWaitKind.playerAway], one [AwayWait] per player waited for, in player
/// order.
typedef HostWait = ({HostWaitKind kind, int? secondsLeft, int sinceMs, List<AwayWait> away});

/// The wait a phone that shows a game is in (m12-joined-view §0.3, m12 bug
/// 1107d), for the card over the game: null when it waits for nothing.
///
/// Three things start a wait. A [HostAway] says how long the round still runs,
/// and the countdown runs from when it arrived. A link that drops while a view
/// is on is the second: an iOS host that is suspended can't say anything, so
/// the phone reconnects and gives it [hostGraceS] from the moment it noticed.
/// A [PlayerAway] is the third: the game holds a place for a player who
/// dropped, one line each, until it comes back or the game goes on without
/// them. The host's own wait comes first whenever it and a player's meet.
///
/// A host back, a new view, the end of the view or an [ClientStatus.idle]
/// client ends them all; a reconnected link ends only the one the drop
/// started, so an away message keeps its countdown until the host says it is
/// back.
final hostWaitProvider = NotifierProvider<HostWaitNotifier, HostWait?>(HostWaitNotifier.new);

class HostWaitNotifier extends Notifier<HostWait?> {
  HostWait? _away;
  HostWait? _dropped;

  /// The players the host waits for, by player id (m12 bug 1107d). The phone
  /// that was away hears its own player's message too when it pairs back into
  /// a round that still waits, and shows no line for itself.
  final _players = <String, AwayWait>{};
  bool _hasView = false;

  @override
  HostWait? build() {
    // A new client starts over, as the view does (m12 §5).
    _away = null;
    _dropped = null;
    _players.clear();
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
        _away = (kind: HostWaitKind.hostAway, secondsLeft: secondsLeft, sinceMs: arrivedAtMs, away: const []);
      case HostBack():
        _away = null;
      case PlayerAway(:final playerId, :final number, :final secondsLeft, :final arrivedAtMs):
        if (playerId != ref.read(clientProvider).identity.controllerId) {
          _players[playerId] = (playerId: playerId, number: number, secondsLeft: secondsLeft, sinceMs: arrivedAtMs);
        }
      case PlayerBack(:final playerId):
        _players.remove(playerId);
      case ViewFrame():
        // Frames stop while the game waits for a player, so one that comes
        // after the seconds the host gave means it went on without them (m12
        // bug 1107d).
        final nowMs = ref.read(clientProvider).nowMs;
        _players.removeWhere((_, away) => nowMs - away.sinceMs >= away.secondsLeft * _msPerSecond);
      case ViewStarted():
        _hasView = true;
        _away = null;
        _dropped = null;
        _players.clear();
      case ViewEnded():
        _hasView = false;
        _away = null;
        _dropped = null;
        _players.clear();
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
      _players.clear();
      _hasView = false;
    } else if (_hasView && _dropped == null) {
      // The drop ended the view ([viewActiveProvider]); the card stands in for
      // it until the link is back, and the phone reconnects by itself. The
      // round's away players come again with the view that comes back.
      _dropped = (
        kind: HostWaitKind.dropped,
        secondsLeft: null,
        sinceMs: ref.read(clientProvider).nowMs,
        away: const [],
      );
      _players.clear();
      _hasView = false;
    }
    _publish();
  }

  void _publish() => state = _away ?? (_players.isEmpty ? _dropped : _playersWait());

  /// The wait for every player the host holds the game for: one entry each, in
  /// player order, from the first of them so the card has a start.
  HostWait _playersWait() {
    final away = _players.values.toList()..sort((a, b) => a.number.compareTo(b.number));
    final sinceMs = away.map((a) => a.sinceMs).reduce((a, b) => a < b ? a : b);
    return (kind: HostWaitKind.playerAway, secondsLeft: null, sinceMs: sinceMs, away: away);
  }
}

/// A second in ms, the unit the host gives its seconds in.
const _msPerSecond = Duration.millisecondsPerSecond;

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
        case ViewFrame() || HostAway() || HostBack() || PlayerAway() || PlayerBack():
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
