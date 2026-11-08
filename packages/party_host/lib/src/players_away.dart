import 'dart:async';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// One player the round is waiting for (m12 bug 1107d): the player whose phone
/// dropped and whose slot the host still holds, and the whole seconds the
/// round waits for them before it goes on.
typedef AwayPlayer = ({GamePlayer player, int secondsLeft});

/// The players whose phone dropped and whose slot the round still holds (m12
/// bug 1107d), with their countdown: empty while everyone is here. The screens
/// pause the round while it isn't, and the host's screen shows the away card.
final playersAwayProvider = NotifierProvider<PlayersAwayNotifier, List<AwayPlayer>>(PlayersAwayNotifier.new);

/// Keeps the away players and the seconds their grace has left in step with
/// the game host: a player is away from the first roster the host reports them
/// in until they are back or their slot ends, and their grace counts from that
/// moment on [GameHost.nowMs].
class PlayersAwayNotifier extends Notifier<List<AwayPlayer>> {
  /// The grace the host holds a dropped player's slot for, in s
  /// ([ServerGameHost.hostGraceS]): the card counts down to its end.
  static const graceS = ServerGameHost.hostGraceS;

  /// How often the countdown moves on: the card shows whole seconds.
  static const tick = Duration(seconds: 1);

  /// When each away player's slot started, on the host's clock, and the player
  /// as the host last reported them.
  final _slots = <String, ({GamePlayer player, int atMs})>{};

  /// Moves the countdown on while there is one: nothing ticks while everyone
  /// is here.
  Timer? _countdown;

  @override
  List<AwayPlayer> build() {
    final host = ref.watch(gameHostProvider);
    _note(ref.read(gamePlayersProvider), host.nowMs);
    final away = _away(host.nowMs);
    ref.listen(gamePlayersProvider, (_, players) => _refresh(players));
    ref.onDispose(_stopCountdown);
    _countdownWhile(away.isNotEmpty);
    return away;
  }

  void _refresh(List<GamePlayer> players) {
    final host = ref.read(gameHostProvider);
    _note(players, host.nowMs);
    final away = _away(host.nowMs);
    if (!listEquals(away, state)) state = away;
    _countdownWhile(away.isNotEmpty);
  }

  void _countdownWhile(bool away) {
    if (!away) {
      _stopCountdown();
      return;
    }
    _countdown ??= Timer.periodic(tick, (_) => _refresh(ref.read(gamePlayersProvider)));
  }

  void _stopCountdown() {
    _countdown?.cancel();
    _countdown = null;
  }

  /// Notes the players the round is waiting for, and forgets the ones it
  /// isn't: a phone back on the roster, or a slot that ended.
  void _note(List<GamePlayer> players, int nowMs) {
    final here = {for (final p in players) p.id};
    _slots.removeWhere((id, _) => !here.contains(id));
    for (final p in players) {
      if (p.away) {
        _slots.putIfAbsent(p.id, () => (player: p, atMs: nowMs));
      } else {
        _slots.remove(p.id);
      }
    }
  }

  /// The away players by number, each with the seconds their slot has left.
  List<AwayPlayer> _away(int nowMs) =>
      [for (final slot in _slots.values) (player: slot.player, secondsLeft: _secondsLeft(nowMs - slot.atMs))]
        ..sort((a, b) => a.player.number.compareTo(b.player.number));

  /// The whole seconds still to come of [graceS] after [elapsedMs]: 30 until
  /// the first second has passed, 0 when the slot is due to end.
  int _secondsLeft(int elapsedMs) {
    final leftMs = graceS * Duration.millisecondsPerSecond - elapsedMs;
    return max(0, (leftMs / Duration.millisecondsPerSecond).ceil());
  }
}
