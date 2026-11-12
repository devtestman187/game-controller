part of 'view.dart';

/// How far an empty slot is mixed from the board toward `onBackground` — ink
/// in Sunny, white in Night — so it is a shade darker in one look and a shade
/// lighter in the other (design section 5, decided at device test 3).
const _slotMix = 0.04;

/// The most an empty slot on Easy is tinted with its own piece's colour, and
/// how much stronger a ready target's fill is, so it reads as ready.
const _slotEasyTint = 0.1;
const _targetReadyFill = 0.45;

/// How much wider a ready or hinted target's outline is than the look's.
const _targetEdgeShare = 1.5;

/// How strongly a hint's fill glows, and how far the glow spreads, in the
/// look's pixels.
const _hintGlowAlpha = 0.5;
const _hintGlowPx = 2.5;

/// An empty target's slot and its edge (design section 5): the recess in the
/// mat, Easy's tint, a ready target's fill, a hint's glow, and the dashed edge
/// that waits for a piece.
extension _SlotPaint on PuzzlePainter {
  /// The colour of an empty slot: the board's, a shade toward `onBackground`,
  /// so a slot is a little darker than the cream mat and a little lighter than
  /// the grape one (design section 5, decided at device test 3).
  Color get _slotFill => Color.lerp(_colours.board, _colours.onBackground, _slotMix)!;

  /// An empty target's slot: the recess in the mat, Easy's tint of the piece's
  /// own colour, a ready target's stronger one and a hint's glow, all drawn
  /// under the picture. A ready target and a hint keep their meaning, in `good`
  /// and `focus`.
  void _slot(Canvas canvas, int i, double scale, ToyShapeStyle style) {
    final spec = puzzle.pieces[i];
    final path = _path(spec.shape, _targetAt(i), spec.targetAngle);
    toySunkenSlot(canvas, path, _slotFill, style);
    final ready = s.readyTargets.contains(i);
    if (ready || puzzle.level.colouredOutlines) {
      final fill = puzzle.level.colouredOutlines ? Color(spec.color) : _colours.targetNeutral;
      canvas.drawPath(path, Paint()..color = fill.withValues(alpha: ready ? _targetReadyFill : _slotEasyTint));
    }
    if (s.hintTargets.contains(i)) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _colours.focus.withValues(alpha: _hintGlowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _hintGlowPx / scale),
      );
    }
  }

  /// An empty target's edge: dashed in the ink while it waits, square-capped
  /// and in `good` and wider when ready, in `focus` when hinted.
  ///
  /// A look-alike's slot waits in its own piece's colour instead, so a player
  /// can tell two shapes apart that a turn cannot exchange (M14 p1). The
  /// colour is a piece colour, so it keeps [pieceBoardDistance] from the board
  /// in both looks, which the rule book checks for every puzzle.
  void _outline(Canvas canvas, int i, double scale, ToyShapeStyle style) {
    final spec = puzzle.pieces[i];
    final path = _path(spec.shape, _targetAt(i), spec.targetAngle);
    final ready = s.readyTargets.contains(i);
    final hint = s.hintTargets.contains(i);
    final width = look.sizes.outlineWidth / scale * (ready || hint ? _targetEdgeShare : 1);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      // The dashes end square: round caps would close their gaps and make the
      // target's edge read as solid, as it did before device test 3.
      ..strokeCap = ready || hint ? StrokeCap.round : StrokeCap.butt
      ..color = hint
          ? _colours.focus
          : ready
          ? _colours.good
          : puzzle.twins.lookAlikes.contains(i)
          ? Color(spec.color)
          : _colours.ink;
    if (ready || hint) {
      canvas.drawPath(path, edge);
    } else {
      // The look's own dashed edge, in the painter's units.
      paintDashedEdge(canvas, path, edge, on: toyDashOn / scale, off: toyDashOff / scale);
    }
  }
}
