import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

/// A big field, so a piece's pixels are easy to read: the shorter side is 500
/// and a marble 16 across.
const _size = Size(1000, 500);
const _dt = 1 / 60;
const _marbleRadius = ArenaFieldRules.playerRadius * 500;

/// A field of [map] with one marble, put at [at] px.
ArenaFieldRules _field(ArenaMap map, Offset at) {
  final field = ArenaFieldRules(map: map, size: _size)..join('a');
  field.player('a')!.place(at);
  return field;
}

/// Steps [field] [frames] times with a marble holding [move], its A pressed
/// on the first frame when [dash], and returns every event it caused.
List<GameEvent> _steps(ArenaFieldRules field, int frames, {Offset move = Offset.zero, bool dash = false}) {
  final events = <GameEvent>[];
  for (var i = 0; i < frames; i++) {
    field.advanceTime(_dt);
    field.stepMarble(field.player('a')!, _dt, GameInput(move: move, dash: dash && i == 0), events);
  }
  return events;
}

void main() {
  test('a spring launches a marble back faster than it came, with a bump', () {
    final map = testMap(springs: const [SpringSpec(Offset(0.5, 0.5))]);
    final field = _field(map, const Offset(430, 250));
    final events = [..._steps(field, 10, move: const Offset(1, 0)), ..._steps(field, 20)];

    final spring = events.singleWhere((e) => e.cause == GameEventCause.spring);
    expect(spring.soundName, ArenaSounds.bump);
    expect(spring.event?.name, 'hit');
    expect(field.player('a')!.position.dx, lessThan(430), reason: 'thrown back past where it started');
    // It never enters the spring: a marble's centre stays a marble and a
    // spring's radius away from the spring's middle.
    final gap = (field.player('a')!.position - const Offset(500, 250)).distance;
    expect(gap, greaterThanOrEqualTo((springRadius + ArenaFieldRules.playerRadius) * 500 - 0.5));
    expect(events.where((e) => e.cause == GameEventCause.hazard), isEmpty);
  });

  test('a bouncy wall sends a marble back faster, and a plain wall stops it', () {
    const wall = [Offset(0.6, 0), Offset(0.6, 1)];
    final bouncy = _field(
      testMap(walls: const [WallSpec(Offset(0.6, 0), Offset(0.6, 1), bouncy: true)]),
      const Offset(400, 250),
    );
    final thrown = [..._steps(bouncy, 20, move: const Offset(1, 0), dash: true), ..._steps(bouncy, 20)];
    expect(thrown.map((e) => e.cause), contains(GameEventCause.spring));
    expect(bouncy.player('a')!.position.dx, lessThan(500), reason: 'a dash into a slingshot comes back');

    final plain = _field(testMap(walls: const [WallSpec(Offset(0.6, 0), Offset(0.6, 1))]), const Offset(400, 250));
    _steps(plain, 40, move: const Offset(1, 0), dash: true);
    expect(plain.player('a')!.position.dx, closeTo(575.25, 1), reason: 'a plain wall holds it');
    expect(wall, isNotEmpty);
  });

  test('a post is solid: a marble walks up to it and stops', () {
    final field = _field(testMap(posts: const [PostSpec(Offset(0.5, 0.5))]), Offset(300, 250));
    final events = _steps(field, 180, move: const Offset(1, 0));
    expect(field.player('a')!.position.dx, closeTo(500 - postRadius * 500 - _marbleRadius, 1));
    expect(field.player('a')!.position.dy, closeTo(250, 1e-6));
    expect(events.where((e) => e.cause == GameEventCause.hazard), isEmpty);
  });

  test('a belt carries a marble along at half its speed, toward its end', () {
    final right = _field(testMap(belts: const [BeltSpec(Offset(0.2, 0.5), Offset(0.8, 0.5))]), const Offset(300, 250));
    _steps(right, 60);
    expect(
      right.player('a')!.position,
      offsetMoreOrLessEquals(const Offset(300 + 137.5, 250), epsilon: 1),
      reason: 'a second at half a marble\'s walking speed',
    );

    final left = _field(testMap(belts: const [BeltSpec(Offset(0.8, 0.5), Offset(0.2, 0.5))]), const Offset(700, 250));
    _steps(left, 60);
    expect(left.player('a')!.position.dx, closeTo(700 - 137.5, 1), reason: 'the arrows say which way');
  });

  test('a still hazard sends a marble back to its start', () {
    final field = _field(testMap(hazards: const [HazardSpec.still(Offset(0.5, 0.5))]), const Offset(400, 250));
    final events = _steps(field, 20, move: const Offset(1, 0));
    expect(events.where((e) => e.cause == GameEventCause.hazard), hasLength(1));
    expect(field.player('a')!.position.dx, lessThan(100), reason: 'back at the race\'s start, 70 px in');
    expect(field.player('a')!.position.dy, closeTo(250, 1e-6));
    expect(field.player('a')!.hits, 1);
  });

  test('a mover moves on the clock, and a marble never ends a step inside it', () {
    const mover = MoverSpec.slide(Offset(0.5, 0.2), Offset(0.5, 0.8), length: 0.3, deg: 0, periodS: 2);
    final field = _field(testMap(movers: const [mover]), const Offset(500, 250));
    final atStart = field.moverBars.single;
    expect(atStart.$2 - atStart.$1, offsetMoreOrLessEquals(const Offset(150, 0), epsilon: 0.01));

    final marble = field.player('a')!;
    var atHalf = atStart;
    for (var i = 0; i < 120; i++) {
      field.advanceTime(_dt);
      field.stepMarble(marble, _dt, GameInput.none, <GameEvent>[]);
      for (final (a, b) in field.moverBars) {
        final nearest = nearestOnLine(marble.position, a, b);
        expect(
          (marble.position - nearest).distance,
          greaterThanOrEqualTo(ArenaFieldRules.playerRadius * 500 + ArenaFieldRules.wallThickness * 500 / 2 - 0.5),
          reason: 'frame $i: the bar pushes it out',
        );
      }
      if (i == 59) atHalf = field.moverBars.single;
    }
    expect(atHalf, isNot(atStart), reason: 'half of its 2 s cycle: the bar travelled');
    expect(field.moverBars.single, atStart, reason: 'a whole cycle: back where it started');
    expect(marble.position.dy, isNot(closeTo(250, 1)), reason: 'the bar pushed the marble off its line');
  });
}
