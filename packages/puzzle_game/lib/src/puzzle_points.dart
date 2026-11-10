part of 'game.dart';

/// One pop-up as the rules keep it: its side, its place in the field, its
/// scaled amount, its icon, and how long it has lived.
final class _Popup {
  _Popup(this.side, this.place, this.amount, this.icon);
  static const _perMs = 1000;

  final PuzzleSide side;
  final Offset place;
  final int amount;
  final PuzzleIcon icon;
  double ageS = 0;

  /// How long ago it started, in whole ms.
  int get ageMs => (ageS * _perMs).round();
}

/// The points a side earns and the pop-ups they make (M14 a1, party-night
/// section 3): every award times the round's scale, credited to the side, and
/// a pop-up where it happened so a joined phone draws the same rise and fade.
/// Public for the cat's +1, which the cat job (a2) calls from outside.
extension PuzzlePointsRules on PuzzleGame {
  /// Counts [base] points times the round's scale for this game's side, at
  /// [place], with a pop-up that lives [PuzzlePoints.popupMs]. The oldest
  /// pop-up goes when a side has more than [PuzzlePoints.maxPopups]: no frame
  /// carries more.
  void _award(int base, Offset place, PuzzleIcon icon) {
    final amount = base * settings.pointsScale;
    points += amount;
    _popups.add(_Popup(side, place, amount, icon));
    while (_popups.length > PuzzlePoints.maxPopups) {
      _popups.removeAt(0);
    }
  }

  /// A snap's points: the first try's, or the try again's, and the big piece
  /// two teammates brought home ([carriers] are the players who were holding
  /// it at the drop).
  void _awardSnap(PuzzlePlayer p, PieceRuntime piece, {required int target, required List<String> carriers}) {
    final again = piece.wronged;
    _award(again ? PuzzlePoints.wrongSnap : PuzzlePoints.snap, targetAt(target), PuzzleIcon.star);
    if (again) p.tryAgains++;
    if (!puzzle.pieces[piece.index].big || carriers.length < 2) return;
    _award(PuzzlePoints.together, targetAt(target), PuzzleIcon.star);
    // Both carriers brought it home, so both get the counter (the Best Helper
    // award counts them).
    for (final id in carriers) {
      _players[id]?.carries++;
    }
  }

  /// Ages every pop-up by [dt], and forgets the ones that have lived their
  /// [PuzzlePoints.popupMs]. A round that stands still ages nothing.
  void _agePopups(double dt) {
    for (final popup in _popups) {
      popup.ageS += dt;
    }
    _popups.removeWhere((popup) => popup.ageMs >= PuzzlePoints.popupMs);
  }

  /// The cat was shooed by [id] at [at] (job a2 calls this when the cat is
  /// batted away): +1 to their side, a pop-up at the cat, and their counter
  /// for the Cat Catcher award.
  void awardCatShooed(String id, Offset at) {
    _players[id]?.catsShooed++;
    _award(PuzzlePoints.catShooed, at, PuzzleIcon.star);
  }
}
