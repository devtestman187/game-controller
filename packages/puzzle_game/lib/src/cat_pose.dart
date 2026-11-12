import 'dart:ui';

import 'cat_view.dart';
import 'puzzle.dart';
import 'snapshot.dart';

/// The cat's motion, and where its head and paw are drawn in one frame (M14 bug
/// c1, PRD v2 G3; M14 bugs2 1), in field units of the world it visits: its head
/// hanging from the top edge of that player's own area, centred above the piece
/// it is after, and its paw reaching out of the head, drawing back, swatting and
/// drawing back in with the head it came out of.
///
/// A frame carries the cat where the rules put it ([CatView.at]) and not how
/// far into its visit it is, so the view times that itself ([CatMoments]) and
/// hands the pose the [share] of the state the cat is through. A pose is drawn
/// from the frame and the box it is given alone, so the host, a joined phone
/// and the mirror draw the same cat (S8).
final class CatPose {
  const CatPose._({
    required this.area,
    required this.head,
    required this.shoulder,
    required this.gaze,
    required this.aim,
    this.tip,
    this.swat,
  });

  /// [cat]'s pose on [board] in [field], [share] of the way through its state:
  /// 0 at that state's first frame and 1 at its last, so a still frame passes 1.
  ///
  /// The head hangs from the top edge of [area], the box the player sees, and
  /// slides down over the first 40% of the warning and back up over the last
  /// 60% of the leave, staying at rest in between. Its bottom is kept above the
  /// piece it is after, so it never covers that piece; where the room above the
  /// piece is under [_minHeadShare] of the head's size, it stops shrinking there
  /// and the head overlaps the board's top edge instead (M14 bugs2 1).
  factory CatPose.of(
    CatView cat, {
    required PuzzleSnapshot board,
    required PuzzleField field,
    Rect? area,
    double share = 1,
  }) {
    final own = area ?? (Offset.zero & field.size);
    final column = field.board;
    final width = column.width * headWidthShare;
    final full = width * _headHeightShare;
    final aim = _aimAt(cat, board);
    // The head shrunk to the room between the area's top and the piece, but
    // never under [_minHeadShare] of its size, so its face stays readable.
    final shrink = ((aim.dy - own.top) / full).clamp(_minHeadShare, 1.0);
    final headWidth = width * shrink;
    final height = full * shrink;
    final centre = Offset(
      aim.dx.clamp(column.left + headWidth / 2, column.right - headWidth / 2),
      own.top + height / 2,
    );
    final peek = switch (cat.state) {
      CatState.warning => _ease((share / _peekShare).clamp(0.0, 1.0)),
      CatState.leave => 1 - _ease((share / _leaveShare).clamp(0.0, 1.0)),
      _ => 1.0,
    };
    final head = Rect.fromCenter(center: centre + Offset(0, (peek - 1) * height), width: headWidth, height: height);
    final side = aim.dx < centre.dx ? -1.0 : 1.0;
    // The shoulder is part of the head, so the paw goes up with it as it leaves
    // (the bugs1 review's must): the last of the leave draws no paw on the board.
    final shoulder = Offset(
      head.center.dx + side * headWidth * _shoulderSideShare,
      head.center.dy + height * _shoulderDownShare,
    );
    final tip = switch (cat.state) {
      CatState.warning => null,
      CatState.walk => _reach(shoulder, aim, headWidth, share),
      CatState.bat => aim,
      CatState.leave => Offset.lerp(cat.at, shoulder, _ease(share)),
    };
    return CatPose._(
      area: own,
      head: head,
      shoulder: shoulder,
      gaze: _gaze(aim, centre, headWidth),
      aim: aim,
      tip: tip,
      swat: cat.state == CatState.bat ? share : null,
    );
  }

  /// The head's width as a share of the board area's width: about a quarter of
  /// it (the owner's device test, Nov 12, 2026), which reads on a TV and on a
  /// phone in landscape.
  static const headWidthShare = 0.25;

  /// How tall the head is against its width, ears and all.
  static const _headHeightShare = 0.92;

  /// The smallest the head shrinks to, as a share of that size, where the piece
  /// it is after sits high: below it the face stops reading (M14 bugs2 1).
  static const _minHeadShare = 0.8;

  /// The share of the warning the head spends sliding in, and of the leave it
  /// spends sliding back up.
  static const _peekShare = 0.4;
  static const _leaveShare = 0.6;

  /// How far below its middle the paw comes out of the head, and how far to the
  /// side of it, as shares of the head's height and width: the foreleg's
  /// shoulder.
  static const _shoulderSideShare = 0.26;
  static const _shoulderDownShare = 0.34;

  /// How much of the reach the paw spends drawing back for the swat, and how
  /// far back from the piece it draws, as a share of the head's width.
  static const _drawBackShare = 0.25;
  static const _drawBack = 0.18;

  /// How far the pupils turn toward the piece, as a share of the head's width.
  static const _gazeShare = 0.06;

  /// The box the player sees the cat in, in field units: the whole world of one
  /// board, a split screen's half, or the mirror's own box. The head hangs from
  /// its top edge and the head and the paw are drawn only inside it.
  final Rect area;

  /// The head's box, ears and all: up to [headWidthShare] of the board area's
  /// width, kept over the board's columns and hung from [area]'s top edge, less
  /// the part still above it as the cat slides in or out.
  final Rect head;

  /// Where the paw comes out of the head: under its lower edge, on the side the
  /// piece lies on.
  final Offset shoulder;

  /// How far the pupils are turned toward [aim]: the eyes follow the piece.
  final Offset gaze;

  /// The point the cat works on: the middle of the piece it is after while it
  /// warns and walks, and the place its paw struck once it has. During the
  /// warning and the walk a bat may not have moved the piece yet, and while the
  /// cat leaves the piece is behind it.
  final Offset aim;

  /// Where the paw's tip is drawn mid-reach; null while no paw is out (the
  /// warning).
  final Offset? tip;

  /// How far through the swat the cat is, 0 to 1, while its paw has just hit;
  /// null at every other moment.
  final double? swat;
}

/// The piece [cat] is after, from [board], or where the cat itself is when that
/// piece is not in the frame: the paw and the head still have a point to go by.
Offset _aimAt(CatView cat, PuzzleSnapshot board) {
  if (cat.state == CatState.bat || cat.state == CatState.leave) return cat.at;
  final target = cat.target;
  if (target == null || target >= board.pieces.length) return cat.at;
  final piece = board.pieces[target];
  return Offset(piece.x, piece.y);
}

/// The pupils' turn toward [aim] from the head's [centre]: a fixed shift, so an
/// eye never leaves the face.
Offset _gaze(Offset aim, Offset centre, double width) {
  final toward = aim - centre;
  final distance = toward.distance;
  return distance == 0 ? Offset.zero : toward / distance * (width * CatPose._gazeShare);
}

/// The paw's tip [share] of the way through its reach from [shoulder] to [aim]:
/// the leg stretches over the first 75% of the state and draws back over the
/// last 25% by [_drawBack] of the head's [width], so the swat lands on the next
/// frame, where the piece moves.
Offset _reach(Offset shoulder, Offset aim, double width, double share) {
  final towards = aim - shoulder;
  final distance = towards.distance;
  final approach = 1 - CatPose._drawBackShare;
  if (share <= approach) return Offset.lerp(shoulder, aim, _ease(share / approach))!;
  if (distance == 0) return aim;
  final back = (share - approach) / CatPose._drawBackShare;
  return aim - towards / distance * (width * CatPose._drawBack * back);
}

/// [t] eased out: fast at the start, slowing to its end.
double _ease(double t) => t * (2 - t);
