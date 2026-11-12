import 'dart:ui';

import 'cat_view.dart';
import 'puzzle.dart';
import 'snapshot.dart';

/// The cat's motion, and where its head and paw are drawn in one frame (M14 bug
/// c1, PRD v2 G3), in field units of the world it visits: its head peeking in
/// over the top edge of the board area, centred above the piece it is after,
/// and its paw reaching out of the head, drawing back, swatting and drawing
/// back in.
///
/// A frame carries the cat where the rules put it ([CatView.at]) and not how
/// far into its visit it is, so the view times that itself ([CatMoments]) and
/// hands the pose the [share] of the state the cat is through. A pose is drawn
/// from the frame and the box it is given alone, so the host, a joined phone
/// and the mirror draw the same cat (S8).
final class CatPose {
  const CatPose._({
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
  /// The head slides down over the first 40% of the warning and back up over
  /// the last 60% of the leave, and stays at rest in between.
  factory CatPose.of(CatView cat, {required PuzzleSnapshot board, required PuzzleField field, double share = 1}) {
    final area = field.board;
    final width = area.width * headWidthShare;
    final height = width * _headHeightShare;
    final aim = _aimAt(cat, board);
    final centre = Offset(aim.dx.clamp(area.left + width / 2, area.right - width / 2), area.top + height / 2);
    final peek = switch (cat.state) {
      CatState.warning => _ease((share / _peekShare).clamp(0.0, 1.0)),
      CatState.leave => 1 - _ease((share / _leaveShare).clamp(0.0, 1.0)),
      _ => 1.0,
    };
    final head = Rect.fromCenter(center: centre + Offset(0, (peek - 1) * height), width: width, height: height);
    final side = aim.dx < centre.dx ? -1.0 : 1.0;
    final shoulder = Offset(centre.dx + side * width * _shoulderSideShare, centre.dy + height * _shoulderDownShare);
    final tip = switch (cat.state) {
      CatState.warning => null,
      CatState.walk => _reach(shoulder, aim, width, share),
      CatState.bat => aim,
      CatState.leave => Offset.lerp(cat.at, shoulder, _ease(share)),
    };
    return CatPose._(
      head: head,
      shoulder: shoulder,
      gaze: _gaze(aim, centre, width),
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

  /// The head's box, ears and all: [headWidthShare] of the board area's width,
  /// kept inside the area and hung from its top edge, less the part still above
  /// it as the cat slides in or out.
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
