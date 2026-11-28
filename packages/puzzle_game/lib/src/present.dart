import 'puzzle_values.dart';

/// The present as the view sees it (M17 r3a): the hot-potato present is batted between the sides, its fuse runs
/// down, and it pops on the slow side. A present never takes a piece. A frame without one has no present out.
final class PresentState {
  const PresentState({required this.holder, required this.fuseMs, required this.fuseTotalMs, this.popped = false});

  /// The side it is with now: the side that is about to bat it on, or the one it pops on.
  final PuzzleSide holder;

  /// The fuse left, in ms: it runs down while the present is batted about. 0 when it pops.
  final int fuseMs;

  /// The fuse it started with, in ms, so the view can draw how much is left.
  final int fuseTotalMs;

  /// True once the present has popped on the slow side.
  final bool popped;

  /// The frame's `pr` entry: holder, fuse left and fuse total in ms, and whether it has popped (1) or not (0).
  List<Object> toJson() => [holder.index, fuseMs, fuseTotalMs, popped ? 1 : 0];

  static PresentState fromJson(List<Object?> j) => PresentState(
    holder: PuzzleSide.values[j[0] as int],
    fuseMs: j[1] as int,
    fuseTotalMs: j[2] as int,
    popped: j[3] == 1,
  );

  /// The present [t] of the way from this frame's state to [next]'s. The fuse runs down between the two. The holder,
  /// the fuse total and whether it has popped stay this frame's until halfway, then take [next]'s, so a pop shows
  /// on the frame it happens.
  PresentState lerpTo(PresentState next, double t) => PresentState(
    holder: t < 0.5 ? holder : next.holder,
    fuseMs: (fuseMs + (next.fuseMs - fuseMs) * t).round(),
    fuseTotalMs: t < 0.5 ? fuseTotalMs : next.fuseTotalMs,
    popped: t < 0.5 ? popped : next.popped,
  );

  @override
  bool operator ==(Object other) =>
      other is PresentState &&
      other.holder == holder &&
      other.fuseMs == fuseMs &&
      other.fuseTotalMs == fuseTotalMs &&
      other.popped == popped;

  @override
  int get hashCode => Object.hash(holder, fuseMs, fuseTotalMs, popped);

  @override
  String toString() => 'PresentState(${holder.name}, ${fuseMs}ms of $fuseTotalMs, popped $popped)';
}
