import 'dart:ui';

import 'puzzle_values.dart';

/// The cat's rules and the values they share with the view (PRD v2 G3).
abstract final class CatRules {
  /// How long the cat warns at the side's edge before it walks in, in seconds:
  /// its meow, the paw at the edge and the shadow on the piece it wants.
  static const warningS = 2.0;

  /// How long it takes to walk from the edge to that piece, to bat it, and to
  /// run off again.
  static const walkS = 1.2;
  static const batS = 0.4;
  static const leaveS = 1.2;

  /// A visit from the warning to the cat away.
  static const visitS = warningS + walkS + batS + leaveS;

  /// The cat leaves the first `graceS` of a round alone, and no visit runs
  /// into its last `tailS` (PRD v2 G3). A round too short for both has no cat.
  static const graceS = 20.0;
  static const tailS = 10.0;

  /// A placed piece must have sat in its outline this long before the cat may
  /// knock it loose (PRD v2 G3, Party): a piece placed a moment ago is safe.
  static const settledS = 3.0;

  /// How far in from the side's edge the paw sits, in field units: half the
  /// paw it leaves there.
  static const edgeInset = 3.5;

  /// How long [state] lasts, in milliseconds: the view times the head's and the
  /// paw's motion against that state's own span (M14 bug c1).
  static int spanMs(CatState state) => switch (state) {
    CatState.warning => (warningS * msPerS).round(),
    CatState.walk => (walkS * msPerS).round(),
    CatState.bat => (batS * msPerS).round(),
    CatState.leave => (leaveS * msPerS).round(),
  };

  /// The milliseconds in a second, for the spans above.
  static const msPerS = 1000;
}

/// Where the cat is in its visit (PRD v2 G3): it warns at the side's edge,
/// walks to the piece it wants, bats it, and runs off.
enum CatState { warning, walk, bat, leave }

/// The cat as the view draws it (S8), and the part of it a frame carries: its
/// state, its side, where it is in that side's field units, the piece it is
/// after and how much of the warning is left. A frame without one has no cat
/// out.
final class CatView {
  const CatView({required this.state, required this.side, required this.at, this.target, this.warningMs = 0});

  final CatState state;
  final PuzzleSide side;
  final Offset at;

  /// The piece it is after: the one it bats, or the one it knocks loose.
  final int? target;

  /// The warning time left, in ms: its meow's countdown. 0 after it.
  final int warningMs;

  /// The frame's `cat` entry: state, side, position to a tenth of a field
  /// unit, the warning left in ms and the piece, -1 when it is after none.
  List<Object> toJson() => [state.index, side.index, _tenths(at.dx), _tenths(at.dy), warningMs, target ?? -1];

  static CatView fromJson(List<Object?> j) => CatView(
    state: CatState.values[j[0] as int],
    side: PuzzleSide.values[j[1] as int],
    at: Offset((j[2] as num) / 10, (j[3] as num) / 10),
    warningMs: j[4] as int,
    target: j[5] == -1 ? null : j[5] as int,
  );

  /// The cat [t] of the way from this frame's place to [next]'s, its state and
  /// its piece as this frame had them: it moves, but it doesn't change its
  /// mind between two frames.
  CatView lerpTo(CatView next, double t) =>
      CatView(state: state, side: side, at: Offset.lerp(at, next.at, t)!, target: target, warningMs: warningMs);

  @override
  bool operator ==(Object other) =>
      other is CatView &&
      other.state == state &&
      other.side == side &&
      other.at == at &&
      other.target == target &&
      other.warningMs == warningMs;

  @override
  int get hashCode => Object.hash(state, side, at, target, warningMs);

  @override
  String toString() => 'CatView(${state.name}, ${side.name}, $at, target $target, ${warningMs}ms)';
}

/// What the rules ask the cat (PRD v2 G3): the game a shoo lands in, so a cat
/// on this side's board can be sent off without the puzzle rules knowing the
/// cat's own rules.
abstract interface class CatVisit {
  /// [id]'s dot at [at] on [side]'s board shoos the cat, if it is there and
  /// can still be shooed — warning or walk, and not already shooed. Returns
  /// where the cat was, for the shoo's pop-up, or null when nothing happened.
  Offset? shoo(PuzzleSide side, String id, Offset at);
}

int _tenths(double v) => (v * 10).round();
