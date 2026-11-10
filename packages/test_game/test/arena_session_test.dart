import 'dart:math';
import 'dart:ui';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
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

void main() {
  test('a round records one start, one end and one frame count, timed by the step it was won on', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1, nickname: 'Phone a'))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(map: testMap());
    final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      clock.frame(session, 16);
    }
    expect(game.phase, ArenaPhase.won);

    final names = clock.host.records.map((r) => r.name).toList();
    expect(names.where((n) => n == 'round_start'), hasLength(1));
    expect(names.where((n) => n == 'round_end'), hasLength(1));
    expect(names.where((n) => n == 'frames'), hasLength(1));
    expect(
      clock.host.records.firstWhere((r) => r.name == 'round_start').data['hz'],
      HostingSettings.defaults.frameRateHz,
      reason: 'the round ran at the default rate',
    );
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

  test('the round is reported at the rate the host settings ask for', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(map: testMap());
    final session = ArenaSession(
      host: clock.host,
      game: game,
      onEvent: (_) {},
      settings: const HostingSettings(frameRateHz: 20),
    );
    for (var i = 0; i < 10; i++) {
      clock.frame(session, 16);
    }
    expect(clock.host.records.firstWhere((r) => r.name == 'round_start').data['hz'], 20);
    session.dispose();
  });

  test('the round break starts a new round, with its own start record', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(map: testMap());
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
    final game = ArenaGame(map: testMap());
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

  group('the phones’ buttons', () {
    test('the Arena labels A Dash and Start Pause', () {
      expect(arenaLayout.labels, {ControllerButton.a: 'Dash', ControllerButton.start: 'Pause'});
      expect(arenaLayout.labels[ControllerButton.a], arenaDashLabel);
    });

    test('the Arena hides every button its rules never read', () {
      final read = buttonsTheRulesRead();
      expect(read, {ControllerButton.a}, reason: 'the rules read A for a dash, and the sticks for moving and aiming');
      // Start is the host's pause (M11), not the rules, so it stays visible.
      expect(arenaLayout.hidden, ControllerButton.values.toSet()..removeAll({...read, ControllerButton.start}));
      expect(arenaLayout.hidden.intersection(arenaLayout.labels.keys.toSet()), isEmpty, reason: 'a label shows');
    });
  });

  group('Robo’s seat', () {
    /// A Bumper Round's map: two starts either side of a coin zone.
    ArenaMap bumperMap() => testMap(
      race: null,
      bumper: BumperSpec(starts: const [Offset(0.1, 0.3), Offset(0.9, 0.7)], coins: const [centerZone]),
    );

    /// [count] players joined to [clock]'s host, numbered in order.
    void join(Clock clock, int count) {
      for (var i = 1; i <= count; i++) {
        clock.host.setPlayer(GamePlayer(id: 'p$i', number: i));
      }
    }

    test('a lone player’s Bumper Round gives Robo a marble', () {
      final clock = Clock();
      join(clock, 1);
      final game = ArenaGame(map: bumperMap(), mode: ArenaMode.bumper, random: Random(1));
      final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
      clock.frame(session, 16);
      clock.frame(session, 16);
      expect(game.snapshot().players.map((p) => p.id), contains(roboPlayerId), reason: 'one player, so Robo plays');
      session.dispose();
    });

    test('a race never gives Robo a seat', () {
      final clock = Clock();
      join(clock, 1);
      final game = ArenaGame(map: testMap(), random: Random(1));
      final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
      clock.frame(session, 16);
      expect(game.snapshot().players.map((p) => p.id), isNot(contains(roboPlayerId)));
      session.dispose();
    });

    test('two players leave Robo no seat', () {
      final clock = Clock();
      join(clock, 2);
      final game = ArenaGame(map: bumperMap(), mode: ArenaMode.bumper, random: Random(1));
      final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
      clock.frame(session, 16);
      clock.frame(session, 16);
      expect(game.snapshot().players.map((p) => p.id), isNot(contains(roboPlayerId)));
      session.dispose();
    });

    test('Robo’s play is no player’s: no record and no haptic ever carries its id', () {
      final clock = Clock();
      join(clock, 1);
      final game = ArenaGame(map: bumperMap(), mode: ArenaMode.bumper, random: Random(1));
      final session = ArenaSession(host: clock.host, game: game, onEvent: (_) {});
      for (var i = 0; i < 600; i++) {
        clock.frame(session, 16);
      }
      expect(game.player(roboPlayerId)!.coins, greaterThan(0), reason: 'Robo played, and took coins');
      expect(clock.host.records.every((r) => r.playerId != roboPlayerId), isTrue, reason: 'no stats of Robo’s');
      expect(clock.host.haptics.where((haptic) => haptic.$1 == roboPlayerId), isEmpty, reason: 'Robo has no phone');
      session.dispose();
    });
  });

  test('the session ends as quit, and a won round does not end it', () {
    final clock = Clock();
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1))
      ..setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 1, dx: 1)));
    final game = ArenaGame(map: testMap());
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

/// The buttons the arena's rules read: one held on its own changes what
/// [GameInput.fromGamepad] hands them, as A does for the dash. So a hidden
/// button is one the rules read nowhere, and the test fails the day a rule
/// starts reading a button the phones were told they don't need.
Set<ControllerButton> buttonsTheRulesRead() => {
  for (final b in ControllerButton.values)
    if (!sameInput(
      GameInput.fromGamepad(GamepadState.neutral),
      GameInput.fromGamepad(GamepadState(buttons: {GamepadState.buttonOf(b)})),
    ))
      b,
};

/// Whether two inputs ask the rules for the same move, dash and aim.
bool sameInput(GameInput a, GameInput b) => a.move == b.move && a.dash == b.dash && a.aim == b.aim;
