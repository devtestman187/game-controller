import 'dart:ui';

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
enum PuzzleEventKind { pickup, snap, wrong, dropReady, tick, timeUp, finished, help }

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
