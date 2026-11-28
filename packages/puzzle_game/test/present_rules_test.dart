import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// Runs [rules] for [seconds] whole seconds, live (enabled, not on one board). Whole seconds keep every expectation exact.
void _run(PresentRules rules, int seconds) {
  for (var i = 0; i < seconds; i++) {
    rules.update(1.0, enabled: true, oneBoard: false);
  }
}

const _start = PresentRules.startFuseMs;
const _cut = PresentRules.snapCutMs;
const _min = PresentRules.minFuseMs;

/// Bats the present from whoever holds it until the fuse sits on the floor; returns the holder then. Needs a live
/// present. Works for any sensible fuse values (a cut above 0, a floor under the start).
PuzzleSide _batToFloor(PresentRules rules) {
  for (var i = 0; i < 100; i++) {
    final st = rules.state!;
    if (st.fuseMs <= _min) return st.holder;
    rules.onSnap(st.holder);
  }
  fail('the fuse never reached the floor');
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
    expect(rules.state, const PresentState(holder: PuzzleSide.left, fuseMs: _start, fuseTotalMs: _start));
  });

  test('one present at a time: it counts its fuse down and no second one comes while it is out', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    expect(rules.state, const PresentState(holder: PuzzleSide.left, fuseMs: _start - 3000, fuseTotalMs: _start));
  });

  test('a snap with no present out does nothing', () {
    final rules = PresentRules();
    rules.onSnap(PuzzleSide.left);
    expect(rules.state, isNull);
  });

  test('a snap by the holder bats the present to the other side and cuts its fuse by the snap cut', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left);
    expect(_start - 3000 - _cut, greaterThanOrEqualTo(_min), reason: 'fixture: the cut must not hit the floor');
    expect(
      rules.state,
      const PresentState(holder: PuzzleSide.right, fuseMs: _start - 3000 - _cut, fuseTotalMs: _start),
    );
  });

  test('the fuse never falls below the floor', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    final holder = _batToFloor(rules);
    rules.onSnap(holder); // one more cut would go under the floor: it stays on it
    expect(
      rules.state,
      PresentState(
        holder: holder == PuzzleSide.left ? PuzzleSide.right : PuzzleSide.left,
        fuseMs: _min,
        fuseTotalMs: _start,
      ),
    );
  });

  test('a snap on a fuse already under the floor leaves the fuse as it was', () {
    final rules = PresentRules();
    final secs = (_start - _min) ~/ 1000 + 1; // the first whole second count that runs the fuse under the floor
    final left = _start - secs * 1000;
    expect(left, greaterThan(0), reason: 'fixture: the fuse must still be lit');
    _run(rules, PresentRules.startDelayS.round() + secs);
    rules.onSnap(PuzzleSide.left); // right holds, the fuse stays, it is not lifted to the floor
    expect(rules.state, PresentState(holder: PuzzleSide.right, fuseMs: left, fuseTotalMs: _start));
  });

  test('a snap by the other side changes nothing', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    rules.onSnap(PuzzleSide.left); // right holds
    final before = rules.state;
    rules.onSnap(PuzzleSide.left);
    expect(rules.state, before);
  });

  test('a fuse that runs out pops the present on the side holding it', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    final holder = _batToFloor(rules);
    _run(rules, (_min / 1000).ceil());
    expect(rules.state, PresentState(holder: holder, fuseMs: 0, fuseTotalMs: _start, popped: true));
  });

  test('a popped present stays for the pop time, and the next one comes the gap after it is gone', () {
    final rules = PresentRules();
    _run(rules, PresentRules.startDelayS.round() + 3);
    final holder = _batToFloor(rules);
    _run(rules, (_min / 1000).ceil()); // pops
    _run(rules, 1); // 500 ms of the pop left
    expect(rules.state?.popped, isTrue);
    _run(rules, 1); // the pop is over
    expect(rules.state, isNull);
    _run(rules, PresentRules.gapS.round() - 1);
    expect(rules.state, isNull);
    _run(rules, 1);
    expect(
      rules.state,
      PresentState(
        holder: holder == PuzzleSide.left ? PuzzleSide.right : PuzzleSide.left,
        fuseMs: _start,
        fuseTotalMs: _start,
      ),
    );
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
