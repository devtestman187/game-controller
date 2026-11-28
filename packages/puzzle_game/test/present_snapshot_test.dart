import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'snapshot_eight_players_test.dart' show nightFrame, playerCounts;

/// The most a present may add to a frame, in bytes: its `pr` key and its four numbers come to 23 bytes at the
/// frame's worst-case digits, so 40 leaves room for the digits to grow (M17 r3a).
const presentMaxBytes = 40;

/// A present out with the fuse half run down, the frame's worst-case digits in its fuse (M17 r3a).
const _present = PresentState(holder: PuzzleSide.right, fuseMs: 9000, fuseTotalMs: 15000);

/// The present at the start of a lerp, and the same present a while later (M17 r3a).
const _from = PresentState(holder: PuzzleSide.left, fuseMs: 1000, fuseTotalMs: 4000);
const _to = PresentState(holder: PuzzleSide.right, fuseMs: 3000, fuseTotalMs: 6000, popped: true);

void main() {
  test('a frame with a present round-trips through encode and decode, with the present as it was', () {
    final base = nightFrame(4);
    final frame = MatchSnapshot(boards: base.boards, seed: 7, cat: base.cat, present: _present);
    final back = MatchSnapshot.decode(frame.encode());
    expect(back.present, _present);
    expect(back.encode(), frame.encode());
  });

  test('a frame without a present round-trips with no present', () {
    final frame = MatchSnapshot(boards: nightFrame(4).boards, seed: 7);
    final back = MatchSnapshot.decode(frame.encode());
    expect(back.present, isNull);
    expect(back.encode(), frame.encode());
  });

  test('a popped present encodes its holder, fuse and pop as four numbers, and decodes them back', () {
    const popped = PresentState(holder: PuzzleSide.left, fuseMs: 0, fuseTotalMs: 15000, popped: true);
    expect(popped.toJson(), [0, 0, 15000, 1]);
    expect(PresentState.fromJson(popped.toJson()), popped);
  });

  test('an older peer decodes a frame with a present, boards, seed and cat unchanged, when it ignores the pr key', () {
    final base = nightFrame(4);
    final frame = MatchSnapshot(boards: base.boards, seed: 7, cat: base.cat, present: _present);
    final map = jsonDecode(frame.encode()) as Map<String, Object?>;
    expect(map.containsKey('pr'), isTrue, reason: 'the frame carries the present');
    final withoutPr = Map<String, Object?>.of(map)..remove('pr');
    final old = MatchSnapshot.fromJson(withoutPr);
    final expected = MatchSnapshot(boards: base.boards, seed: 7, cat: base.cat);
    expect([for (final b in old.boards) b.toJson()], [for (final b in expected.boards) b.toJson()], reason: 'boards');
    expect(old.seed, 7);
    expect(old.cat, base.cat);
    expect(old.present, isNull);
  });

  test('a frame with an unknown extra key still decodes its present, as the m17.1 phone does', () {
    final base = nightFrame(4);
    final frame = MatchSnapshot(boards: base.boards, seed: 7, cat: base.cat, present: _present);
    final map = jsonDecode(frame.encode()) as Map<String, Object?>;
    final decoded = MatchSnapshot.fromJson({...map, 'zz': 1});
    expect(decoded.present, _present);
  });

  test('a present lerps: the fuse runs down linearly, and the holder and the pop switch at halfway', () {
    expect(_from.lerpTo(_to, 0.25), const PresentState(holder: PuzzleSide.left, fuseMs: 1500, fuseTotalMs: 4000));
    expect(
      _from.lerpTo(_to, 0.5),
      const PresentState(holder: PuzzleSide.right, fuseMs: 2000, fuseTotalMs: 6000, popped: true),
    );
    expect(
      _from.lerpTo(_to, 0.75),
      const PresentState(holder: PuzzleSide.right, fuseMs: 2500, fuseTotalMs: 6000, popped: true),
    );
  });

  test('a match lerps its present between two frames that both have one', () {
    final base = nightFrame(4);
    final a = MatchSnapshot(boards: base.boards, seed: 7, present: _from);
    final b = MatchSnapshot(boards: base.boards, seed: 7, present: _to);
    expect(a.lerpTo(b, 0.25).present, _from.lerpTo(_to, 0.25));
    expect(a.lerpTo(b, 0.75).present, _from.lerpTo(_to, 0.75));
  });

  test('a present that comes or goes between two frames is drawn as the nearer frame has it', () {
    final base = nightFrame(4);
    final out = MatchSnapshot(boards: base.boards, seed: 7, present: _from);
    final away = MatchSnapshot(boards: base.boards, seed: 7);
    expect(out.lerpTo(away, 0.25).present, _from, reason: 'nearer the present frame');
    expect(out.lerpTo(away, 0.75).present, isNull, reason: 'nearer the frame with none');
    expect(away.lerpTo(out, 0.25).present, isNull, reason: 'nearer the frame with none');
    expect(away.lerpTo(out, 0.75).present, _from, reason: 'nearer the present frame');
  });

  test('the worst-case night frame with a present adds at most presentMaxBytes at 4, 6 and 8 players', () {
    for (final players in playerCounts) {
      final frame = nightFrame(players);
      final without = MatchSnapshot(boards: frame.boards, seed: frame.seed, cat: frame.cat);
      final added = frame.encode().length - without.encode().length;
      expect(added, lessThanOrEqualTo(presentMaxBytes), reason: '$players players');
    }
  });

  test('the 4-player worst-case night frame with a present stays under PuzzleSnapshot.maxBytes', () {
    expect(nightFrame(4).encode().length, lessThan(PuzzleSnapshot.maxBytes));
  });
}
