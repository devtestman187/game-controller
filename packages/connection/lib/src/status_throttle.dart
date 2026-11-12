import 'dart:async';

import 'package:protocol/protocol.dart';

/// The status panel's rate limit (M15 a2 moved this out of the server's game
/// host, which needed the room): a phone takes at most
/// [StatusMessage.maxPerSecond] panels a second, and the newest one waits for
/// the gap rather than being dropped.
class StatusThrottle {
  StatusThrottle({required this.nowMs, required this.send});

  /// The host's clock, in ms.
  final int Function() nowMs;

  /// Where a panel goes.
  final void Function(String playerId, StatusMessage status) send;

  final _statuses = <String, StatusMessage>{};
  final _sentMs = <String, int>{};
  final _timers = <String, Timer>{};

  /// The panel [playerId] was last given, or null when it has none.
  StatusMessage? statusOf(String playerId) => _statuses[playerId];

  /// Sets a player's panel: sent now when the gap is up, at its end otherwise.
  void set(String playerId, StatusMessage status) {
    if (status.isHidden) {
      _statuses.remove(playerId);
    } else {
      _statuses[playerId] = status;
    }
    final gap = 1000 ~/ StatusMessage.maxPerSecond;
    final since = nowMs() - (_sentMs[playerId] ?? -gap);
    if (since >= gap) {
      sendNow(playerId, status);
      return;
    }
    // Too soon: the newest one goes when the gap is up.
    _timers[playerId] ??= Timer(Duration(milliseconds: gap - since), () {
      _timers.remove(playerId);
      sendNow(playerId, _statuses[playerId] ?? StatusMessage.hidden());
    });
  }

  /// Sends [playerId]'s panel now, as a phone that just (re)joined gets it.
  void sendNow(String playerId, StatusMessage status) {
    _sentMs[playerId] = nowMs();
    send(playerId, status);
  }

  /// Drops the waiting timers.
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
  }
}
