import 'dart:math';

import 'present.dart';
import 'puzzle_values.dart';
import 'settings.dart';

/// The hot-potato present's rules (M17 r3b): when one comes, which side holds it, how each snap by the holder bats
/// it on and shortens its fuse, and how it pops on the slow side. Pure Dart: it never draws. The present never costs
/// a piece, as no piece code runs here.
final class PresentRules {
  /// How the present's rules run in a round: a present only at A lot chaos and not on Wild (owner, Nov 27: A little has none), which the
  /// owner may change here in one place.
  static bool enabled(PuzzleSettings s) => s.chaos == Chaos.party && s.catPreset != CatPreset.wild;

  /// Seconds of a round before the first present: see [FuseParams.startDelayS].
  static const startDelayS = FuseParams.startDelayS;

  /// The fuse a present starts with, in ms: see [FuseParams.startFuseMs].
  static const startFuseMs = FuseParams.startFuseMs;

  /// Ms the fuse loses on each snap by the holder: see [FuseParams.snapCutMs].
  static const snapCutMs = FuseParams.snapCutMs;

  /// The least fuse a snap leaves, in ms: see [FuseParams.minFuseMs].
  static const minFuseMs = FuseParams.minFuseMs;

  /// PROVISIONAL (fuse values lock after the kid playtest, r3g). Ms a popped present stays on the view.
  static const popMs = 1500;

  /// PROVISIONAL (fuse values lock after the kid playtest, r3g). Seconds with no present out before the next one,
  /// counted from the end of the last pop.
  static const gapS = 15.0;

  /// Ms in a second: the fuse counts in ms and the clock in seconds.
  static const _msPerS = 1000;

  /// Seconds since the last present ended, or since the rules began, while no present is out.
  double _clockS = 0;

  /// How many presents have come, so the first one waits for [startDelayS] and the holder alternates from left.
  int _presents = 0;

  /// True once [end] has run: the rules never bring a present back.
  bool _ended = false;

  /// The side the present is with now, or null when none is out.
  PuzzleSide? _holder;

  /// The fuse left, in ms, while the present is batted about.
  double _fuseMs = 0;

  /// True once the present has popped on the slow side.
  bool _popped = false;

  /// The pop time left, in ms, once the present has popped.
  double _popLeftMs = 0;

  /// The present as the view sees it, or null when none is out.
  PresentState? get state {
    final holder = _holder;
    if (holder == null) return null;
    return PresentState(
      holder: holder,
      fuseMs: _popped ? 0 : _fuseMs.round(),
      fuseTotalMs: startFuseMs,
      popped: _popped,
    );
  }

  /// A snap by [side]. When a present is held and [side] holds it, it is batted to the other side and its fuse is cut
  /// by [snapCutMs], never below [minFuseMs]. A fuse already under [minFuseMs] is left as it is: a snap only shortens
  /// the fuse, never lengthens it. A snap by the other side, or with no present out, does nothing.
  void onSnap(PuzzleSide side) {
    final holder = _holder;
    if (holder == null || _popped || side != holder) return;
    _holder = holder == PuzzleSide.left ? PuzzleSide.right : PuzzleSide.left;
    _fuseMs = min(_fuseMs, max(minFuseMs.toDouble(), _fuseMs - snapCutMs));
  }

  /// Moves the rules on by [dt] seconds. With the rules [enabled] and not on one board, a present comes once the
  /// clock reaches [startDelayS] (or [gapS] after the last pop), held by the left side first and then alternating.
  /// While held the fuse runs down; at 0 the present pops on the side holding it for [popMs], then goes. Turning the
  /// rules off removes a present at once and restarts the clock.
  void update(double dt, {required bool enabled, required bool oneBoard}) {
    if (_ended) return;
    if (!enabled || oneBoard) {
      _clear();
      return;
    }
    if (_holder == null) {
      _clockS += dt;
      if (_clockS >= (_presents == 0 ? startDelayS : gapS)) _spawn();
      return;
    }
    if (_popped) {
      _popLeftMs -= dt * _msPerS;
      if (_popLeftMs <= 0) _clear();
      return;
    }
    _fuseMs -= dt * _msPerS;
    if (_fuseMs <= 0) {
      _fuseMs = 0;
      _popped = true;
      _popLeftMs = popMs.toDouble();
    }
  }

  /// Clears the present for good: no later [update] brings one back and no snap does anything.
  void end() {
    _ended = true;
    _clear();
  }

  /// Brings a present out, held by the left side on the first and then alternating, with the start fuse.
  void _spawn() {
    _holder = _presents.isEven ? PuzzleSide.left : PuzzleSide.right;
    _presents++;
    _fuseMs = startFuseMs.toDouble();
    _popped = false;
    _clockS = 0;
  }

  /// Takes the present out and restarts the clock, which then counts the wait for the next one.
  void _clear() {
    _holder = null;
    _popped = false;
    _clockS = 0;
  }
}
