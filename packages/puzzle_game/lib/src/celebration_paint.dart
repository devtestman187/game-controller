part of 'view.dart';

/// How thick the glow's warm rim is drawn against its blur, in blur radii: wide
/// and soft, so it never draws a hard line over the picture's own edge.
const _glowStrokeShare = 0.9;

/// How thick a star's edge is against the look's outline, so a star a few units
/// across still has a crisp edge.
const _starEdgeShare = 1.0;

/// How round a confetto's corners are, as a share of its shorter side, and how
/// thick its ink edge is at most, as a share of that side: the look's outline
/// would swallow a bit this small.
const _confettoCornerShare = 0.18;
const _confettoEdgeShare = 0.12;

/// The finish celebration's drawing (design section 3a): the warm rim round the
/// finished picture, the ring of stars and the falling confetti. What it draws
/// at each moment is [Celebration]'s; this draws it round the board the view
/// paints, from the finish age [PieceMoments] keeps.
extension _FinishPaint on PuzzlePainter {
  /// The glow (design 3a item 3): a soft warm rim round every placed piece,
  /// under the picture, breathing once over the moment — a still rim with the
  /// effects off (G5).
  void _paintGlow(Canvas canvas, double px) {
    final age = _finishAge;
    if (age == null) return;
    final alpha = Celebration.glowAlpha(age, effects: look.effects);
    if (alpha <= 0) return;
    final blur = Celebration.glowBlur / px;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = blur * _glowStrokeShare
      ..color = _colours.star.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    for (final (i, p) in s.pieces.indexed) {
      if (p.state != PieceState.locked) continue;
      canvas.drawPath(_path(puzzle.pieces[i].shape, Offset(p.x, p.y), p.angle), paint);
    }
  }

  /// The ring of stars (design 3a item 2): a gold star round the board's edge,
  /// four in fourteen of them in the pale paper, all outside the picture. With
  /// the effects off they stand still until the moment ends.
  void _paintStars(Canvas canvas, double px) {
    final age = _finishAge;
    if (age == null) return;
    final edge = look.sizes.outlineWidth / px * _starEdgeShare;
    for (final star in Celebration.starsOf(age, field.board, effects: look.effects)) {
      // The same star the awards draw (points_paint), so round the picture is
      // the star of the party night's own marks.
      final path = _starPath(star.at, star.radius);
      final fill = star.bright ? _colours.focus : _colours.paper;
      final stroke = star.bright ? _colours.ink : _colours.focus;
      canvas
        ..drawPath(path, Paint()..color = fill.withValues(alpha: star.alpha))
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = edge
            ..color = stroke.withValues(alpha: star.alpha),
        );
    }
  }

  /// The confetti (design 3a item 2): bits in the players' colours falling round
  /// the board, outside the picture, turning as they go. With the effects off
  /// there is none (G5: no motion).
  void _paintConfetti(Canvas canvas, double px) {
    final age = _finishAge;
    if (age == null) return;
    final edge = min(look.sizes.outlineWidth / px, Celebration.confettiTall * _confettoEdgeShare);
    for (final bit in Celebration.confettiOf(age, field.board, effects: look.effects)) {
      final rect = Rect.fromCenter(center: Offset.zero, width: bit.wide, height: bit.tall);
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(bit.tall * _confettoCornerShare));
      canvas
        ..save()
        ..translate(bit.at.dx, bit.at.dy)
        ..rotate(bit.angleDeg * pi / 180)
        ..drawRRect(shape, Paint()..color = _colours.player(bit.colour).withValues(alpha: bit.alpha))
        ..drawRRect(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = edge
            ..color = _colours.ink.withValues(alpha: bit.alpha),
        )
        ..restore();
    }
  }
}
