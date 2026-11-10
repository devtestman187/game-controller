import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

/// The field these tests draw in, and a mover on it that travels across the
/// middle, so its ends are easy to read.
const _size = Size(1000, 500);
const _mover = MoverSpec.slide(Offset(0.2, 0.5), Offset(0.8, 0.5), length: 0.2, deg: 90, periodS: 2);

ArenaMap _map() => testMap(
  theme: 'tops',
  movers: const [_mover],
  springs: const [SpringSpec(Offset(0.3, 0.3))],
  posts: const [PostSpec(Offset(0.6, 0.2))],
  belts: const [BeltSpec(Offset(0.2, 0.8), Offset(0.8, 0.8))],
  decor: const [DecorSpec(DecorKind.gear, Offset(0.1, 0.1))],
);

void main() {
  test('a frame carries the pieces and the movers\' ends, and says when the field is mirrored', () {
    final game = ArenaGame(map: _map(), size: _size)..join('a');
    final json = game.snapshot().toJson();
    expect(json['mv'], [
      [0.2, 0.4, 0.2, 0.6],
    ], reason: 'a slide starts where its map puts it: 0.2 across, a bar 0.2 long down the field');
    expect(json['sp'], [
      [0.3, 0.3],
    ], reason: 'a spring is a point, with the radius its kind defaults to');
    expect(json['po'], [
      [0.6, 0.2],
    ]);
    expect(json['bl'], [
      [0.2, 0.8, 0.8, 0.8],
    ]);
    expect(json['dc'], [
      [DecorKind.gear.index, 0.1, 0.1],
    ], reason: 'decor is a kind by its number, then its spot');
    expect(json['th'], 'tops');
    expect(json.containsKey('mi'), isFalse, reason: 'a round that doesn\'t swap sides says nothing');
  });

  test('a mirrored round says so, and its movers come mirrored too', () {
    final game = ArenaGame(map: _map(), size: _size)
      ..join('a')
      ..mirrored = true;
    final json = game.snapshot().toJson();
    expect(json['mi'], 1);
    expect(json['mv'], [
      [0.8, 0.4, 0.8, 0.6],
    ]);
  });

  test('the Playroom\'s frame carries none of them, so it is the frame it always was', () {
    final json = ArenaGame(size: _size).snapshot().toJson();
    expect([
      for (final key in ['mv', 'mi', 'th', 'sp', 'po', 'bl', 'dc']) json.containsKey(key),
    ], everyElement(isFalse));
  });

  test('a frame\'s movers survive the wire, and lerp between frames', () {
    final game = ArenaGame(map: _map(), size: _size)..join('a');
    final first = game.snapshot();
    game.update(1 / 60, {'a': GameInput.none});
    for (var i = 1; i < 30; i++) {
      game.update(1 / 60, {'a': GameInput.none});
    }
    final second = game.snapshot();
    expect(second.movers.single.$1, isNot(first.movers.single.$1), reason: 'half a second of travel');

    final decoded = ArenaSnapshot.decode(second.encode());
    expect(decoded.movers.single.$1.dx, closeTo(second.movers.single.$1.dx, 1e-4));
    expect(decoded.movers.single.$2.dy, closeTo(second.movers.single.$2.dy, 1e-4));
    expect(decoded.mirrored, second.mirrored);
    expect(decoded.theme, second.theme);
    expect(decoded.springs.single, second.springs.single);
    expect(decoded.posts.single, second.posts.single);
    expect(decoded.belts.single, second.belts.single);
    expect(decoded.decor.single, second.decor.single);

    final half = first.lerpTo(second, 0.5);
    expect(half.movers.single.$1.dx, closeTo((first.movers.single.$1.dx + second.movers.single.$1.dx) / 2, 1e-9));
    expect(half.springs, first.springs, reason: 'a piece fixed to the floor does not move between frames');
  });
}
