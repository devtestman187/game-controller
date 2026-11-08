part of 'view.dart';

class PuzzlePainter extends CustomPainter {
  PuzzlePainter(this.puzzle, this.s, {this.timeLimitS, this.field = PuzzleField.single, this.hud = true});

  final Puzzle puzzle;
  final PuzzleSnapshot s;
  final int? timeLimitS;

  /// The side's world: the one-board layout or a half of the split screen.
  final PuzzleField field;

  /// The clock and the count along the top (the split screen draws its own).
  final bool hud;

  static const _tray = Color(0xFF1C222B);
  static const _outlineGrey = Color(0xFF9AA5B1);

  Offset _targetAt(int i) => field.origin + puzzle.pieces[i].target;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    final f = fieldIn(size, field.size);
    canvas
      ..save()
      ..translate(f.origin.dx, f.origin.dy)
      ..scale(f.scale);
    canvas.clipRect(Offset.zero & field.size);

    _panels(canvas);
    // The picture in its own order: each target shows the piece locked in
    // it, or its outline, so a door's outline stays on top of a placed wall.
    final lockedIn = {
      for (final (i, p) in s.pieces.indexed)
        if (p.state == PieceState.locked) _targetOf(s.pieces[i]): i,
    };
    for (final t in Iterable<int>.generate(puzzle.pieces.length)) {
      final piece = lockedIn[t];
      piece != null ? _piece(canvas, piece) : _outline(canvas, t);
    }
    // Then loose pieces lowest layer first, so the pile looks as it lies,
    // carried pieces, and the dots on top of everything.
    for (final i in s.order) {
      final p = s.pieces[i];
      if (p.state != PieceState.locked && p.state != PieceState.held) _piece(canvas, i);
    }
    for (final (i, p) in s.pieces.indexed) {
      if (p.state == PieceState.held) _piece(canvas, i);
    }
    for (final p in s.players) {
      _dot(canvas, p);
    }
    if (hud) _hud(canvas);
    canvas.restore();
  }

  void _panels(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(field.board.inflate(1.5), const Radius.circular(2)),
      Paint()..color = _board,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(field.tray, const Radius.circular(2)), Paint()..color = _tray);
  }

  Path _path(PieceShape shape, Offset at, double angle, {double scale = 1}) {
    if (shape.circle) return Path()..addOval(Rect.fromCircle(center: at, radius: shape.radius * scale));
    final points = shape.placed(at, angle);
    return Path()..addPolygon(scale == 1 ? points : [for (final p in points) at + (p - at) * scale], true);
  }

  void _outline(Canvas canvas, int i) {
    final spec = puzzle.pieces[i];
    final path = _path(spec.shape, _targetAt(i), spec.targetAngle);
    final ready = s.readyTargets.contains(i);
    final hint = s.hintTargets.contains(i);
    final colour = puzzle.level.colouredOutlines ? Color(spec.color) : _outlineGrey;
    if (hint) {
      canvas.drawPath(
        path,
        Paint()
          ..color = colour.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
    canvas.drawPath(path, Paint()..color = colour.withValues(alpha: ready ? 0.45 : 0.16));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ready ? 0.9 : 0.5
        ..color = ready ? Colors.white : colour.withValues(alpha: 0.85),
    );
  }

  /// The outline a locked piece sits in: the nearest of its kind.
  int _targetOf(PieceView p) {
    final at = Offset(p.x, p.y);
    var best = 0;
    var bestDistance = double.infinity;
    for (final i in Iterable<int>.generate(puzzle.pieces.length)) {
      final d = (_targetAt(i) - at).distance;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  void _piece(Canvas canvas, int i) {
    final p = s.pieces[i];
    final spec = puzzle.pieces[i];
    final at = Offset(p.x, p.y);
    // A piece still in the tray is smaller on the split screen; from its
    // first pickup on it is full size.
    final scale = p.state == PieceState.tray ? field.trayScale : 1.0;
    final path = _path(spec.shape, at, p.angle, scale: scale);
    final wrong = p.state == PieceState.wrong;
    canvas.drawPath(path, Paint()..color = Color(spec.color));
    if (wrong) canvas.drawPath(path, Paint()..color = _wrong.withValues(alpha: 0.55));
    final holder = p.holder;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = holder != null ? 0.8 : 0.4
        ..color = holder != null
            ? Color(playerColor(holder))
            : wrong
            ? _wrong
            : Colors.black.withValues(alpha: 0.5),
    );
    if (p.calling) _callFlash(canvas, path, at, p);
    // Right and wrong also show as a mark, not only a colour.
    if (wrong) _mark(canvas, at, '✗', _wrong);
    if (p.state == PieceState.locked && !_insideOpenTarget(at)) _mark(canvas, at, '✓', _right, small: true);
  }

  /// A big piece carried alone flashes its edge toward each free teammate,
  /// in their colour, about twice a second.
  void _callFlash(Canvas canvas, Path path, Offset at, PieceView p) {
    final pulse = 0.5 + 0.5 * sin(s.timeLeftMs / 1000 * 2 * pi * 2);
    final reach = field.size.longestSide * 2;
    for (final mate in s.players) {
      if (p.holders.contains(mate.number)) continue;
      final toward = Offset(mate.x, mate.y) - at;
      if (toward.distance < 0.01) continue;
      final dir = toward / toward.distance;
      final side = Offset(-dir.dy, dir.dx);
      // The half of the piece facing the teammate.
      final half = Path()
        ..addPolygon([
          at + side * reach,
          at + side * reach + dir * reach,
          at - side * reach + dir * reach,
          at - side * reach,
        ], true);
      canvas
        ..save()
        ..clipPath(half);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Color(playerColor(mate.number)).withValues(alpha: 0.35 + 0.65 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
      canvas.restore();
    }
  }

  /// Whether [at] is inside the outline of a target nothing is locked in
  /// yet (a wall's ✓ would otherwise sit in the empty door).
  bool _insideOpenTarget(Offset at) {
    final filled = {
      for (final p in s.pieces)
        if (p.state == PieceState.locked) _targetOf(p),
    };
    for (final (i, spec) in puzzle.pieces.indexed) {
      if (!filled.contains(i) && _path(spec.shape, _targetAt(i), spec.targetAngle).contains(at)) return true;
    }
    return false;
  }

  void _mark(Canvas canvas, Offset at, String mark, Color color, {bool small = false}) {
    final size = small ? 3.2 : 5.0;
    canvas.drawCircle(at, size * 0.62, Paint()..color = Colors.black.withValues(alpha: 0.55));
    _text(canvas, mark, at, size, color, bold: true);
  }

  void _dot(Canvas canvas, PlayerView p) {
    final at = Offset(p.x, p.y);
    const r = PuzzleGame.dotRadius;
    canvas.drawCircle(at, r, Paint()..color = Color(playerColor(p.number)));
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4
        ..color = Colors.white,
    );
    _text(canvas, '${p.number}', at, r * 1.2, _background, bold: true);
  }

  void _hud(Canvas canvas) {
    final secondsLeft = (s.timeLeftMs / 1000).ceil();
    final clock = '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    final warn = s.warning && s.phase == PuzzlePhase.playing;
    _text(canvas, puzzle.name, Offset(field.board.left + 2, 5), 4, Colors.white70, align: TextAlign.left);
    _text(canvas, clock, Offset(field.size.width / 2, 5), 5.5, warn ? _wrong : Colors.white, bold: true);
    _text(
      canvas,
      '${s.placed}/${s.pieces.length} placed',
      Offset(field.tray.right - 2, 5),
      4,
      Colors.white70,
      align: TextAlign.right,
    );
    final limit = timeLimitS;
    if (limit != null && limit > 0) {
      final f = (s.timeLeftMs / 1000 / limit).clamp(0.0, 1.0);
      final bar = Rect.fromLTWH(field.board.left, field.top - 1.2, (field.tray.right - field.board.left) * f, 0.8);
      canvas.drawRect(bar, Paint()..color = warn ? _wrong : Colors.white24);
    }
  }

  @override
  bool shouldRepaint(PuzzlePainter old) => !identical(old.s, s);
}

void _text(
  Canvas canvas,
  String text,
  Offset at,
  double size,
  Color color, {
  bool bold = false,
  TextAlign align = TextAlign.center,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w500, height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => -painter.width,
    _ => -painter.width / 2,
  };
  painter.paint(canvas, at + Offset(dx, -painter.height / 2));
}
