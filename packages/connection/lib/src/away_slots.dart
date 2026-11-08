import 'dart:async';

import 'game_types.dart';

/// The slots kept for the players whose phone dropped (m12 bug 1107d): for
/// each one, the player as the round last saw them, [GamePlayer.away], and
/// the timer that ends the grace.
///
/// [ServerGameHost] owns one and puts [players] in its own list. A slot is
/// held until [end], its grace runs out, or [dispose]: the timer's owner is
/// this class, from [hold] on.
final class AwaySlots {
  final _slots = <String, _Slot>{};

  /// The players who are away, in no particular order.
  Iterable<GamePlayer> get players => _slots.values.map((slot) => slot.player);

  /// The IDs of the players who are away.
  Iterable<String> get ids => _slots.keys;

  bool get isEmpty => _slots.isEmpty;

  bool contains(String id) => _slots.containsKey(id);

  /// Holds a slot for [player], away, until [end] or [timer] fires.
  void hold(GamePlayer player, Timer timer) {
    _slots[player.id] = _Slot(
      GamePlayer(id: player.id, number: player.number, nickname: player.nickname, mode: player.mode, away: true),
      timer,
    );
  }

  /// Frees [id]'s slot and stops its timer. True when the player was away, so
  /// the caller knows whether the roster changed.
  bool end(String id) {
    final slot = _slots.remove(id);
    slot?.timer.cancel();
    return slot != null;
  }

  /// Frees every slot: the round is over.
  void endAll() {
    for (final id in _slots.keys.toList()) {
      end(id);
    }
  }

  /// Stops every timer and forgets every slot.
  void dispose() {
    for (final slot in _slots.values) {
      slot.timer.cancel();
    }
    _slots.clear();
  }
}

/// One away player and the timer that ends their grace.
final class _Slot {
  _Slot(this.player, this.timer);

  final GamePlayer player;
  final Timer timer;
}
