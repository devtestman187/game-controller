import 'puzzle_values.dart';
import 'snapshot.dart';

/// How long a piece that has just locked boings, in milliseconds (design
/// section 5: 150 ms) — and how big it grows with it.
const boingDurationMs = 150;
const boingPeakScale = 1.12;

/// How long a piece that has just been dropped wrong wobbles, in milliseconds
/// (design section 5: 120 ms) and how far it turns, in degrees each way.
const wobbleDurationMs = 120;
const wobblePeakDeg = 3.0;

/// How long the ✓ sparkle of a piece that has just locked lasts, in
/// milliseconds (design section 5: 400 ms), how much it grows, and how much of
/// it is left at the end.
const sparkleDurationMs = 400;
const sparklePeakGrow = 0.6;

/// When each piece last turned `locked` or `wrong`, as the view saw it (design
/// section 5): the board's boing, its ✓ sparkle and its wobble are drawn from
/// this and nothing else, so a joined phone shows the same motion as the host
/// with nothing added to the protocol.
///
/// It is fed each new snapshot with the time it arrived, and answers how long
/// ago a piece changed. A piece already in one of those states in the first
/// snapshot the view sees is not noted (the view was built mid-round), and a
/// board whose puzzle changes is a new round: its notes start again.
///
/// It is a rules-side value: no Flutter and no look (design section 7).
final class PieceMoments {
  PieceMoments();

  /// What has been seen per board, left then right; a board the view hasn't
  /// drawn yet has none.
  final List<_BoardMoments?> _boards = [];

  /// Notes every piece of [snapshot] that has turned `locked` or `wrong`
  /// since the last snapshot, at [nowMs] on the view's clock.
  void observe(MatchSnapshot snapshot, int nowMs) {
    for (final (index, board) in snapshot.boards.indexed) {
      while (_boards.length <= index) {
        _boards.add(null);
      }
      final seen = _boards[index];
      if (seen == null || seen.puzzleId != board.puzzleId) {
        // The first look at this board, or a new round on it: nothing has
        // just happened that this view could have seen.
        _boards[index] = _BoardMoments(board.puzzleId, board.pieces.map((p) => p.state).toList());
      } else {
        seen.note(board, nowMs);
      }
    }
  }

  /// The milliseconds since piece [piece] of board [board] turned `locked` or
  /// `wrong`, or null when it hasn't while this view watched (or is neither
  /// state now).
  int? ageMs(int board, int piece, int nowMs) {
    final seen = board < _boards.length ? _boards[board] : null;
    if (seen == null || piece >= seen.changedAtMs.length) return null;
    final at = seen.changedAtMs[piece];
    return at == null ? null : nowMs - at;
  }

  /// The scale a piece that locked [ageMs] ago is drawn at: 1, up to
  /// [boingPeakScale] half way, and 1 again at [boingDurationMs] (design
  /// section 5). Still with the effects off (design D8).
  static double boingScale(int ageMs, {bool effects = true}) {
    if (!effects || ageMs <= 0 || ageMs >= boingDurationMs) return 1;
    final half = boingDurationMs ~/ 2;
    final away = ageMs <= half ? ageMs / half : (boingDurationMs - ageMs) / half;
    return 1 + (boingPeakScale - 1) * away;
  }

  /// The degrees a piece that was dropped wrong [ageMs] ago is turned by:
  /// [wobblePeakDeg], then its reverse, then none, in three equal parts of
  /// [wobbleDurationMs] (design section 5). Still with the effects off.
  static double wobbleDeg(int ageMs, {bool effects = true}) {
    if (!effects || ageMs < 0 || ageMs >= wobbleDurationMs) return 0;
    final third = wobbleDurationMs ~/ 3;
    if (ageMs < third) return wobblePeakDeg;
    return ageMs < 2 * third ? -wobblePeakDeg : 0;
  }

  /// How far the ✓ sparkle of a piece that locked [ageMs] ago has grown, 0 to
  /// [sparklePeakGrow], over [sparkleDurationMs] (design section 5). Still with
  /// the effects off.
  static double sparkleGrow(int ageMs, {bool effects = true}) =>
      !effects || ageMs < 0 || ageMs >= sparkleDurationMs ? 0 : sparklePeakGrow * ageMs / sparkleDurationMs;

  /// How much of that sparkle is left, 1 at the lock down to 0 at
  /// [sparkleDurationMs]. Still with the effects off.
  static double sparkleLeft(int ageMs, {bool effects = true}) =>
      !effects || ageMs < 0 || ageMs >= sparkleDurationMs ? 0 : 1 - ageMs / sparkleDurationMs;
}

/// One board's pieces as last seen, and when each of them changed.
final class _BoardMoments {
  _BoardMoments(this.puzzleId, this.states) : changedAtMs = List<int?>.filled(states.length, null);

  final String puzzleId;

  /// Each piece's state in the snapshot before.
  final List<PieceState> states;

  /// When each piece turned `locked` or `wrong`, on the view's clock.
  final List<int?> changedAtMs;

  void note(PuzzleSnapshot board, int nowMs) {
    for (final (index, piece) in board.pieces.indexed) {
      if (index >= states.length) {
        states.add(piece.state);
        changedAtMs.add(piece.state == PieceState.locked || piece.state == PieceState.wrong ? nowMs : null);
        continue;
      }
      final before = states[index];
      if (before == piece.state) continue;
      states[index] = piece.state;
      changedAtMs[index] = piece.state == PieceState.locked || piece.state == PieceState.wrong ? nowMs : null;
    }
  }
}
