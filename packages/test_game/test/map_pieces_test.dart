import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// A map file whose own fields are [fields], so one piece can be read on its
/// own: the header, the fields, then the Playroom's race.
String pieceMap(String fields) =>
    '{"id": "x", "name": "X", "line": "A map.", "theme": "playroom", $fields, '
    '"race": {"start": [0.07, 0.5], "goal": [0.86, 0.38, 0.97, 0.62]}}';

ArenaMap parse(String fields) => ArenaMap.parse(pieceMap(fields));

Matcher refuses(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(message)));

void main() {
  test('a map reads its springs, posts, belts, movers and decor', () {
    final map = parse(
      '"springs": [{"at": [0.3, 0.3]}, {"at": [0.4, 0.4], "radius": 0.06}], '
      '"posts": [{"at": [0.5, 0.5]}, {"at": [0.6, 0.5], "radius": 0.07}], '
      '"belts": [{"from": [0.2, 0.6], "to": [0.8, 0.6]}, {"from": [0.2, 0.7], "to": [0.8, 0.7], "width": 0.1}], '
      '"movers": ['
      '{"swing": {"pivot": [0.1, 0.2], "length": 0.25, "fromDeg": -35, "toDeg": 35}, "periodS": 2.5}, '
      '{"spin": {"pivot": [0.2, 0.2], "length": 0.3}, "periodS": 3, "phase": 0.25}, '
      '{"slide": {"from": [0.3, 0.9], "to": [0.7, 0.9], "length": 0.35, "deg": 90}, "periodS": 4}], '
      '"decor": [{"kind": "gear", "at": [0.1, 0.9]}, {"kind": "flag", "at": [0.9, 0.1], "size": 0.12}]',
    );

    expect(map.springs, [const SpringSpec(Offset(0.3, 0.3)), const SpringSpec(Offset(0.4, 0.4), radius: 0.06)]);
    expect(map.posts, [const PostSpec(Offset(0.5, 0.5)), const PostSpec(Offset(0.6, 0.5), radius: 0.07)]);
    expect(map.belts, [
      const BeltSpec(Offset(0.2, 0.6), Offset(0.8, 0.6)),
      const BeltSpec(Offset(0.2, 0.7), Offset(0.8, 0.7), width: 0.1),
    ]);
    expect(map.movers, [
      const MoverSpec.swing(Offset(0.1, 0.2), length: 0.25, fromDeg: -35, toDeg: 35, periodS: 2.5),
      const MoverSpec.spin(Offset(0.2, 0.2), length: 0.3, periodS: 3, phase: 0.25),
      const MoverSpec.slide(Offset(0.3, 0.9), Offset(0.7, 0.9), length: 0.35, deg: 90, periodS: 4),
    ]);
    expect(map.decor, [
      const DecorSpec(DecorKind.gear, Offset(0.1, 0.9)),
      const DecorSpec(DecorKind.flag, Offset(0.9, 0.1), size: 0.12),
    ]);
  });

  test('a piece left as the map writes it takes the look\'s sizes', () {
    final map = parse(
      '"springs": [{"at": [0.3, 0.3]}], "posts": [{"at": [0.5, 0.5]}], '
      '"belts": [{"from": [0.2, 0.6], "to": [0.8, 0.6]}], "decor": [{"kind": "light", "at": [0.9, 0.9]}]',
    );
    expect(
      [map.springs.single.radius, map.posts.single.radius, map.belts.single.width],
      [springRadius, postRadius, beltWidth],
    );
    expect(map.decor.single.size, decorSize);
    expect(map.decor.single.kind, DecorKind.light);
  });

  test('two pieces are equal when they say the same, so a map round trips', () {
    final first = parse(
      '"belts": [{"from": [0.2, 0.6], "to": [0.8, 0.6]}], "decor": [{"kind": "gear", "at": [0.1, 0.9]}]',
    );
    final second = parse(
      '"belts": [{"from": [0.2, 0.6], "to": [0.8, 0.6]}], "decor": [{"kind": "gear", "at": [0.1, 0.9]}]',
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.belts.single, const BeltSpec(Offset(0.2, 0.6), Offset(0.8, 0.6)));
    expect(first.belts.single, isNot(const BeltSpec(Offset(0.2, 0.6), Offset(0.8, 0.7))));
  });

  test('a bouncy wall and a still hazard read as the map writes them', () {
    final map = parse(
      '"walls": [{"from": [0.2, 0.2], "to": [0.2, 0.8], "bouncy": true}, '
      '{"from": [0.4, 0.2], "to": [0.4, 0.8]}], '
      '"hazards": [{"still": {"at": [0.5, 0.5]}}, {"slide": {"from": [0.6, 0.2], "to": [0.6, 0.8]}, "periodS": 3}]',
    );
    expect([for (final wall in map.walls) wall.bouncy], [true, false]);
    expect(map.hazards.first.isStill, isTrue);
    expect(map.hazards.first.at(1.7, mapFieldSize), const Offset(0.5, 0.5), reason: 'a still hazard never moves');
    expect(map.hazards.last.isStill, isFalse);
  });

  test('a mover\'s ends follow the clock', () {
    const field = mapFieldSize;
    const swing = MoverSpec.swing(Offset(0.5, 0.5), length: 0.2, fromDeg: 0, toDeg: 90, periodS: 2);
    // 0.2 of the shorter side is 18 units of the map's 90: across and down the
    // field the same distance.
    final (pivot, end) = swing.endsAt(0, field);
    expect(pivot, const Offset(0.5, 0.5));
    expect(end.dx, closeTo(0.5 + 18 / 160, 1e-9));
    expect(end.dy, closeTo(0.5, 1e-9));
    final (_, down) = swing.endsAt(1, field);
    expect(down.dy, closeTo(0.5 + 18 / 90, 1e-9), reason: 'half a cycle is the far angle');

    const spin = MoverSpec.spin(Offset(0.5, 0.5), length: 0.2, periodS: 2);
    final (over, under) = spin.endsAt(0.5, field);
    expect(over.dy, closeTo(0.5 - 9 / 90, 1e-9), reason: 'a quarter turn stands the bar down the field');
    expect(under.dy, closeTo(0.5 + 9 / 90, 1e-9));

    const slide = MoverSpec.slide(Offset(0.2, 0.5), Offset(0.8, 0.5), length: 0.1, deg: 90, periodS: 2);
    final (start, _) = slide.endsAt(0, field);
    expect(start.dx, closeTo(0.2, 1e-9), reason: 'a slide starts where its map puts it');
    expect(start.dy, closeTo(0.5 - 4.5 / 90, 1e-9));
    final (end2, _) = slide.endsAt(1, field);
    expect(end2.dx, closeTo(0.8, 1e-9));
    expect(slide.sweep().length, moverSamples);
  });

  test('each piece names a bad field, and the map, the part and the field', () {
    expect(() => parse('"springs": [{"at": [0.3]}]'), refuses('Map "x", spring 0: "at" must be [x, y]'));
    expect(() => parse('"springs": [7]'), refuses('Map "x", spring 0 is not an object'));
    expect(
      () => parse('"springs": [{"at": [0.3, 0.3], "radius": "big"}]'),
      refuses('Map "x", spring 0: "radius" must be a number'),
    );
    expect(() => parse('"posts": [{"at": 3}]'), refuses('Map "x", post 0: "at" must be [x, y]'));
    expect(() => parse('"belts": [{"from": [0.2, 0.6]}]'), refuses('Map "x", belt 0: "to" must be [x, y]'));
    expect(
      () => parse('"belts": [{"from": [0.2, 0.6], "to": [0.8, 0.6], "width": null}]'),
      refuses('Map "x", belt 0: "width" must be a number'),
    );
    expect(() => parse('"decor": [{"kind": "cloud", "at": [0.5, 0.5]}]'), refuses(notADecorKind('cloud')));
    expect(() => parse('"decor": [{"at": [0.5, 0.5]}]'), refuses('Map "x", decor 0: "kind" must be text'));
    expect(
      () => parse('"walls": [{"from": [0.2, 0.2], "to": [0.2, 0.8], "bouncy": "yes"}]'),
      refuses('Map "x", wall 0: "bouncy" must be true or false'),
    );
    expect(() => parse('"hazards": [{"still": [0.5, 0.5]}]'), refuses('Map "x", hazard 0: "still" is not an object'));
    expect(() => parse('"springs": {}'), refuses('Map "x": "springs" must be a list'));
    expect(() => parse('"movers": {}'), refuses('Map "x": "movers" must be a list'));
  });

  test('a mover names the three shapes it comes in, and every field of each', () {
    expect(
      () => parse('"movers": [{"periodS": 3}]'),
      refuses('Map "x", mover 0: needs a "swing" ({pivot, length, fromDeg, toDeg})'),
    );
    expect(
      () => parse('"movers": [{"spin": {"pivot": [0.5, 0.5]}, "periodS": 3}]'),
      refuses('"length" must be a number'),
    );
    expect(
      () => parse('"movers": [{"swing": {"pivot": [0.5, 0.5], "length": 0.2}, "toDeg": 30, "periodS": 3}]'),
      refuses('Map "x", mover 0: "fromDeg" must be a number'),
    );
    expect(
      () => parse('"movers": [{"slide": {"from": [0.2, 0.5], "to": [0.8, 0.5], "length": 0.2}, "periodS": 3}]'),
      refuses('Map "x", mover 0: "deg" must be a number'),
    );
    expect(
      () => parse('"movers": [{"slide": 7, "periodS": 3}]'),
      refuses('Map "x", mover 0: "slide" is not an object'),
    );
    expect(
      () => parse('"movers": [{"spin": {"pivot": [0.5, 0.5], "length": 0.2}}]'),
      refuses('"periodS" must be a number'),
    );
  });

  test('a theme a build has not got is refused, and the five it has are the floors', () {
    expect(mapThemes, ['playroom', 'pinball', 'castle', 'factory', 'tops']);
    expect(notATheme('space'), '"space" is not a theme: use playroom, pinball, castle, factory or tops');
  });

  test('the playroom has no pieces, so it plays as it always has', () {
    expect([
      ArenaMap.playroom.springs,
      ArenaMap.playroom.posts,
      ArenaMap.playroom.belts,
      ArenaMap.playroom.movers,
    ], everyElement(isEmpty));
    expect(ArenaMap.playroom.walls.every((wall) => !wall.bouncy), isTrue);
    expect(ArenaMap.playroom.hazards.every((hazard) => !hazard.isStill), isTrue);
    expect(ArenaMap.playroom.decor, isEmpty);
  });
}
