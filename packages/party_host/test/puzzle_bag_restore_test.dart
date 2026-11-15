import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/puzzle_bag.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The bag across a restart (B-009, b013): a draw saves the ids the cycle has
/// played and the one it played last, so an app that closed between two rounds
/// neither opens with the puzzle just finished nor makes a new puzzle wait a
/// whole cycle for its turn. The bag's own rules are `puzzle_bag_test.dart`.
void main() {
  const easy = ['a', 'b', 'c', 'd', 'e', 'f'];

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
  String drawOne(PuzzleBagNotifier bag, Level level, {List<String> from = easy, int seed = 7}) {
    final drawn = bag.draw(level: level, ids: from, random: Random(seed));
    if (drawn == null) fail('a level with puzzles always draws one');
    return drawn;
  }

  test('a cycle that ended before the restart still does not open with the puzzle just finished', () async {
    final first = await bagHost();
    final bag = first.container.read(puzzleBagProvider.notifier);
    final played = [for (var i = 0; i < 6; i++) drawOne(bag, Level.easy, seed: i)];
    final last = played.last;
    expect(first.container.read(puzzleBagProvider).waitingFor(Level.easy), isEmpty, reason: 'the cycle is done');
    final saved = first.prefs.getString('puzzleBag');
    expect(saved, isNotNull);

    // The restart's refill from every shuffle: the id played last stays behind
    // another one in all of them. Each seed gets the saved prefs as they were.
    for (var seed = 0; seed < 30; seed++) {
      SharedPreferences.setMockInitialValues({'puzzleBag': saved!});
      final prefs = await SharedPreferences.getInstance();
      final second = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(second.dispose);
      final next = second.read(puzzleBagProvider.notifier).draw(level: Level.easy, ids: easy, random: Random(seed));
      expect(next, isNot(last), reason: 'seed $seed: the puzzle just finished waits behind another one');
    }
  });

  test('an id a build adds after a restart is shuffled into the cycle at once', () async {
    // A bag saved mid-cycle by a build of six: two ids waiting, four played.
    final host = await bagHost({
      'puzzleBag': jsonEncode({
        'easy': ['c', 'd'],
        'played': {
          'easy': {
            'ids': ['a', 'b', 'e', 'f'],
            'last': 'f',
          },
        },
      }),
    });
    final bag = host.container.read(puzzleBagProvider.notifier);
    expect(host.container.read(puzzleBagProvider).waitingFor(Level.easy), ['c', 'd'], reason: 'read back as saved');
    const seven = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    final drawn = <String>[];
    while (host.container.read(puzzleBagProvider).waitingFor(Level.easy).isNotEmpty) {
      drawn.add(drawOne(bag, Level.easy, from: seven, seed: drawn.length));
    }
    expect(
      drawn,
      unorderedEquals(['c', 'd', 'g']),
      reason: 'the new puzzle joins this cycle, with the two ids the bag still held',
    );
  });
}
