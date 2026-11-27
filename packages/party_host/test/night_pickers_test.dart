import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_pickers.dart';
import 'package:party_host/src/night/variant.dart';
import 'package:puzzle_game/puzzle_game.dart';

const _shapeEasy = Variant(game: VariantGame.shapeRace, tier: Level.easy);
const _shapeHard = Variant(game: VariantGame.shapeRace, tier: Level.hard);
const _bumperPinball = Variant(game: VariantGame.bumperRound, tier: Level.medium, mapId: 'pinball');
const _arenaPlayroom = Variant(game: VariantGame.arenaRace, tier: Level.easy, mapId: 'playroom');
const _pool = [_shapeEasy, _shapeHard, _bumperPinball, _arenaPlayroom];

void main() {
  group('ShufflePicker', () {
    const picker = ShufflePicker();

    test('draws every pool variant once before any repeats', () {
      final random = Random(7);
      final played = <Variant>[];
      for (var draw = 0; draw < _pool.length; draw++) {
        final next = picker.next(pool: _pool, played: played, random: random);
        if (next == null) fail('no pick');
        expect(played, isNot(contains(next)), reason: 'draw $draw repeated a variant');
        played.add(next);
      }
      expect(played.toSet(), _pool.toSet());
    });

    test('ten draws in a row never repeat a variant until all four were played', () {
      final random = Random(7);
      final played = <Variant>[];
      for (var draw = 0; draw < 10; draw++) {
        final next = picker.next(pool: _pool, played: played, random: random);
        if (next == null) fail('no pick');
        if (played.toSet().length < _pool.length) {
          expect(played, isNot(contains(next)), reason: 'draw $draw repeated before all four were played');
        }
        played.add(next);
      }
      expect(played.take(_pool.length).toSet(), _pool.toSet());
    });

    test('after a full pass never repeats the variant just played', () {
      final random = Random(7);
      final played = <Variant>[..._pool];
      for (var draw = 0; draw < 10; draw++) {
        final next = picker.next(pool: _pool, played: played, random: random);
        if (next == null) fail('no pick');
        expect(next, isNot(played.last), reason: 'draw $draw repeated the last variant');
        played.add(next);
      }
    });

    test('a one-variant pool returns that variant even when it was the last played', () {
      final next = picker.next(pool: const [_shapeEasy], played: const [_shapeEasy], random: Random(7));
      expect(next, _shapeEasy);
    });

    test('an empty pool gives null', () {
      expect(picker.next(pool: const [], played: const [], random: Random(7)), isNull);
    });

    test('the same seed gives the same draws', () {
      Iterable<Variant?> draws(int seed) {
        final random = Random(seed);
        final played = <Variant>[];
        return List<Variant?>.generate(8, (_) {
          final next = picker.next(pool: _pool, played: played, random: random);
          if (next == null) fail('no pick');
          played.add(next);
          return next;
        });
      }

      expect(draws(7).toList(), draws(7).toList());
    });
  });

  group('PlaylistPicker', () {
    const order = [_shapeEasy, _bumperPinball, _arenaPlayroom];

    test('follows the host order round by round', () {
      const picker = PlaylistPicker(order: order);
      expect(picker.next(0), _shapeEasy);
      expect(picker.next(1), _bumperPinball);
      expect(picker.next(2), _arenaPlayroom);
    });

    test('repeats from the start when the night is longer than the playlist', () {
      const picker = PlaylistPicker(order: order);
      expect(picker.next(3), _shapeEasy);
      expect(picker.next(4), _bumperPinball);
    });

    test('an empty order gives null', () {
      expect(const PlaylistPicker(order: []).next(0), isNull);
    });
  });

  group('RotatingChooser', () {
    const chooser = RotatingChooser();
    const players = ['p1', 'p2', 'p3'];

    test('walks the players in order and wraps back to the first', () {
      expect(chooser.next(playerIds: players), 'p1');
      expect(chooser.next(playerIds: players, lastChooser: 'p1'), 'p2');
      expect(chooser.next(playerIds: players, lastChooser: 'p2'), 'p3');
      expect(chooser.next(playerIds: players, lastChooser: 'p3'), 'p1');
    });

    test('skips a player who left the list', () {
      expect(chooser.next(playerIds: const ['p1', 'p3'], lastChooser: 'p1'), 'p3');
    });

    test('an unknown last chooser gives the first player', () {
      expect(chooser.next(playerIds: const ['p1', 'p3'], lastChooser: 'p2'), 'p1');
    });

    test('one player is always the chooser', () {
      expect(chooser.next(playerIds: const ['p1'], lastChooser: 'p1'), 'p1');
    });

    test('an empty list gives null', () {
      expect(chooser.next(playerIds: const []), isNull);
    });
  });
}
