import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

/// The host clock and the Ticker's elapsed time, both moved by the test.
final class Clock {
  int nowMs = 0;
  Duration elapsed = Duration.zero;
  late final MemoryGameHost host = MemoryGameHost(now: () => nowMs);

  /// One drawn frame, [ms] after the last.
  void frame(ArenaSession session, int ms) {
    nowMs += ms;
    elapsed += Duration(milliseconds: ms);
    session.advance(elapsed);
  }
}

/// A Bumper Round's map: two starts either side of a coin zone.
ArenaMap bumperMap() => testMap(
  race: null,
  bumper: const BumperSpec(starts: [Offset(0.1, 0.3), Offset(0.9, 0.7)], coins: [centerZone]),
);

/// The one round_end record of [clock]'s host, once the Bumper Round's minute
/// of [session] has run out. The round is stepped in frames of 100 ms: the
/// session catches up at most maxCatchUpS a frame.
GameRecord bumperEnd(Clock clock, ArenaSession session, ArenaGame game) {
  for (var i = 0; i < 700 && game.phase == ArenaPhase.playing; i++) {
    clock.frame(session, 100);
  }
  expect(game.phase, ArenaPhase.over, reason: 'the minute ran out');
  return clock.host.records.firstWhere((r) => r.name == 'round_end');
}

void main() {
  test('a round Robo wins records robotWin, with no player and no stat of Robo’s', () {
    final clock = Clock()..host.setPlayer(const GamePlayer(id: 'p1', number: 1));
    final game = ArenaGame(map: bumperMap(), mode: ArenaMode.bumper, random: Random(1));
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    final end = bumperEnd(clock, session, game);

    expect(game.winnerId, roboPlayerId, reason: 'the lone player never moved, so Robo led on coins');
    expect(end.data['robotWin'], isTrue, reason: 'the round says who won, though it is no player’s win');
    expect(end.playerId, isNull, reason: 'a win is recorded for no player, so no stats count Robo');
    expect(clock.host.records.every((r) => r.playerId != roboPlayerId), isTrue, reason: 'no stats of Robo’s');
    session.dispose();
  });

  test('a round a player wins carries no robotWin, so old rounds and new read alike', () {
    final clock = Clock()
      ..host.setPlayer(const GamePlayer(id: 'a', number: 1))
      ..host.setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(map: testMap());
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      clock.frame(session, 16);
    }
    final end = clock.host.records.firstWhere((r) => r.name == 'round_end');

    expect(end.data['winner'], 'a');
    expect(end.data.containsKey('robotWin'), isFalse, reason: 'only a robot win says so');
    session.dispose();
  });

  test('a Bumper Round two players win carries no robotWin', () {
    final clock = Clock()
      ..host.setPlayer(const GamePlayer(id: 'p1', number: 1))
      ..host.setPlayer(const GamePlayer(id: 'p2', number: 2));
    final game = ArenaGame(map: bumperMap(), mode: ArenaMode.bumper, random: Random(1));
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    final end = bumperEnd(clock, session, game);

    expect(game.winnerId, isNot(roboPlayerId), reason: 'Robo has no seat with two players');
    expect(end.data.containsKey('robotWin'), isFalse);
    session.dispose();
  });
}
