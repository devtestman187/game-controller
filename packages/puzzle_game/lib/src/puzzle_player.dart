part of 'game.dart';

/// One player's dot and what it carries.
class PuzzlePlayer {
  PuzzlePlayer(this.id, this.number, this.pos);

  final String id;
  final int number;
  Offset pos;
  int? held;
  bool _aDown = false;
  double _holdS = 0;
  int? readyTarget;
  int? hintTarget;
  int _lastTurn = 0;

  /// Where the dot holds a piece it carries, from its middle, as it was when the piece was taken up (s14).
  Offset _grab = Offset.zero;

  /// Until the next help call while carrying a big piece alone.
  double _helpS = 0;

  // Metrics (PRD v2 "Puzzle results").
  int pickups = 0;
  int snaps = 0;
  int wrongDrops = 0;
  double rotatingS = 0;
  int overshoots = 0;

  /// Help calls made while carrying a big piece alone, how many such carries
  /// were started, and the time spent on them.
  int helpCalls = 0;
  int soloBigCarries = 0;
  double soloBigS = 0;
}
