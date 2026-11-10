import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

void main() {
  test('every piece is inside the field', () {
    final spring = testMap(springs: const [SpringSpec(Offset(1.2, 0.5))]);
    expect(
      onlyMessage(spring, MapRule.field),
      'test/spring 0: it reaches 1.23 across and 0.55 down, outside the field. '
      'Keep every part of the map between 0 and 1, across and down.',
    );

    final belt = testMap(belts: const [BeltSpec(Offset(0.2, 0.5), Offset(1.4, 0.5))]);
    expect(messagesOf(belt, MapRule.field).single, contains('test/belt 0: its end is at 1.40 across'));

    final mover = testMap(
      movers: const [MoverSpec.slide(Offset(0.2, 0.5), Offset(1.3, 0.5), length: 0.2, deg: 90, periodS: 3)],
    );
    expect(messagesOf(mover, MapRule.field).single, contains('test/mover 0: its sweep runs to 1.30 across'));
  });

  test('a spring or a post is clear of every start', () {
    final map = testMap(springs: const [SpringSpec(Offset(0.07, 0.5))]);
    expect(
      onlyMessage(map, MapRule.piece),
      'test/spring 0: it sits on start 0, where a marble begins. Move it clear of every start.',
    );

    final post = testMap(
      posts: const [PostSpec(Offset(0.10, 0.20))],
      race: null,
      bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
    );
    expect(
      onlyMessage(post, MapRule.piece),
      'test/post 0: it sits on bumper start 0, where a marble begins. Move it clear of every start.',
    );
  });

  test('a piece is clear of the coin zones, where the coins appear', () {
    final spring = testMap(
      race: null,
      springs: const [SpringSpec(Offset(0.5, 0.5))],
      bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
    );
    expect(
      onlyMessage(spring, MapRule.piece),
      'test/spring 0: it sits in coin zone 0, where coins appear. Move it clear of the coin zones.',
    );

    final belt = testMap(
      race: null,
      belts: const [BeltSpec(Offset(0.4, 0.5), Offset(0.6, 0.5))],
      bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
    );
    expect(
      onlyMessage(belt, MapRule.piece),
      'test/belt 0: it crosses coin zone 0, where coins appear. Move it clear of the coin zones.',
    );
  });

  test('a mover is clear of the starts and the coin zones', () {
    final start = testMap(movers: const [MoverSpec.spin(Offset(0.07, 0.5), length: 0.1, periodS: 3)]);
    expect(
      onlyMessage(start, MapRule.piece),
      'test/mover 0: its sweep crosses start 0, where a marble begins. Move it clear of every start.',
    );

    final zone = testMap(
      race: null,
      movers: const [MoverSpec.spin(Offset(0.5, 0.5), length: 0.3, periodS: 3)],
      bumper: const BumperSpec(starts: fourStarts, coins: [centerZone]),
    );
    expect(
      onlyMessage(zone, MapRule.piece),
      'test/mover 0: its sweep crosses coin zone 0, where coins appear. Move it clear of the coin zones.',
    );
  });

  test('the limits: 8 springs, 6 belts, no mover faster than one pass every 1.5 s', () {
    final springs = testMap(springs: [for (var i = 0; i < 9; i++) SpringSpec(Offset(0.3 + i * 0.04, 0.9))]);
    expect(onlyMessage(springs, MapRule.limit), 'test: it has 9 springs; a map has at most 8. Remove one.');

    final belts = testMap(
      belts: [for (var i = 0; i < 7; i++) BeltSpec(Offset(0.3 + i * 0.02, 0.9), Offset(0.3 + i * 0.02, 0.96))],
    );
    expect(onlyMessage(belts, MapRule.limit), 'test: it has 7 belts; a map has at most 6. Remove one.');

    final fast = testMap(
      movers: const [MoverSpec.slide(Offset(0.3, 0.9), Offset(0.6, 0.9), length: 0.1, deg: 0, periodS: 1.2)],
    );
    expect(
      onlyMessage(fast, MapRule.limit),
      'test/mover 0: it makes a pass every 1.2 s; the fastest is one every 1.5 s. Make its "periodS" bigger.',
    );
  });

  test('a mover counts as a wall, since it is one that moves', () {
    final map = testMap(
      walls: [for (var i = 0; i < 20; i++) topWall(i)],
      movers: [
        for (var i = 0; i < 5; i++)
          MoverSpec.slide(
            Offset(0.30, 0.60 + i * 0.01),
            Offset(0.34, 0.60 + i * 0.01),
            length: 0.04,
            deg: 90,
            periodS: 3,
          ),
      ],
    );
    expect(
      onlyMessage(map, MapRule.limit),
      'test: it has 20 walls and 5 movers; a wall and a mover both count, and a map has at most 24. '
      'Remove one, or join two into a longer wall.',
    );
  });

  test('a still hazard is not too fast, since it never moves', () {
    expect(checkMap(testMap(hazards: const [HazardSpec.still(Offset(0.3, 0.9))])), isEmpty);
  });
}
