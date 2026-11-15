import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/map_files.dart';

/// The race each map landed (M14 bugs7 b015), as the owner approved it in
/// bugs6: Block Castle finishes inside the keep, Toy Factory in the top-east
/// bay, and both swap sides every round, as the race does.
const approvedRaces = <String, RaceSpec>{
  'block-castle': RaceSpec(start: Offset(0.075, 0.5), goal: Rect.fromLTRB(0.4625, 0.444, 0.5375, 0.556)),
  'toy-factory': RaceSpec(start: Offset(0.1, 0.5), goal: Rect.fromLTRB(0.88, 0.14, 0.97, 0.24)),
};

/// The maps of M14 k2b that stay Bumper Round only: no race to win.
const bumperOnlyMapIds = ['pinball', 'spinning-tops'];

void main() {
  test('block-castle and toy-factory race from the approved start to the approved goal, swapping sides', () {
    for (final MapEntry(key: id, value: approved) in approvedRaces.entries) {
      final race = loadMap(id).race;
      expect(race, isNotNull, reason: '$id has a race section (M14 bugs7 b015)');
      expect(race?.start, approved.start, reason: '$id starts where the owner approved it');
      expect(race?.goal, approved.goal, reason: '$id finishes on the approved pad');
      expect(race?.swapSides, isTrue, reason: '$id swaps sides every round, as the race does');
    }
  });

  test('block-castle and toy-factory keep their Bumper Round starts and coin zones', () {
    for (final id in approvedRaces.keys) {
      final bumper = loadMap(id).bumper;
      expect(bumper, isNotNull, reason: '$id still plays the Bumper Round');
      expect(bumper?.starts, hasLength(bumperStarts), reason: '$id still starts four marbles');
    }
  });

  test('block-castle and toy-factory pass the rule book with their race in place', () {
    for (final id in approvedRaces.keys) {
      final issues = checkMap(loadMap(id));
      for (final issue in issues) {
        debugPrint('$issue');
      }
      expect(issues, isEmpty, reason: '$id: ${issues.isEmpty ? 'ready to race' : '${issues.length} issue(s)'}');
    }
  });

  test('pinball and spinning-tops still have no race: the Bumper Round alone', () {
    for (final id in bumperOnlyMapIds) {
      final map = loadMap(id);
      expect(map.race, isNull, reason: '$id is a Bumper Round arena with no finish (party-night §7b)');
      expect(map.bumper, isNotNull, reason: '$id plays the Bumper Round');
    }
  });
}
