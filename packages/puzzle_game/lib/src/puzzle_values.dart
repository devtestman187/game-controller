import 'dart:ui';

/// A side of the split screen, chosen on the join screen (PRD v2 T13). The
/// rules count each side's points, so a game knows the side its players play
/// for (M14 a1).
enum PuzzleSide { left, right }

/// Where a piece is.
enum PieceState {
  /// In the tray, never moved yet.
  tray,

  /// Put down somewhere off the board, or on the board but not yet dropped
  /// as an answer (a player moved it away).
  loose,

  /// Carried by a player (or two, with a big piece).
  held,

  /// Snapped into its outline: it can't move any more.
  locked,

  /// Dropped on the board in a wrong spot: red, with a ✗. Counts as not
  /// placed; anyone can pick it up again.
  wrong,
}

/// What happened, for haptics, sounds and analytics.
enum PuzzleEventKind { pickup, snap, wrong, dropReady, tick, timeUp, finished, help, catWarning, catBat, catShooed }

final class PuzzleEvent {
  const PuzzleEvent(this.kind, {this.playerId, this.data = const {}});

  final PuzzleEventKind kind;

  /// Whose action it was (for [PuzzleEventKind.help], the teammate being
  /// called); null for the clock (tick, time-up, finished).
  final String? playerId;

  /// For analytics: errors at a drop, the finishing time, …
  final Map<String, Object?> data;

  @override
  String toString() => '${kind.name}${playerId == null ? '' : ' ($playerId)'} $data';
}

/// One piece as it is now.
class PieceRuntime {
  PieceRuntime(this.index, this.pos, this.angle, this.layer);

  final int index;
  Offset pos;
  double angle;
  PieceState state = PieceState.tray;

  /// Where it lies in the pile: pieces put down later have a higher layer and
  /// are drawn, and picked up, above the others.
  int layer;

  /// Who carries it: one player, or two teammates sharing a big piece.
  final carriers = <String>[];
  int? lockedTarget;

  /// A big piece carried alone calls the free teammate: its edge flashes
  /// toward them.
  bool calling = false;

  /// Where the tray laid it out and at what angle: the cat knocks a placed
  /// piece back to this spot (M14 a2).
  Offset trayPos = Offset.zero;
  double trayAngle = 0;

  /// When it was snapped into its outline, in the round's seconds: the cat
  /// leaves a piece placed a moment ago alone (M14 a2).
  double placedAtS = 0;

  /// It was dropped wrong once: its snap is a try again, worth
  /// [PuzzlePoints.wrongSnap] instead of [PuzzlePoints.snap] (M14 a1).
  bool wronged = false;

  /// It was placed in its outline before, even if the cat knocked it back
  /// out: only the first place earns the first try's points (M14 r5 13).
  bool placedOnce = false;

  /// The first carrier.
  String? get heldBy => carriers.firstOrNull;
}

/// How the round ended for one side.
final class PuzzleResult {
  const PuzzleResult({required this.finished, required this.placed, required this.total, this.timeS});

  /// All pieces placed before time ran out.
  final bool finished;
  final int placed;
  final int total;

  /// The finishing time, when [finished].
  final double? timeS;
}

/// [stopped]: the round ended early because the other side finished first.
enum PuzzlePhase { playing, finished, timeUp, stopped }
