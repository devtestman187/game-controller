import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

const none = GamepadState(mode: InputMode.dpad);
const pressA = GamepadState(buttons: {GamepadButton.a}, mode: InputMode.dpad);

/// One step of the rules' fixed step, a sixtieth of a second.
const stepS = 1 / 60;

/// A Medium puzzle of two squares whose outlines are 40 units apart, four
/// times the drop's tolerance from each other: one snap leaves a piece still
/// to place, so a round goes on after it.
Puzzle pair() => Puzzle.parse('''
{"id": "pair", "name": "Pair", "level": "medium", "pieces": [
  {"id": "left", "shape": {"rect": [10, 10]}, "color": "#FF0000", "at": [20, 20]},
  {"id": "right", "shape": {"rect": [10, 10]}, "color": "#00FF00", "at": [60, 20]}
]}''');

/// The Medium puzzle of the host's own library, for a race.
Puzzle house() => Puzzle.parse(File('puzzles/house.json').readAsStringSync());

/// Where the tests hold the left square: far from its own outline and from the
/// right one's (44.7 and 20 units).
const away = Offset(60, 40);

/// The grab a dot takes a 10 x 10 square up by from its left side, within the
/// pickup reach (carry_test takes it the same way).
const grab = Offset(-(5 + PuzzleGame.pickupReach * 0.9), 0);

/// A press of A on the game p1 plays.
List<PuzzleEvent> tapA(PuzzleGame g) => [
  ...g.update(stepS, const {'p1': pressA}),
  ...g.update(stepS, const {'p1': none}),
];

/// [frames] steps of a sixtieth of a second with p1 standing still.
void drive(PuzzleGame g, {int frames = 1}) {
  for (var i = 0; i < frames; i++) {
    g.update(stepS, const {'p1': none});
  }
}

/// One player on the pair, holding the left square at [at]: taken from its
/// side, as carry_test takes a piece.
PuzzleGame holding({Offset at = away}) {
  final g = PuzzleGame(pair(), random: Random(1));
  g.update(stepS, const {'p1': none}, numbers: const {'p1': 1});
  g.pieces[0]
    ..pos = at
    ..state = PieceState.loose;
  g.player('p1')!.pos = at + grab;
  tapA(g);
  expect(g.player('p1')!.held, 0, reason: 'the square is taken from its side');
  return g;
}

/// The held square brought into its own outline, turned as the outline is.
void overItsOutline(PuzzleGame g) {
  g.pieces[0]
    ..pos = g.targetAt(0)
    ..angle = g.puzzle.pieces[0].targetAngle;
}

/// The host clock and the Ticker's elapsed time, both moved by the test.
final class Clock {
  int nowMs = 0;
  Duration elapsed = Duration.zero;
  late final MemoryGameHost host = MemoryGameHost(now: () => nowMs);

  /// One drawn frame, [ms] after the last.
  void frame(PuzzleSession session, int ms) {
    nowMs += ms;
    elapsed += Duration(milliseconds: ms);
    session.advance(elapsed);
  }
}

/// A session of the pair with one player on it.
PuzzleSession sessionFor(Clock clock) {
  clock.host
    ..setPlayer(const GamePlayer(id: 'p1', number: 1, nickname: 'Phone p1'))
    ..setGamepad('p1', const GamepadState(mode: InputMode.dpad));
  return PuzzleSession(
    host: clock.host,
    puzzle: pair(),
    teams: const {'p1': PuzzleSide.left},
    random: Random(1),
    playtest: () => PuzzleSettings.defaults,
  );
}

/// Every piece in its place, as the rules see it: the next step finishes.
void placeEverything(PuzzleMatch match) {
  final game = match.sides.first.game;
  for (var i = 0; i < game.pieces.length; i++) {
    game.pieces[i]
      ..state = PieceState.locked
      ..pos = game.targetAt(i)
      ..angle = game.puzzle.pieces[i].targetAngle;
  }
}

