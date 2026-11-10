import 'dart:ui';

import 'puzzle_values.dart';

/// The points the rules count (party-night.md §3, PRD v2 G1 and G2): the
/// awards below, each times the round's `PuzzleSettings.pointsScale`, so a
/// night's last round is worth double (N3). Points only ever go up.
abstract final class PuzzlePoints {
  /// A piece snapped on the first try, +2.
  static const snap = 2;

  /// A piece snapped after a wrong drop of that piece, the try again, +1.
  static const wrongSnap = 1;

  /// A big piece carried home by two teammates, +1.
  static const together = 1;

  /// The picture finished: first in a race, or before time-up on one board,
  /// +5. Both sides of a race that finish in the same frame are a draw and
  /// keep theirs.
  static const finish = 5;

  /// Shooing the cat, +1, to the shooer's side (job a2 calls it at the cat).
  static const catShooed = 1;

  /// How long a pop-up lives, in milliseconds: its rise and its fade
  /// (design section 3).
  static const popupMs = 1200;

  /// How far a pop-up rises, in screen px.
  static const risePx = 24;

  /// The most pop-ups one side can make in one frame: two players each snap a
  /// big piece carried by two (two awards each) and the picture is finished.
  static const maxPopups = 5;

  /// How far a pop-up [ageMs] old has risen, in screen px: [risePx] over
  /// [popupMs]. Still with the effects off (G5): it appears and goes where it
  /// is.
  static double risenPx(int ageMs, {bool effects = true}) =>
      !effects || ageMs <= 0 ? 0 : risePx * (ageMs / popupMs).clamp(0.0, 1.0);

  /// How much of a pop-up [ageMs] old is left: 1 at the start, 0 at
  /// [popupMs]. Whole while the effects are off (G5).
  static double left(int ageMs, {bool effects = true}) =>
      !effects || ageMs <= 0 ? 1 : (1 - ageMs / popupMs).clamp(0.0, 1.0);
}

/// What a pop-up draws beside its number, so the award reads by shape and not
/// only by colour (G5): the star of a points award, the flag of a finished
/// picture.
enum PuzzleIcon { star, flag }

/// One pop-up as the view draws it (party-night §3): whose side earned it,
/// where it happened in the board's field units, how much it was worth (the
/// scale already applied) and how long ago it started.
final class PuzzlePopup {
  const PuzzlePopup({
    required this.side,
    required this.place,
    required this.amount,
    required this.ageMs,
    this.icon = PuzzleIcon.star,
  });

  final PuzzleSide side;
  final Offset place;
  final int amount;
  final int ageMs;
  final PuzzleIcon icon;
}
