import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/scene.dart';

/// The scenes in `tools/demo/scenes/` and the parser's rejections
/// (docs/demo-video-runbook.md 2.3).
void main() {
  final dir = Directory('../tools/demo/scenes');

  test('every scene file parses, and no seat has an empty goal list', () {
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files, isNotEmpty, reason: 'no scene files in ${dir.path}');
    for (final file in files) {
      final scene = Scene.fromFile(file.path);
      expect(scene.seats, isNotEmpty, reason: file.path);
      for (final MapEntry(key: id, value: seat) in scene.seats.entries) {
        expect(seat.goals, isNotEmpty, reason: '$id in ${file.path}');
        expect(seat.via, anyOf('phone', 'bot'));
      }
    }
  });

  test('race.json says what the runbook describes', () {
    final scene = Scene.fromFile('../tools/demo/scenes/race.json');
    expect(scene.game, 'puzzle');
    expect(scene.puzzle, 'rocket');
    expect(scene.seed, 4242);
    expect(scene.teams['left'], ['P1', 'Bot 2']);
    expect(scene.teams['right'], ['Bot 3', 'Bot 4']);
    expect(scene.sideOf('Bot 3'), 'right');
    expect(scene.phoneSeat, 'P1');
    expect(scene.seats['P1']!.via, 'phone');
    expect(scene.pace['left'], 52000);
    expect(scene.endAfter, 'results');
    // The storyboard needs a wrong drop.
    expect(scene.seats['Bot 3']!.goals.map((g) => g.kind), contains(GoalKind.wrongDrop));
  });

  test('the arena takes wander instead of racing for the goal', () {
    for (final name in ['arena_gyro.json', 'arena_sticks.json']) {
      final scene = Scene.fromFile('../tools/demo/scenes/$name');
      expect(scene.game, 'arena');
      expect(scene.wander, isTrue, reason: '$name: a won round freezes the picture for the ~2 s break');
    }
    // M1's accepted take 12 is the goal-seeking D-pad shot and stays as it is.
    expect(Scene.fromFile('../tools/demo/scenes/arena_dpad.json').wander, isFalse);
  });

  test('join_race.json is a join pre-roll: four seats, then the match starts', () {
    final scene = Scene.fromFile('../tools/demo/scenes/join_race.json');
    expect(scene.screenStart, 'join');
    expect(scene.endAfter, 'game_start');
    expect(scene.join, isNotNull);
    // The natural side order: the first and third to join go left, so this
    // order gives the 2 vs 2 the race scene expects.
    expect(scene.join!.order, ['P1', 'Bot 3', 'Bot 2', 'Bot 4']);
    expect(scene.join!.startSeat, 'P1');
    expect(scene.teams['left'], ['P1', 'Bot 2']);
    expect(scene.teams['right'], ['Bot 3', 'Bot 4']);
  });

  test('a layout goal switches the phone mode mid-scene', () {
    final scene = Scene.parse(
      '{"game":"puzzle","seats":{"P1":{"via":"phone","goals":['
      '{"navigate":["a"]},{"waitFor":"game_start"},{"layout":"sticks"},{"idle":2000}]}}}',
      source: 'test',
    );
    final goals = scene.seats['P1']!.goals;
    expect(goals.map((g) => g.kind), [GoalKind.navigate, GoalKind.waitFor, GoalKind.layout, GoalKind.idle]);
    expect(goals[2].mode, 'sticks');
  });

  test('R1/R2 (menus.json) and G1/G2 switch to Sticks once the game is up', () {
    // The menus and the join screen only allow the D-pad, so the switch has to
    // come after `game_start`, not at the start of the scene.
    for (final name in ['menus.json', 'join.json', 'race.json']) {
      final scene = Scene.fromFile('../tools/demo/scenes/$name');
      final goals = scene.seats['P1']!.goals;
      final layout = goals.indexWhere((g) => g.kind == GoalKind.layout);
      expect(layout, greaterThanOrEqualTo(0), reason: '$name has no layout goal');
      expect(goals[layout].mode, 'sticks', reason: name);
      if (name == 'race.json') {
        // race.json starts inside a live match, so the switch comes first.
        expect(layout, 0, reason: 'race.json starts in-game');
      } else {
        final wait = goals.indexWhere((g) => g.kind == GoalKind.waitFor && g.event == 'game_start');
        expect(wait, greaterThanOrEqualTo(0), reason: '$name should wait for game_start');
        expect(layout, greaterThan(wait), reason: '$name: switch after game_start');
      }
    }
  });

  group('refuses', () {
    Scene parse(String text) => Scene.parse(text, source: 'test');

    test('an unknown layout mode', () {
      expect(
        () => parse('{"game":"puzzle","seats":{"P1":{"goals":[{"layout":"keyboard"}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unknown mode'))),
      );
    });

    test('wander outside an arena scene', () {
      expect(
        () => parse('{"game":"puzzle","wander":true,"seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('arena only'))),
      );
    });

    test('a join order naming a seat with no script', () {
      expect(
        () => parse('{"game":"puzzle","join":{"order":["P1","P9"]},"seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('P9'))),
      );
    });

    test('a join block with an empty order', () {
      expect(
        () => parse('{"game":"puzzle","join":{"order":[]},"seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('order'))),
      );
    });

    test('a join start naming a seat with no script', () {
      expect(
        () => parse('{"game":"puzzle","join":{"order":["P1"],"start":"P9"},"seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('P9'))),
      );
    });

    test('an unknown goal, naming it and the seat', () {
      expect(
        () => parse('{"game":"puzzle","seats":{"P1":{"goals":[{"fly":1}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unknown goal "fly"'))),
      );
    });

    test('a goal with two keys', () {
      expect(
        () => parse('{"game":"puzzle","seats":{"P1":{"goals":[{"pair":1,"bogus":2}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('one key'))),
      );
    });

    test('an unknown game', () {
      expect(
        () => parse('{"game":"pong","seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unknown game'))),
      );
    });

    test('an unknown endAfter', () {
      expect(
        () => parse('{"game":"puzzle","endAfter":"tea","seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('endAfter'))),
      );
    });

    test('a team that names a seat with no script', () {
      expect(
        () => parse('{"game":"puzzle","teams":{"left":["P9"]},"seats":{"P1":{"goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('P9'))),
      );
    });

    test('an unknown via', () {
      expect(
        () => parse('{"game":"puzzle","seats":{"P1":{"via":"magic","goals":[{"place":{}}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('via'))),
      );
    });

    test('an unknown navigate press', () {
      expect(
        () => parse('{"game":"puzzle","seats":{"P1":{"goals":[{"navigate":["jump"]}]}}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('jump'))),
      );
    });

    test('bad JSON', () {
      expect(() => parse('{nope'), throwsA(isA<FormatException>()));
    });
  });
}
