import 'dart:async';

import 'package:protocol/protocol.dart';

import 'game_types.dart';
import 'host_server.dart';

/// The slots kept for the players whose phone dropped (m12 bug 1107d): for
/// each one, the player as the round last saw them, [GamePlayer.away], the
/// host clock when its grace ends, and the timer that ends it.
///
/// [ServerGameHost] gives it the roster at every change. It holds a slot for a
/// player that dropped while a round runs, frees it when the phone is back or
/// the grace is over, and tells the viewers with `player_away` and
/// `player_back` (m12 §2). The slot's timer is owned here, from [_hold] on.
final class AwaySlots {
  AwaySlots({
    required this.server,
    required this.grace,
    required this.nowMs,
    required this.hasView,
    required this.onEnded,
  });

  /// Where the viewers' messages go. Each one needs [Capability.view], so a
  /// controller that doesn't show the game never gets one.
  final HostServer server;

  /// How long a dropped player keeps their slot: the host's grace.
  final Duration grace;

  /// The host's clock in ms: when a slot ends, and the seconds a phone is
  /// told, are measured on it.
  final int Function() nowMs;

  /// Whether the host shows a game to phones: only then does anyone hear
  /// about an away player (m12 §2.10).
  final bool Function() hasView;

  /// Called when a grace runs out on its own, so the host reports the roster
  /// again: the round goes on without them.
  final void Function() onEnded;

  final _slots = <String, _Slot>{};

  /// The players of the last check that could drop: a phone or a tablet, not
  /// a local player and not a simulated controller.
  Map<String, GamePlayer> _live = const {};

  /// The players who are away, in no particular order.
  Iterable<GamePlayer> get players => _slots.values.map((slot) => slot.player);

  bool get isEmpty => _slots.isEmpty;

  /// Notes the roster of this check: a player who was here at the last one and
  /// isn't now keeps their slot for [grace] while [roundRunning], and one whose
  /// phone is back loses it (m12 bug 1107d). A simulated controller never gets
  /// a slot: the round doesn't wait for a test tool. Nor does the host phone's
  /// own player, whose link drops with the host's own app (a lock does it): the
  /// host-away pause covers that, and no one is told to wait for the host
  /// (m12 code health N5).
  void noteRoster(List<GamePlayer> roster, {required bool roundRunning}) {
    final live = <String, GamePlayer>{
      for (final p in roster)
        if (!p.away && !p.local && !p.simulated && !p.ownPlayer) p.id: p,
    };
    for (final MapEntry(key: id, value: player) in _live.entries) {
      if (roundRunning && !live.containsKey(id) && !_slots.containsKey(id)) _hold(player);
    }
    for (final id in _slots.keys.toList()) {
      if (live.containsKey(id)) end(id);
    }
    _live = live;
  }

  /// Ends [id]'s slot: the player is back, the grace is over, or the round goes
  /// on without them. True when the player was away. While a view runs, the
  /// viewers hear it.
  bool end(String id) {
    final slot = _slots.remove(id);
    slot?.timer.cancel();
    if (slot != null && hasView()) _tellBack(id);
    return slot != null;
  }

  /// Frees every slot: the round is over. Its view has ended by then, so no
  /// viewer is told.
  void endAll() {
    for (final id in _slots.keys.toList()) {
      end(id);
    }
  }

  /// Tells [controllerId] about every player away now, with the seconds left:
  /// it paired mid-away and missed the messages (m12 §2).
  void sendTo(String controllerId) {
    final at = nowMs();
    for (final slot in _slots.values) {
      server.send(controllerId, slot.messageAt(at));
    }
  }

  /// Tells every viewer that [id] is no longer away. The phone that is coming
  /// back is skipped: it never showed a card for its own player, and the
  /// view's start follows it (m12 bug 1107d).
  void _tellBack(String id) {
    final message = PlayerBackMessage(playerId: id);
    for (final viewer in server.snapshot.connected) {
      if (viewer.controllerId != id) server.send(viewer.controllerId, message);
    }
  }

  /// Stops every timer and forgets every slot.
  void dispose() {
    for (final slot in _slots.values) {
      slot.timer.cancel();
    }
    _slots.clear();
  }

  /// Holds a slot for [player], away, until [end] or [grace] runs out, and
  /// tells the viewers how long the round waits for them.
  void _hold(GamePlayer player) {
    final at = nowMs();
    final timer = Timer(grace, () {
      if (end(player.id)) onEnded();
    });
    final slot = _Slot(
      GamePlayer(id: player.id, number: player.number, nickname: player.nickname, mode: player.mode, away: true),
      at + grace.inMilliseconds,
      timer,
    );
    _slots[player.id] = slot;
    if (hasView()) server.sendToAll(slot.messageAt(at));
  }
}

/// One away player, the host clock when its grace ends, and the timer that
/// ends it.
final class _Slot {
  _Slot(this.player, this.endsAtMs, this.timer);

  final GamePlayer player;
  final int endsAtMs;
  final Timer timer;

  /// The message a viewer gets at [nowMs]: who is away, the number a phone
  /// shows, and the whole seconds the round still waits for them, rounded up
  /// (0 when the grace is over).
  PlayerAwayMessage messageAt(int nowMs) =>
      PlayerAwayMessage(playerId: player.id, number: player.number, secondsLeft: _secondsLeft(nowMs));

  int _secondsLeft(int nowMs) {
    final ms = endsAtMs - nowMs;
    if (ms <= 0) return 0;
    final whole = ms ~/ Duration.millisecondsPerSecond;
    return ms % Duration.millisecondsPerSecond == 0 ? whole : whole + 1;
  }
}
