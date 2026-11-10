part of 'puzzle_screen.dart';

/// The results' headline and its colour (M13 3b): who won a race, or how a
/// one-board game went. A winning side's header takes its own colour, a draw
/// takes the focus yellow, and a one-board game is good or a caution by whether
/// it finished. The host log says the same words (m12 bug 1107e).
({String title, Color colour}) _resultsHead(ToyLook look, MatchResult result) {
  final colors = look.colors;
  if (!result.format.split) {
    return result.sides.values.single.finished
        ? (title: HostText.done, colour: colors.good)
        : (title: HostText.timeUp, colour: colors.caution);
  }
  return switch (result.winner) {
    PuzzleSide.left => (title: HostText.leftWins, colour: colors.player(1)),
    PuzzleSide.right => (title: HostText.rightWins, colour: colors.player(2)),
    null => (title: HostText.draw, colour: colors.focus),
  };
}

/// The winning side's time for the log, ` (105.9 s)`: nothing when the round
/// ran out of time or drew.
String _endTime(MatchResult result) {
  final side = result.winner ?? (result.format.split ? null : PuzzleSide.left);
  final done = side == null ? null : result.sides[side];
  if (done == null || !done.finished) return '';
  return ' (${done.timeS!.toStringAsFixed(1)} s)';
}

/// How many players a round has, in words: `1 player`, `2 players`.
String _playersLine(int count) => count == 1 ? '1 player' : '$count players';

/// The results' first button (T14): Rematch or Play again for one chosen
/// puzzle, Next puzzle after a round that played `any <level> puzzle` (m12
/// bug 1108e). The focus starts on it, so the remote's OK and a phone's A work
/// at once.
typedef _AgainButton = ({String label, IconData icon, String key, FocusNode focusNode, VoidCallback onPressed});

/// The first button (Rematch, Play again or Next puzzle), Change teams and
/// Back; a night's round has the first button alone, Next (M14 c1).
class _ResultButtons extends StatelessWidget {
  const _ResultButtons({required this.again, required this.onChangeTeams, required this.night});

  final _AgainButton again;
  final VoidCallback onChangeTeams;
  final bool night;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HostButton(
        key: Key(again.key),
        label: again.label,
        icon: again.icon,
        focusNode: again.focusNode,
        onPressed: again.onPressed,
      ),
      if (!night) ...[
        const SizedBox(width: ToySizes.space12),
        HostButton(
          key: const Key('changeTeams'),
          label: HostText.changeTeams,
          icon: Icons.group,
          onPressed: onChangeTeams,
        ),
        const SizedBox(width: ToySizes.space12),
        HostButton(
          key: const Key('resultsBack'),
          label: HostText.back,
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ],
  );
}

/// The results' photo of the picture (design 3a): how tall it is against a
/// button's height, how far it is tilted, how thick its cream border is against
/// the look's outline, how much of that outline a piece's edge takes, and how
/// its small shadow falls against the look's own.
const _photoShare = 2.0;
const _photoTiltDeg = -3.0;
const _photoBorderShare = 1.5;
const _photoEdgeShare = 0.6;
const _photoShadowShare = 0.5;
const _photoShadowAlpha = 0.25;

/// The share of the card's corner the photo's corners take, how big the photo
/// starts when it shrinks in, and how long that takes (design 3a).
const _photoCornerShare = 0.6;
const _photoFrom = 1.25;
const _photoShrink = Duration(milliseconds: 260);

/// The picture as a framed photo on the results (design 3a): the pieces as the
/// round left them on a cream frame with the ink edge, a small shadow and a
/// slight tilt. It shrinks into place when it appears; with the effects off it
/// is simply there (G5).
class _Photo extends StatelessWidget {
  const _Photo({super.key, required this.side, required this.puzzle, required this.board, required this.field});

  final PuzzleSide side;
  final Puzzle puzzle;

  /// The board as the round left it: finished, or as it stood, and the field it
  /// was played in, whose board is the picture's box in field units.
  final PuzzleSnapshot board;
  final PuzzleField field;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final height = look.sizes.buttonHeight * _photoShare;
    final size = Size(height * field.board.width / field.board.height, height);
    final motion = look.effects && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: motion ? _photoFrom : 1.0, end: 1.0),
      duration: _photoShrink,
      curve: Curves.easeOutCubic,
      builder: (context, scale, photo) => Transform.rotate(
        angle: _photoTiltDeg * pi / 180,
        child: Transform.scale(scale: scale, child: photo),
      ),
      child: CustomPaint(
        size: size,
        painter: _PhotoPainter(puzzle: puzzle, board: board, field: field, look: look),
      ),
    );
  }
}

/// The photo's drawing: the cream frame with its ink edge and small shadow, and
/// the pieces as they stood inside it, as the board drew them (design 3a).
class _PhotoPainter extends CustomPainter {
  _PhotoPainter({required this.puzzle, required this.board, required this.field, required this.look});

  final Puzzle puzzle;
  final PuzzleSnapshot board;
  final PuzzleField field;
  final ToyLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = look.colors;
    final ink = look.sizes.outlineWidth;
    final frame = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(ToySizes.cardCorner * _photoCornerShare));
    canvas
      ..drawRRect(
        frame.shift(ToySizes.shadowOffset * _photoShadowShare),
        Paint()..color = colors.ink.withValues(alpha: _photoShadowAlpha),
      )
      ..drawRRect(frame, Paint()..color = colors.paper);
    final border = ink * _photoBorderShare;
    final inner = frame.outerRect.deflate(ink + border);
    // The picture fills the field's board rect; the snapshot's pieces are in
    // field units, so the board's top left is the photo's own origin.
    final picture = field.board;
    final scale = min(inner.width / picture.width, inner.height / picture.height);
    final origin = inner.center - Offset(picture.width * scale / 2, picture.height * scale / 2);
    final style = ToyShapeStyle(
      ink: colors.ink,
      outlineWidth: ink * _photoEdgeShare,
      shadowOffset: ToySizes.shadowOffset * _photoShadowShare,
    );
    for (final (i, piece) in board.pieces.indexed) {
      if (piece.state != PieceState.locked && piece.state != PieceState.wrong) continue;
      final spec = puzzle.pieces[i];
      final at = origin + Offset((piece.x - picture.left) * scale, (piece.y - picture.top) * scale);
      toyShape(canvas, _shapeAt(spec.shape, at, piece.angle, scale), Color(spec.color), style, shade: look.shade);
    }
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ink
        ..color = colors.ink,
    );
  }

  /// A piece's outline at [at], turned by [angle] and drawn [scale] times its
  /// size, as the board's units are scaled into the photo.
  Path _shapeAt(PieceShape shape, Offset at, double angle, double scale) {
    if (shape.circle) return Path()..addOval(Rect.fromCircle(center: at, radius: shape.radius * scale));
    return Path()..addPolygon([for (final p in shape.placed(Offset.zero, angle)) at + p * scale], true);
  }

  @override
  bool shouldRepaint(_PhotoPainter old) =>
      !identical(old.board, board) ||
      old.look != look ||
      !identical(old.puzzle, puzzle) ||
      old.field.board != field.board;
}
