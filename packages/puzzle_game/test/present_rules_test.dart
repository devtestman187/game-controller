import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// Runs [rules] for [seconds] whole seconds, live (enabled, not on one board). Whole seconds keep every expectation exact.
void _run(PresentRules rules, int seconds) {
  for (var i = 0; i < seconds; i++) {
    rules.update(1.0, enabled: true, oneBoard: false);
  }
}

void main() {
  test('no present comes before the start delay', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() - 1);
    expect(rules.state, isNull);
  });

  test('the first present comes at the start delay, held by the left side, with the start fuse', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round());
    expect(rules.state, const PresentState(holder: PuzzleSide.left, fuseMs: 12000, fuseTotalMs: 12000));
  });

  test('one present at a time: it counts its fuse down and no second one comes while it is out', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    expect(rules.state, const PresentState(holder: PuzzleSide.left, fuseMs: 9000, fuseTotalMs: 12000));
  });

  test('a snap with no present out does nothing', () {
    final rules = PresentRules();
    rules.onSnap(PuzzleSide.left);
    expect(rules.state, isNull);
  });

  test('a snap by the holder bats the present to the other side and cuts its fuse by 1500 ms', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left);
    expect(rules.state, const PresentState(holder: PuzzleSide.right, fuseMs: 7500, fuseTotalMs: 12000));
  });

  test('the fuse never falls below the 4000 ms floor', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left); // right holds, fuse 7500
    rules.onSnap(PuzzleSide.right); // left holds, fuse 6000
    rules.onSnap(PuzzleSide.left); // right holds, fuse 4500
    rules.onSnap(PuzzleSide.right); // left holds, 3000 would be cut, so 4000
    expect(rules.state, const PresentState(holder: PuzzleSide.left, fuseMs: 4000, fuseTotalMs: 12000));
  });

  test('a snap by the other side changes nothing', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left); // right holds, fuse 7500
    final before = rules.state;
    rules.onSnap(PuzzleSide.left);
    expect(rules.state, before);
  });

  test('a fuse that runs out pops the present on the side holding it', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left); // right holds, fuse 7500
    rules.onSnap(PuzzleSide.right); // left holds, fuse 6000
    rules.onSnap(PuzzleSide.left); // right holds, fuse 4500
    rules.onSnap(PuzzleSide.right); // left holds, fuse 4000
    _run(rules, 4);
    expect(rules.state, const PresentState(holder: PuzzleSide.left, fuseMs: 0, fuseTotalMs: 12000, popped: true));
  });

  test('a popped present stays for 1500 ms, and the next one comes 15 s after it is gone', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left); // right holds, fuse 7500
    rules.onSnap(PuzzleSide.right); // left holds, fuse 6000
    rules.onSnap(PuzzleSide.left); // right holds, fuse 4500
    rules.onSnap(PuzzleSide.right); // left holds, fuse 4000
    _run(rules, 4); // pops
    _run(rules, 1); // 500 ms of the pop left
    expect(rules.state?.popped, isTrue);
    _run(rules, 1); // the pop is over
    expect(rules.state, isNull);
    _run(rules, PresentRules.gapS.round() - 1);
    expect(rules.state, isNull);
    _run(rules, 1);
    expect(rules.state, const PresentState(holder: PuzzleSide.right, fuseMs: 12000, fuseTotalMs: 12000));
  });

  test('disabling the rules removes the present at once', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round());
    rules.update(1.0, enabled: false, oneBoard: false);
    expect(rules.state, isNull);
  });

  test('a one-board match never has a present', () {
    final rules = PresentRules();
    for (var i = 0; i < 60; i++) {
      rules.update(1.0, enabled: true, oneBoard: true);
    }
    expect(rules.state, isNull);
  });

  test('end() clears the present, and no later update brings one back', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round());
    rules.end();
    expect(rules.state, isNull);
    _run(rules, 60);
    expect(rules.state, isNull);
  });

  test('enabled over chaos x pace: the present only at A lot on Calm and Lively', () {
    for (final chaos in Chaos.values) {
      for (final preset in CatPreset.values) {
        final want = chaos == Chaos.party && preset != CatPreset.wild;
        expect(
          PresentRules.enabled(PuzzleSettings(chaos: chaos, catPreset: preset)),
          want,
          reason: '${chaos.name} ${preset.name}',
        );
      }
    }
  });
}
