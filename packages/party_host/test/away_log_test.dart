import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/away_log.dart';

/// The round's away lines (m12 bug 1108g): the host's end of a wait and the
/// roster can arrive in either order.
void main() {
  const here = GamePlayer(id: 'p2', number: 2);
  const away = GamePlayer(id: 'p2', number: 2, away: true);
  const grace = Duration(seconds: 30);

  test('a phone back within its grace says so, whether the roster or the end comes first', () {
    for (final endFirst in [true, false]) {
      final lines = <String>[];
      final log = AwayLog(lines.add)..note(const [away]);
      if (endFirst) log.ended((player: here, reason: AwayEnd.back, grace: grace));
      log.note(const [here]);
      if (!endFirst) log.ended((player: here, reason: AwayEnd.back, grace: grace));
      expect(lines, ['P2 away: the round waits for them', 'P2 back: the round goes on'], reason: 'endFirst $endFirst');
    }
  });

  test('a phone back after its grace ran out says only that it is back', () {
    final lines = <String>[];
    AwayLog(lines.add)
      ..note(const [away])
      ..ended((player: away, reason: AwayEnd.graceOver, grace: grace))
      ..note(const [here]);
    expect(lines, [
      'P2 away: the round waits for them',
      "P2 didn't come back in 30 s: the round goes on without them",
      'P2 back',
    ]);
  });
}
