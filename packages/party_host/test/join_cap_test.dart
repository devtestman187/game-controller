import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/ui/join_screen.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// Joins players one by one, each to the side [sideForNewPlayer] gives, until
/// both sides are full at [cap] or [players] have joined.
Map<String, PuzzleSide> _fill({required int cap, required int players}) {
  final teams = <String, PuzzleSide>{};
  for (var i = 0; i < players; i++) {
    final side = sideForNewPlayer(teams, cap: cap);
    if (side == null) break;
    teams['p$i'] = side;
  }
  return teams;
}

int _count(Map<String, PuzzleSide> teams, PuzzleSide side) => teams.values.where((s) => s == side).length;

void main() {
  test('with the default cap of two a side, the third player is turned away', () {
    final teams = _fill(cap: 2, players: 9);
    expect(teams.length, 4, reason: 'two a side');
    expect(sideForNewPlayer(teams), isNull, reason: 'the default cap is the same as before');
  });

  test('a cap of three fills both sides evenly and turns the seventh player away', () {
    final teams = _fill(cap: 3, players: 9);
    expect(_count(teams, PuzzleSide.left), 3);
    expect(_count(teams, PuzzleSide.right), 3);
    expect(sideForNewPlayer(teams, cap: 3), isNull);
  });

  test('a cap of four fills both sides evenly and turns the ninth player away', () {
    final teams = _fill(cap: 4, players: 10);
    expect(_count(teams, PuzzleSide.left), 4);
    expect(_count(teams, PuzzleSide.right), 4);
    expect(sideForNewPlayer(teams, cap: 4), isNull);
  });

  test('the setting of four is cut to two a side on Easy, the level\'s cap', () {
    final cap = maxPerSideFor(Level.easy, 4);
    expect(cap, 2);
    expect(_fill(cap: cap, players: 10).length, 4);
  });

  test('the setting of four seats four a side on Medium', () {
    final cap = maxPerSideFor(Level.medium, 4);
    expect(cap, 4);
    expect(_fill(cap: cap, players: 10).length, 8);
  });
}
