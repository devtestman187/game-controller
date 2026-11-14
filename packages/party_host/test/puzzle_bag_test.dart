import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/puzzle_bag.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Each level's puzzles in the order they play (B-009, design section 2): every
/// puzzle of a level once before any of them comes back, the order kept on the
/// host, and a new puzzle coming before a repeat.
void main() {
  const easy = ['a', 'b', 'c', 'd', 'e', 'f'];
  const medium = ['m1', 'm2', 'm3', 'm4', 'm5', 'm6'];

  /// The host's prefs with [saved] in them, and the bag over them.
  Future<({SharedPreferences prefs, ProviderContainer container})> bagHost([
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    return (prefs: prefs, container: container);
  }

  /// One draw of [level] over [from]: a level with puzzles always draws one.
  String drawOne(PuzzleBagNotifier bag, Level level, {List<String> from = easy, int seed = 7, String? avoid}) {
    final drawn = bag.draw(level: level, ids: from, random: Random(seed), avoidId: avoid);
    if (drawn == null) fail('a level with puzzles always draws one');
    return drawn;
  }

  test('six draws of a six-puzzle level give six different ids', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    final drawn = [for (var i = 0; i < 6; i++) drawOne(bag, Level.easy, seed: i)];
    expect(drawn.toSet(), easy.toSet(), reason: 'a cycle is every id of the level, once');
  });

  test('the seventh draw differs from the sixth, and the next cycle brings all six again', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    final first = [for (var i = 0; i < 6; i++) drawOne(bag, Level.easy, seed: i)];
    final seventh = drawOne(bag, Level.easy, seed: 11);
    expect(seventh, isNot(first.last), reason: 'a new cycle does not open with the puzzle just finished');
    final rest = [for (var i = 0; i < 5; i++) drawOne(bag, Level.easy, seed: i + 20)];
    expect({seventh, ...rest}, easy.toSet());
  });

  test('a level with no puzzles draws nothing and saves nothing', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    expect(bag.draw(level: Level.easy, ids: const [], random: Random(7)), isNull);
    expect(host.prefs.getString('puzzleBag'), isNull, reason: 'there was nothing to save');
  });

  test('a one-puzzle level always plays that puzzle', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    final drawn = [
      for (var i = 0; i < 3; i++) drawOne(bag, Level.easy, from: ['solo'], seed: i),
    ];
    expect(drawn, ['solo', 'solo', 'solo']);
  });

  test('the bag is saved: a new notifier over the same prefs draws on in its order', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    final before = [for (var i = 0; i < 3; i++) drawOne(bag, Level.easy, seed: i)];
    final kept = host.container.read(puzzleBagProvider).waitingFor(Level.easy);
    expect(kept, hasLength(3), reason: 'six ids, three drawn');

    final second = ProviderContainer(overrides: [prefsProvider.overrideWithValue(host.prefs)]);
    addTearDown(second.dispose);
    expect(second.read(puzzleBagProvider).waitingFor(Level.easy), kept, reason: 'the saved order is the one read');
    final after = [
      for (var i = 0; i < 3; i++) drawOne(second.read(puzzleBagProvider.notifier), Level.easy, seed: i + 10),
    ];
    expect({...before, ...after}, easy.toSet(), reason: 'every id once before any comes back');
  });

  test('a puzzle a build adds is drawn within the cycle', () async {
    const five = ['a', 'b', 'c', 'd', 'e'];
    const six = ['a', 'b', 'c', 'd', 'e', 'g'];
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    final before = [for (var i = 0; i < 2; i++) drawOne(bag, Level.easy, from: five, seed: i)];
    final after = [for (var i = 0; i < 4; i++) drawOne(bag, Level.easy, from: six, seed: i + 5)];
    expect({...before, ...after}, six.toSet(), reason: 'the added puzzle comes before the level\'s cycle ends');
  });

  test('an id a build no longer ships is dropped', () async {
    final host = await bagHost({
      'puzzleBag': jsonEncode({
        'easy': ['gone', 'a', 'b'],
      }),
    });
    final bag = host.container.read(puzzleBagProvider.notifier);
    final drawn = [
      for (var i = 0; i < 2; i++) drawOne(bag, Level.easy, from: ['a', 'b'], seed: i),
    ];
    expect(drawn.toSet(), {'a', 'b'}, reason: 'the id this build does not ship is not drawn');
    expect(host.container.read(puzzleBagProvider).waitingFor(Level.easy), isEmpty);
  });

  test('a puzzle chosen by hand leaves the bag without a draw, and the rest keep their order', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    for (var i = 0; i < 2; i++) {
      drawOne(bag, Level.easy, seed: i);
    }
    final waiting = host.container.read(puzzleBagProvider).waitingFor(Level.easy);
    expect(waiting, hasLength(4));
    final picked = waiting[2];
    bag.played(Level.easy, picked);
    expect(host.container.read(puzzleBagProvider).waitingFor(Level.easy), [
      waiting[0],
      waiting[1],
      waiting[3],
    ], reason: 'the chosen puzzle leaves the bag, and nothing else moves');

    final chosen = host.container.read(puzzleBagProvider.notifier);
    final rest = [for (var i = 0; i < 3; i++) drawOne(chosen, Level.easy, seed: i + 7)];
    expect(rest, [waiting[0], waiting[1], waiting[3]], reason: 'the bag plays on where it left off');
  });

  test('a puzzle chosen by hand before any draw is not the next one played', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    bag.played(Level.easy, 'c');
    final drawn = [for (var i = 0; i < 5; i++) drawOne(bag, Level.easy, seed: i)];
    expect(drawn, isNot(contains('c')), reason: 'the puzzle just chosen is not repeated early');
  });

  test('a rematch does not get the puzzle it just played while another one is left', () async {
    final host = await bagHost({
      'puzzleBag': jsonEncode({'easy': easy}),
    });
    final bag = host.container.read(puzzleBagProvider.notifier);
    final drawn = drawOne(bag, Level.easy, avoid: 'a');
    expect(drawn, isNot('a'), reason: 'the bag\'s first id was the one just played, so it waits behind');
    expect(host.container.read(puzzleBagProvider).waitingFor(Level.easy), ['c', 'd', 'e', 'f', 'a']);
  });

  test('every level has its own bag', () async {
    final host = await bagHost();
    final bag = host.container.read(puzzleBagProvider.notifier);
    final easyDrawn = <String>[];
    final mediumDrawn = <String>[];
    for (var i = 0; i < 6; i++) {
      easyDrawn.add(drawOne(bag, Level.easy, seed: i));
      mediumDrawn.add(drawOne(bag, Level.medium, from: medium, seed: i));
    }
    expect(easyDrawn.toSet(), easy.toSet());
    expect(mediumDrawn.toSet(), medium.toSet());
  });
}
