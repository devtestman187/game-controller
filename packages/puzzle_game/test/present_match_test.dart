import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/cat_run.dart';
import 'support/match_helpers.dart';

/// The hot-potato present in a match (M17 r3c, owner Q4): the cat knocks a placed piece only on Wild, the present
/// comes on Calm and Lively instead, a snap by its holder bats it on, and it never costs a side a placed piece.
void main() {
  /// A 120 s race of [flatWorld], p1 on the left and p2 on the right, on [preset] and [chaos].
  PuzzleMatch raceOn(CatPreset preset, {Chaos chaos = Chaos.party}) => begin(flatWorld(), const {
    'p1': PuzzleSide.left,
    'p2': PuzzleSide.right,
  }, settings: PuzzleSettings(chaos: chaos, catPreset: preset));

  /// A 120 s one-board match of p1 alone, on [chaos] and Lively.
  PuzzleMatch soloOn(Chaos chaos) =>
      begin(flatWorld(), const {'p1': PuzzleSide.left}, settings: PuzzleSettings(chaos: chaos));

  /// The left side ahead by two pieces and the right by one, as the cat's knock tests set them up.
  Watch leftAhead(PuzzleMatch m) {
    final left = m.gameOf(PuzzleSide.left);
    put(m, left, 'p1', 0);
    put(m, left, 'p1', 1);
    put(m, m.gameOf(PuzzleSide.right), 'p2', 0);
    return Watch(m);
  }

  test('Party on Calm and Lively never knocks a placed piece, and on Wild the cat still knocks one', () {
    for (final preset in [CatPreset.calm, CatPreset.lively]) {
      final m = raceOn(preset);
      final w = leftAhead(m);
      w.toTheEnd();
      expect(w.bats.where((b) => b.knocked), isEmpty, reason: '${preset.name}: the present takes the knock\'s place');
    }
    final wild = raceOn(CatPreset.wild);
    final w = leftAhead(wild);
    expect(w.catComes(), isTrue);
    expect(w.batsOne(), isTrue);
    expect(w.bats.single.knocked, isTrue, reason: 'Wild keeps the cat\'s knock of the side ahead');
  });

  test('a present comes after its start delay at A lot, Calm and Lively', () {
    for (final (chaos, preset) in [(Chaos.party, CatPreset.lively), (Chaos.party, CatPreset.calm)]) {
      final m = raceOn(preset, chaos: chaos);
      final w = Watch(m);
      w.to(PresentRules.startDelayS - 1);
      expect(m.snapshot().present, isNull, reason: '${chaos.name} ${preset.name}: the first waits for the delay');
      w.to(PresentRules.startDelayS + 1);
      expect(m.snapshot().present, isNotNull, reason: '${chaos.name} ${preset.name}: it is out after the delay');
    }
  });

  test('no present on Off, on A little, on Wild, or on one board', () {
    final off = Watch(raceOn(CatPreset.lively, chaos: Chaos.off));
    final wild = Watch(raceOn(CatPreset.wild));
    final little = Watch(raceOn(CatPreset.lively, chaos: Chaos.little));
    final solo = Watch(soloOn(Chaos.party));
    final end = PresentRules.startDelayS + 5;
    for (final w in [off, little, wild, solo]) {
      w.to(end);
      expect(w.match.snapshot().present, isNull);
    }
  });

  test('a snap by the side holding the present bats it to the other side', () {
    final m = raceOn(CatPreset.lively);
    final w = Watch(m);
    w.to(PresentRules.startDelayS + 1);
    expect(m.snapshot().present!.holder, PuzzleSide.left, reason: 'the left side holds the first present');
    put(m, m.gameOf(PuzzleSide.left), 'p1', 0);
    expect(m.snapshot().present!.holder, PuzzleSide.right, reason: 'the left snap bats it to the right');
    put(m, m.gameOf(PuzzleSide.left), 'p1', 1);
    expect(m.snapshot().present!.holder, PuzzleSide.right, reason: 'a snap by the side without it does nothing');
  });

  test('the present never changes a side\'s placed count, even when its fuse pops', () {
    final m = raceOn(CatPreset.lively);
    final left = m.gameOf(PuzzleSide.left);
    final right = m.gameOf(PuzzleSide.right);
    put(m, left, 'p1', 0);
    put(m, right, 'p2', 0);
    final placedLeft = left.placed;
    final placedRight = right.placed;
    final w = Watch(m);
    w.to(PresentRules.startDelayS + 1);
    expect(w.until(() => m.snapshot().present?.popped == true), isTrue, reason: 'the fuse runs out and it pops');
    expect(left.placed, placedLeft);
    expect(right.placed, placedRight);
  });
}
