import 'package:connection/connection.dart';

/// The host log's lines about the phones a round stops for (m12 bug 1107e,
/// 1108g): one when a phone drops and the round waits for it, and one when the
/// wait ends, saying how it ended.
///
/// A wait starts with a roster the host reports with the player
/// [GamePlayer.away] and ends with the host's [AwayEnded] event: the grace run
/// out, or the round gone on without the phone. A phone coming back shows on
/// the roster, as it did before (m12 bug 1107e). One that comes back after its
/// grace ran out only came back, so its line says nothing about the round going
/// on (m12 bug 1108g rule 1): the round never waited for it again.
class AwayLog {
  /// Writes to [log], the host's log.
  AwayLog(this._log);

  final LogSink _log;

  /// The numbers of the players the round waits for now.
  final _waiting = <int>{};

  /// The numbers of the players the round stopped waiting for this round, so
  /// their return is only a return.
  final _without = <int>{};

  /// Notes the players the host reports: a phone that dropped starts a wait,
  /// once, and a phone that is here again ends one.
  void note(List<GamePlayer> players) {
    for (final p in players) {
      if (p.away) {
        if (_waiting.add(p.number)) _log('P${p.number} away: the round waits for them');
      } else if (_waiting.remove(p.number)) {
        _log('P${p.number} back: the round goes on');
      } else if (_without.remove(p.number)) {
        _log('P${p.number} back');
      }
    }
  }

  /// Notes a wait ending without the phone back: its grace ran out, or someone
  /// chose Go on without them (m12 bug 1108g rule 1). The host ends a slot
  /// once, so each one gets its line.
  void ended(AwayEnded end) {
    final n = end.player.number;
    // A phone that is back keeps its wait until the roster shows it, so the
    // "back" line is written whichever of the two arrives first.
    if (end.reason != AwayEnd.back) _waiting.remove(n);
    switch (end.reason) {
      case AwayEnd.graceOver:
        _log('P$n didn\'t come back in ${end.grace.inSeconds} s: the round goes on without them');
        _without.add(n);
      case AwayEnd.wentOnWithout:
        _log('Go on without P$n: the round goes on');
        _without.add(n);
      case AwayEnd.back:
        // The roster says the phone is back: [note] writes that line.
        break;
      case AwayEnd.roundOver:
        // The round is over: its waits end with it, and the log says nothing.
        break;
    }
  }
}
