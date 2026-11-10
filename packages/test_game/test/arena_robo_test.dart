import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

/// The frame these tests draw: a marble per roster entry, one at either side.
ArenaSnapshot frameOf(ArenaRoster roster) => ArenaSnapshot(
  round: 1,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: const Rect.fromLTRB(0.86, 0.38, 0.97, 0.62),
  hazards: const [],
  players: [
    for (final MapEntry(key: id, value: player) in roster.entries)
      ArenaPlayerView(id: id, x: 0.2 + 0.2 * player.number, y: 0.5),
  ],
);

void main() {
  group('Robo’s colour', () {
    test('is the lowest player number nobody has', () {
      expect(roboNumberFor(const []), 1, reason: 'nobody joined, so the first colour is free');
      expect(roboNumberFor(const [1]), 2, reason: 'a lone P1 leaves P2’s colour');
      expect(roboNumberFor(const [1, 3]), 2, reason: 'a P3 that joined before P2 left 2 free');
      expect(roboNumberFor(const [1, 2, 3, 4, 5, 6]), 7, reason: 'past the sixth, the colours wrap as players do');
    });
  });

  group('the viewers’ roster', () {
    test('gives Robo the free colour and its name when the frame has its marble', () {
      const roster = {'a': (number: 1, name: 'Ada')};
      final merged = arenaRosterFor(frameOf({...roster, roboPlayerId: (number: 2, name: roboName)}), roster);
      expect(merged[roboPlayerId], (number: 2, name: roboName));
      expect(merged['a'], (number: 1, name: 'Ada'), reason: 'the players keep their own numbers');
    });

    test('leaves the roster as it is when no frame carries Robo', () {
      const roster = {'a': (number: 1, name: 'Ada')};
      expect(arenaRosterFor(frameOf(roster), roster), roster);
    });
  });

  group('Robo’s marble', () {
    const roster = {'a': (number: 1, name: 'Ada'), roboPlayerId: (number: 2, name: roboName)};

    test('wears its colour with the antenna the design gives it', () {
      final robo = arenaCharacterFor(roster, roboPlayerId);
      expect(robo.colourSlot, ToyCharacter.forPlayer(2).colourSlot);
      expect(robo.accessory, ToyAccessory.antenna, reason: 'party-night §7a: a small antenna');
    });

    test('leaves a player’s character alone', () {
      expect(arenaCharacterFor(roster, 'a').accessory, ToyCharacter.forPlayer(1).accessory);
    });
  });

  group('the levels’ numbers', () {
    test('are the design’s table', () {
      const table = {
        RoboLevel.easy: (0.5, 0.75, 0.45),
        RoboLevel.medium: (0.3, 0.85, 0.2),
        RoboLevel.hard: (0.15, 0.95, 0.05),
      };
      for (final level in RoboLevel.values) {
        final tuning = CpuTuning.of(level);
        expect(
          (tuning.reactionS, tuning.speedShare, tuning.wobbleRad),
          table[level],
          reason: '${level.name} is the design’s reacts, top speed and wobble',
        );
      }
    });
  });
}
