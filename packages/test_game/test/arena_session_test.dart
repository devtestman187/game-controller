import 'dart:ui';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

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

void main() {
  test('a round records one start, one end and one frame count, timed by the step it was won on', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1, nickname: 'Phone a'))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(walls: const [], hazards: const []);
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      clock.frame(session, 16);
    }
    expect(game.phase, ArenaPhase.won);

    final names = clock.host.records.map((r) => r.name).toList();
    expect(names.where((n) => n == 'round_start'), hasLength(1));
    expect(names.where((n) => n == 'round_end'), hasLength(1));
    expect(names.where((n) => n == 'frames'), hasLength(1));
    final end = clock.host.records.firstWhere((r) => r.name == 'round_end');
    expect(end.game, arenaGame);
    expect(end.playerId, 'a');
    expect(end.data['winner'], 'a');
    expect(end.data['modes'], {'a': 'dpad'});
    // The round clock is one step per step, so the win's time is the step
    // count times the step length.
    expect(end.data['timeS'], closeTo(session.stepCount * HostingSettings.defaults.simStepS, 1e-9));
    expect(clock.host.records.last.data['drawn'], greaterThan(1));
    session.dispose();
  });

  test('the round break starts a new round, with its own start record', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(walls: const [], hazards: const []);
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    for (var i = 0; i < 1000 && game.round == 1; i++) {
      clock.frame(session, 16);
    }
    expect(game.round, 2);
    expect(game.phase, ArenaPhase.playing);
    // The new round's first step records its start.
    clock.frame(session, 16);
    clock.frame(session, 16);
    expect(clock.host.records.where((r) => r.name == 'round_start'), hasLength(2));
    expect(clock.host.records.where((r) => r.name == 'round_end'), hasLength(1));
    session.dispose();
  });

  test('a resize reaches the rules', () {
    final clock = Clock();
    final game = ArenaGame();
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    session.resize(const Size(1280, 720));
    expect(game.size, const Size(1280, 720));
    session.dispose();
  });

  test('frames carry the host players roster, with their names', () {
    final clock = Clock()..host.hasViewers = true;
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1, nickname: 'Phone a'))
      ..setPlayer(const GamePlayer(id: 'b', number: 2));
    final session = ArenaSession(host: clock.host, onEvent: (_) {});
    clock.frame(session, 100);
    expect(clock.host.frames.first.roster, {'a': (number: 1, name: 'Phone a'), 'b': (number: 2, name: '')});
    session.dispose();
  });

  test('an abandoned round ends without a winner, with its frames, and the view abandoned', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(walls: const [], hazards: const []);
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    for (var i = 0; i < 10; i++) {
      clock.frame(session, 16);
    }
    expect(game.phase, ArenaPhase.playing);
    expect(clock.host.records.where((r) => r.name == 'round_start'), hasLength(1));

    session.abandon();
    final end = clock.host.records.singleWhere((r) => r.name == 'round_end');
    expect(end.playerId, isNull);
    expect(end.data, {'reason': ViewEndReason.abandoned});
    // The frames the round drew, as leaving the screen records them.
    expect(clock.host.records.last.name, 'frames');
    expect(clock.host.records.last.data['drawn'], session.frameCount);
    expect(clock.host.viewEnds.single.reason, ViewEndReason.abandoned);

    // Nothing runs after it: a later dispose records nothing more.
    final names = clock.host.records.map((r) => r.name).toList();
    clock.frame(session, 16);
    session.dispose();
    expect(clock.host.records.map((r) => r.name), names);
    expect(clock.host.viewEnds, hasLength(1));
  });

  test('the session ends as quit, and a won round does not end it', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(walls: const [], hazards: const []);
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      clock.frame(session, 16);
    }
    expect(clock.host.viewEnds, isEmpty, reason: 'a won round is not the end of the session');
    session.dispose(finished: true);
    expect(clock.host.viewEnds.single.reason, ViewEndReason.quit);
    session.dispose();
    expect(clock.host.viewEnds, hasLength(1));
  });
}
