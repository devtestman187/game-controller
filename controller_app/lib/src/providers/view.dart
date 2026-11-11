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
        case ViewEnded(:final end):
          // An end that carries the phone's own result keeps the last frame
          // drawn: the results card sits over it (M14 design section 9). A
          // second end, without a result, clears both.
          if (end.result == null) state = false;
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

/// The view events the phone's game draws (M14 design section 9): the
/// client's, but a `view_end` that carries this phone's own result is held
/// back, so the game keeps its last frame under the results card instead of
/// clearing it. The card's own provider reads that end from the client's
/// stream, and a later end without a result goes through and clears both.
final gameViewEventsProvider = Provider<Stream<ViewEvent>>((ref) {
  final client = ref.watch(clientProvider);
  // Broadcast, as the client's own view stream is: a game behind the pad may
  // come and go with the window's size, and each mount listens again.
  final events = StreamController<ViewEvent>.broadcast();
  final sub = client.view.listen((event) {
    if (event is ViewEnded && event.end.result != null) return;
    events.add(event);
  });
  ref.onDispose(() async {
    await sub.cancel();
    await events.close();
  });
  return events.stream;
});

/// The view the host started, and the last frame this phone drew of it (M14
/// r5 5): a Shape Race round's results card draws this phone's side's picture
/// from them, as the host's own card does. A new view clears it.
final viewDrawnProvider = NotifierProvider<ViewDrawnNotifier, ({ViewStartMessage start, GameSnapshot frame})?>(
  ViewDrawnNotifier.new,
);

class ViewDrawnNotifier extends Notifier<({ViewStartMessage start, GameSnapshot frame})?> {
  ViewStartMessage? _start;

  @override
  ({ViewStartMessage start, GameSnapshot frame})? build() {
    final client = ref.watch(clientProvider);
    _start = null;
    final sub = client.view.listen((event) {
      switch (event) {
        case ViewStarted(:final start):
          _start = start;
          state = null;
        case ViewEnded() || ViewFrame() || HostAway() || HostBack() || PlayerAway() || PlayerBack():
          // The end keeps the last frame: the results card sits over it. The
          // frames themselves come from the view, which is the one that
          // decodes them ([drawn]).
          break;
      }
    });
    ref.onDispose(sub.cancel);
    ref.listen(clientStateProvider, (previous, next) {
      if (!next.isConnected) {
        _start = null;
        state = null;
      }
    });
    return null;
  }

  /// The frame the game view started drawing, kept with its view's start.
  void drawn(GameSnapshot frame) {
    final start = _start;
    if (start == null) return;
    state = (start: start, frame: frame);
  }
}

/// The puzzle files this app can draw (M14 r5 5): loaded once for the results
/// card's photo, from the same files the game view's own viewer reads.
final puzzleLibraryProvider = FutureProvider<PuzzleLibrary>((ref) => PuzzleLibrary.load());

/// This phone's own result of the round it just drew (M14 design section 9):
/// the `result` a `view_end` carries, drawn as the card over the last frame.
/// A new view clears it, and so does a later `view_end` without a result — the
/// host left the results — while a phone sent no result at all keeps its pad,
/// as in M12.
final viewResultProvider = NotifierProvider<ViewResultNotifier, ViewResult?>(ViewResultNotifier.new);

class ViewResultNotifier extends Notifier<ViewResult?> {
  @override
  ViewResult? build() {
    final client = ref.watch(clientProvider);
    final sub = client.view.listen((event) {
      switch (event) {
        case ViewStarted():
          state = null;
        case ViewEnded(:final end):
          state = end.result;
        case ViewFrame() || HostAway() || HostBack() || PlayerAway() || PlayerBack():
          break;
      }
    });
    ref.onDispose(sub.cancel);
    ref.listen(clientStateProvider, (previous, next) {
      if (!next.isConnected) state = null;
    });
    return null;
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
/// client ends them all. So does a link that comes back: a host that accepts
/// a connection is not away (m12 fix-f2), and one that still runs a round
/// sends its view again. An away message that arrives after the reconnect
/// starts its own wait, countdown and all.
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
    // Every ping brings a snapshot while the link is up, so only the step
    // from down to up is a reconnect: it is what ends a host's wait.
    final cameBack = next.isConnected && !(previous?.isConnected ?? false);
    if (next.isConnected) {
      _dropped = null;
      // The host answered, so it is not away: a `host_away` whose `host_back`
      // went nowhere while the link was down can't outlive the link (m12
      // fix-f2). A host that still runs a round sends its view again, and one
      // that is away sends a new `host_away`.
      if (cameBack) _away = null;
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
