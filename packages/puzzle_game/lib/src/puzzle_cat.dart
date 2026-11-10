part of 'game.dart';

/// What the cat does to a side's pieces (M14 a2, PRD v2 G3): a shoo it takes,
/// a loose or tray piece batted to another free spot, and a placed piece
/// knocked back into its tray. The cat's own rules — when it comes, which
/// side, which piece — are the match's cat's, which calls these from outside.
extension PuzzleCatRules on PuzzleGame {
  /// A shoos the cat instead of picking a piece up: while the cat warns or
  /// walks, a dot that reaches it sends it off, and the shooer's side gets its
  /// +1. A on the cat never picks a piece up (PRD v2 G3).
  bool _shoo(PuzzlePlayer p, List<PuzzleEvent> events) {
    final cat = this.cat;
    if (cat == null) return false;
    final at = cat.shoo(side, p.id, p.pos);
    if (at == null) return false;
    awardCatShooed(p.id, at);
    events.add(PuzzleEvent(PuzzleEventKind.catShooed, playerId: p.id, data: {'side': side.index}));
    return true;
  }

  /// The cat batted [index] to [to]: a loose or tray piece moves there and is
  /// loose from now on, out of the tray it was laid out in.
  void catBats(int index, Offset to) {
    final piece = pieces[index];
    piece
      ..state = PieceState.loose
      ..calling = false
      ..pos = to
      ..layer = _nextLayer++;
  }

  /// The cat knocked the placed piece [index] loose (PRD v2 G3, Party): it
  /// goes back to its tray spot and its outline glows until it is picked up
  /// again, and its side keeps the points it earned for it.
  void catKnocks(int index) {
    final piece = pieces[index];
    final target = piece.lockedTarget;
    if (piece.state != PieceState.locked || target == null) return;
    _filled.remove(target);
    piece
      ..state = PieceState.tray
      ..lockedTarget = null
      ..wronged = false
      ..calling = false
      ..pos = piece.trayPos
      ..angle = piece.trayAngle
      ..layer = _nextLayer++;
    _catGlow = target;
    _catGlowPiece = index;
  }
}