void main() {
  test('60 steps of a sixtieth holding a piece away from its outline are a second of moving', () {
    final g = holding();
    final p = g.player('p1')!;
    final moving = p.moveS(g.elapsedS);
    drive(g, frames: 60);
    expect(p.placeS, 0, reason: 'no outline was within the drop tolerance');
    expect(p.moveS(g.elapsedS) - moving, closeTo(1.0, 1e-9), reason: '60 steps of 1/60 s');
    expect(p.moveS(g.elapsedS) + p.placeS, closeTo(g.elapsedS, 1e-9), reason: 'the two sum to the clock');
  });

  test('30 steps over the outline are half a second of placing', () {
    final g = holding();
    final p = g.player('p1')!;
    overItsOutline(g);
    final moving = p.moveS(g.elapsedS);
    drive(g, frames: 30);
    expect(p.placeS, closeTo(0.5, 1e-9), reason: '30 steps of 1/60 s');
    expect(p.moveS(g.elapsedS), closeTo(moving, 1e-9), reason: 'a step at the outline is placing, not moving');
  });

  test('walking with empty hands is moving', () {
    final g = PuzzleGame(pair(), random: Random(1));
    g.update(stepS, const {'p1': none}, numbers: const {'p1': 1});
    final p = g.player('p1')!;
    final moving = p.moveS(g.elapsedS);
    drive(g, frames: 60);
    expect(p.held, isNull);
    expect(p.placeS, 0);
    expect(p.moveS(g.elapsedS) - moving, closeTo(1.0, 1e-9), reason: '60 steps of 1/60 s');
  });

  test('a snap adds no time to either number', () {
    final g = holding();
    final p = g.player('p1')!;
    overItsOutline(g);
    drive(g, frames: 30);
    tapA(g);
    expect(g.pieces[0].state, PieceState.locked, reason: 'the drop is in its outline');
    final placing = p.placeS;
    final moving = p.moveS(g.elapsedS);
    drive(g, frames: 60);
    expect(p.placeS, placing, reason: 'a placed piece is no longer held: no placing time');
    expect(p.moveS(g.elapsedS) - moving, closeTo(1.0, 1e-9), reason: 'the rest of the round is moving');
  });

  test('a race side that finishes at 40 s has moving and placing fill its 40', () {
    final match = PuzzleMatch(house(), teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right}, random: Random(1));
    const inputs = {'p1': none, 'p2': none};
    // 799 steps of a twentieth of a second, then the last one: the side
    // finishes on the 800th step, at 40 s.
    for (var i = 0; i < 799; i++) {
      match.update(0.05, inputs);
    }
    final left = match.gameOf(PuzzleSide.left);
    for (var i = 0; i < left.pieces.length; i++) {
      left.pieces[i]
        ..state = PieceState.locked
        ..pos = left.targetAt(i)
        ..angle = left.puzzle.pieces[i].targetAngle;
    }
    match.update(0.05, inputs);
    expect(left.phase, PuzzlePhase.finished);
    expect(left.elapsedS, closeTo(40, 1e-9), reason: '799 + 1 steps of 0.05 s');
    for (final p in left.players) {
      expect(p.moveS(left.elapsedS) + p.placeS, closeTo(40, 1e-9), reason: 'the clock of the side it played for');
    }
  });

  test('the round reports each player\'s moving and placing time, and its level', () {
    final clock = Clock();
    final session = sessionFor(clock);
    final game = session.match.sides.first.game;
    for (var i = 0; i < 10; i++) {
      clock.frame(session, 100);
    }
    expect(game.elapsedS, closeTo(1.0, 1e-6), reason: '10 frames of 100 ms, in steps of 1/60 s');
    placeEverything(session.match);
    clock.frame(session, 100);
    expect(game.phase, PuzzlePhase.finished);
    final record = clock.host.records.firstWhere((r) => r.name == 'player_result');
    expect(record.data['moveS'], isA<num>());
    expect(record.data['placeS'], isA<num>());
    expect(record.data['placeS'], 0, reason: 'nothing was held');
    expect(record.data['moveS'], closeTo(game.elapsedS, 0.05), reason: 'the whole clock was moving');
    final end = clock.host.records.firstWhere((r) => r.name == 'round_end');
    expect(end.data['tags'], contains('level_medium'));
    session.dispose();
  });
}
