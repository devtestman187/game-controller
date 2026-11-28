import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'snapshot_eight_players_test.dart' show nightFrame;

void main() {
  test('a frame with a golden target round-trips through encode and decode, with the same target', () {
    final base = nightFrame(4);
    final frame = MatchSnapshot(boards: base.boards, seed: 7, golden: 3);
    final back = MatchSnapshot.decode(frame.encode());
    expect(back.golden, 3);
    expect(back.encode(), frame.encode());
  });

  test('a frame without a golden target writes no gd key and decodes with no target', () {
    final frame = MatchSnapshot(boards: nightFrame(4).boards, seed: 7);
    final map = jsonDecode(frame.encode()) as Map<String, Object?>;
    expect(map.containsKey('gd'), isFalse, reason: 'no target, no key');
    final back = MatchSnapshot.decode(frame.encode());
    expect(back.golden, isNull);
    expect(back.encode(), frame.encode());
  });

  test('a frame from before the golden target has no gd key and decodes with no target', () {
    final base = nightFrame(4);
    final frame = MatchSnapshot(boards: base.boards, seed: 7, golden: 3);
    final map = jsonDecode(frame.encode()) as Map<String, Object?>;
    final withoutGd = Map<String, Object?>.of(map)..remove('gd');
    final old = MatchSnapshot.fromJson(withoutGd);
    expect(old.golden, isNull);
    expect(old.seed, 7);
  });

  test('a lerp at 0.4 takes the golden target of the nearer frame, this one', () {
    final base = nightFrame(4);
    final from = MatchSnapshot(boards: base.boards, seed: 7, golden: 2);
    final to = MatchSnapshot(boards: base.boards, seed: 7, golden: 5);
    expect(from.lerpTo(to, 0.4).golden, 2);
  });

  test('a lerp at 0.6 takes the golden target of the nearer frame, the next one', () {
    final base = nightFrame(4);
    final from = MatchSnapshot(boards: base.boards, seed: 7, golden: 2);
    final to = MatchSnapshot(boards: base.boards, seed: 7, golden: 5);
    expect(from.lerpTo(to, 0.6).golden, 5);
  });
}
