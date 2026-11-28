import 'dart:math';

import 'game.dart';
import 'puzzle_values.dart';

/// What each board has, read off the match for one step of the golden slot: the targets each board has not filled yet,
/// and how many pieces each board has placed (the side behind is the one with fewer).
final class GoldenInputs {
  const GoldenInputs({
    required this.openLeft,
    required this.openRight,
    required this.placedLeft,
    required this.placedRight,
  });

  /// The targets the left board has not filled yet.
  final Set<int> openLeft;

  /// The targets the right board has not filled yet.
  final Set<int> openRight;

  /// The pieces the left board has placed.
  final int placedLeft;

  /// The pieces the right board has placed.
  final int placedRight;
}

/// The golden slot (M17 race1c r3e): one target outline glows on both boards of a two-board match, and the first side
/// to fill it earns double the snap's points (see `PuzzlePointsRules._awardSnap`). Pure Dart: it never draws.
final class GoldenSlot {
  /// The match's random: [stepBoards] picks from it, so a seeded match picks the same slots every time.
  GoldenSlot(this._random);
  final Random _random;

  /// PROVISIONAL (kid playtest). Seconds of a round before the first slot glows.
  static const firstDelayS = 10.0;

  /// PROVISIONAL (kid playtest). Seconds from a claim, or from a glowing slot clearing, to the next glow. This is the
  /// golden slot's gap, not the present's gap (`PresentRules.gapS`).
  static const glowGapS = 10.0;

  /// The weight of a target open on both boards, and of one open only on the side that is behind on a tie. The side
  /// behind gets the double: its own targets weigh [_behindWeight] when it trails.
  static const _sharedWeight = 1;
  static const _behindWeight = 2;

  /// The target index that glows, or null while none does.
  int? _slot;

  /// The side that filled the last claimed slot first, or null before any claim.
  PuzzleSide? _claimedBy;

  /// Targets already claimed: they never glow again, so the double is paid once per target.
  final _claimed = <int>{};

  /// Seconds to wait before the next pick, and seconds waited so far.
  double _delayS = firstDelayS;
  double _waitedS = 0;

  /// The target index that glows, or null while none does.
  int? get slot => _slot;

  /// The side that filled the last claimed slot first, or null before any claim.
  PuzzleSide? get claimedBy => _claimedBy;

  /// Advances by [dt] seconds. While [enabled] and no slot glows, counts the wait and then picks a target open on at
  /// least one board, weighted towards the side behind. A glowing slot that both sides have locked clears, with no claim.
  void update(double dt, {required bool enabled, required GoldenInputs inputs}) {
    if (!enabled) {
      _slot = null;
      return;
    }
    final glowing = _slot;
    if (glowing != null) {
      if (inputs.openLeft.contains(glowing) || inputs.openRight.contains(glowing)) return;
      _slot = null;
      _restart();
      return;
    }
    _waitedS += dt;
    if (_waitedS < _delayS) return;
    final picked = _pick(inputs);
    if (picked == null) return;
    _slot = picked;
    _waitedS = 0;
  }

  /// The match's step: [boards] are the match's games (one on one board, which then has both sides), and [enabled] is
  /// the gate (two boards, on the present's gate). Opens and placed counts come from the games.
  void stepBoards(double dt, {required bool enabled, required List<PuzzleGame> boards}) {
    final left = boards.firstWhere((g) => g.side == PuzzleSide.left, orElse: () => boards.first);
    final right = boards.firstWhere((g) => g.side == PuzzleSide.right, orElse: () => boards.first);
    final inputs = GoldenInputs(
      openLeft: _openOn(left),
      openRight: _openOn(right),
      placedLeft: left.placed,
      placedRight: right.placed,
    );
    update(dt, enabled: enabled, inputs: inputs);
  }

  /// The first claim on the glowing slot, by [side] at [target]: true, and the slot clears and the gap restarts. Any
  /// other claim (no slot glows, another target, or one already paid) is false and changes nothing.
  bool claim(PuzzleSide side, int target) {
    if (_slot != target) return false;
    _claimed.add(target);
    _claimedBy = side;
    _slot = null;
    _restart();
    return true;
  }

  void _restart() {
    _delayS = glowGapS;
    _waitedS = 0;
  }

  /// The targets of [game]'s board that nobody has locked yet.
  static Set<int> _openOn(PuzzleGame game) {
    final open = {for (var i = 0; i < game.puzzle.pieces.length; i++) i};
    for (final piece in game.pieces) {
      final target = piece.lockedTarget;
      if (piece.state == PieceState.locked && target != null) open.remove(target);
    }
    return open;
  }

  /// A target's pick weight: 0 when it is claimed, open on neither board, or open only on the side that leads.
  int _weight(int target, GoldenInputs inputs) {
    if (_claimed.contains(target)) return 0;
    final onLeft = inputs.openLeft.contains(target);
    final onRight = inputs.openRight.contains(target);
    if (onLeft && onRight) return _sharedWeight;
    if (!onLeft && !onRight) return 0;
    final ownPlaced = onLeft ? inputs.placedLeft : inputs.placedRight;
    final otherPlaced = onLeft ? inputs.placedRight : inputs.placedLeft;
    if (ownPlaced < otherPlaced) return _behindWeight;
    if (ownPlaced == otherPlaced) return _sharedWeight;
    return 0;
  }

  /// A weighted pick among the candidates, in target order so a seed picks the same slot every time.
  int? _pick(GoldenInputs inputs) {
    final candidates = [
      for (final target in ({...inputs.openLeft, ...inputs.openRight}.toList()..sort()))
        (target: target, weight: _weight(target, inputs)),
    ].where((c) => c.weight > 0).toList();
    final total = candidates.fold(0, (sum, c) => sum + c.weight);
    if (total == 0) return null;
    var roll = _random.nextInt(total);
    for (final c in candidates) {
      if (roll < c.weight) return c.target;
      roll -= c.weight;
    }
    return candidates.last.target;
  }
}
