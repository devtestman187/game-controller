import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:tvtest/src/demo/puzzle_brain.dart';
import 'package:tvtest/src/demo/scene.dart';

/// The puzzle brain on the real game rules (docs/demo-video-runbook.md 2.3,
/// and G2's story: "6 snaps and 1 wrong"). Ran through a [MemoryGameHost] like
/// a real controller, at the game's own world scale, so the distances are the
/// same as on the TV.
void main() {
  /// Runs [goals] for seat P1 on the rocket and returns the game's events.
  List<PuzzleEventKind> run(List<Map<String, Object?>> goals, {int frames = 30 * 60}) {
    final scene = Scene.parse(
      '{"game":"puzzle","seats":{"P1":{"goals":${goals.map((g) => '{"${g.keys.first}":${g.values.first}}').toList()}}}}',
      source: 'test',
    );
    final puzzle = Puzzle.parse(File('../packages/puzzle_game/puzzles/rocket.json').readAsStringSync());
    final match = PuzzleMatch(puzzle, teams: const {'P1': PuzzleSide.left}, settings: PuzzleSettings.defaults);
    final host = MemoryGameHost()
      ..setPlayer(const GamePlayer(id: 'P1', number: 1, nickname: 'P1', mode: InputMode.sticks));
    final brain = PuzzleBrain(seat: 'P1', goals: scene.seats['P1']!.goals, seed: 7);
    final game = match.gameFor('P1')!;
    final kinds = <PuzzleEventKind>[];
    const dt = 1 / 60;
    for (var i = 0; i < frames; i++) {
      host.setGamepad('P1', brain.step(game, dt));
      for (final e in match.update(dt, {'P1': host.gamepad('P1')}, numbers: const {'P1': 1})) {
        kinds.add(e.event.kind);
      }
    }
    return kinds;
  }

  test('wrongDrop puts the piece on the board, the game calls it wrong, then it is placed', () {
    final kinds = run([
      {'wrongDrop': '"left fin"'},
      {'place': '{}'},
    ]);
    final wrong = kinds.indexOf(PuzzleEventKind.wrong);
    expect(wrong, greaterThanOrEqualTo(0), reason: 'no wrong event: $kinds');
    expect(kinds.skip(wrong).contains(PuzzleEventKind.snap), isTrue, reason: 'the wrong drop was never fixed: $kinds');
    // Carrying with A tapped dropped and re-grabbed the piece all the way
    // across the board: 14 pickups for one wrong drop.
    final pickupsBeforeWrong = kinds.take(wrong).where((k) => k == PuzzleEventKind.pickup).length;
    expect(pickupsBeforeWrong, lessThanOrEqualTo(2), reason: 'the piece was re-grabbed on the way: $kinds');
  });

  test('a wrong drop is on the board, not off it', () {
    // Off the board the game drops the piece loose and never turns it red;
    // G2's story check would then have no `wrong` to find.
    final kinds = run([
      {'wrongDrop': '"window"'},
      {'place': '{}'},
    ]);
    expect(kinds, contains(PuzzleEventKind.wrong));
  });

  group('a layout goal', () {
    test('switches the phone mode once, then moves on', () {
      final goals = Scene.parse(
        '{"game":"puzzle","seats":{"P1":{"goals":[{"layout":"sticks"},{"idle":500}]}}}',
        source: 'test',
      ).seats['P1']!.goals;
      final asked = <String>[];
      final events = <String>[];
      final brain = PuzzleBrain(
        seat: 'P1',
        goals: goals,
        seed: 7,
        onLayout: asked.add,
        onEvent: (name, [data]) => events.add(name),
      );
      // On a menu screen (no game object yet) the goal still has to fire: the
      // menus and the join screen are exactly where a scene switches.
      brain.step(null, 1 / 60);
      expect(asked, ['sticks']);
      expect(events, contains('layout'));
      expect(brain.currentGoal, GoalKind.idle);
      brain.step(null, 1 / 60);
      expect(asked, ['sticks'], reason: 'it must switch once, not every frame');
    });

    test('does not take a paced goal\'s share of the scene time', () {
      // race.json switches to Sticks as its very first goal, with a 52 s pace
      // on the left side. Pacing that step would idle for seconds right after
      // game_start and the race would start late.
      final goals = Scene.parse(
        '{"game":"puzzle","seats":{"P1":{"goals":[{"layout":"sticks"},{"idle":100}]}}}',
        source: 'test',
      ).seats['P1']!.goals;
      final brain = PuzzleBrain(seat: 'P1', goals: goals, seed: 7, paceFinishMs: 52000);
      brain.step(null, 1 / 60);
      expect(brain.currentGoal, GoalKind.idle);
      // Both goals are spent within 0.2 s: with the pace wait they would still
      // be waiting ~4.7 s after game_start.
      for (var i = 0; i < 12; i++) {
        brain.step(null, 1 / 60);
      }
      expect(brain.currentGoal, isNull, reason: 'the layout goal took a paced goal\'s share of the scene time');
    });
  });
}
