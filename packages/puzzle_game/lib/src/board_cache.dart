part of 'view.dart';

/// What a board's still parts were recorded from (M14 bugs3 B-016): the board,
/// the box and field it is drawn in, the canvas's scale, the look, which targets
/// are filled, ready or hinted, and whether a locked piece or the finish is
/// moving. A board's still parts are recorded again whenever any part of this
/// changes.
final class StaticBoardKey {
  const StaticBoardKey({
    required this.board,
    required this.size,
    required this.px,
    required this.field,
    required this.look,
    this.filled = const [],
    this.ready = const [],
    this.hints = const [],
    this.lockedMoving = false,
    this.glowAgeMs,
  });

  /// Which board of a match this is: 0 is the left of a race, else the one
  /// board.
  final int board;

  /// The box the board is drawn in, whose scale sets the look's sizes.
  final Size size;

  /// The canvas's scale when the board is drawn, in pixels a world unit: the
  /// still parts bake the look's sizes into it (an ink width is a pixel size
  /// divided by it), and the match paths pass a box in field units that does not
  /// change when the window does (M14 bugs3's still-key finding).
  final double px;

  /// The side's world: the one-board layout or a half of the split screen.
  final PuzzleField field;

  /// The look the board is drawn in.
  final ToyLook look;

  /// The targets a piece is locked in, in order: a locked piece never moves
  /// while it stays locked (the cat knocks one loose, which changes this), so
  /// its target stands for it.
  final List<int> filled;

  /// The targets a player is being shown, and the ones ready for a drop, in
  /// order: their slots and edges are drawn differently.
  final List<int> ready;
  final List<int> hints;

  /// Whether a piece that has just locked is still boinging or sparkling its
  /// ✓, which redraws it each frame for [sparkleDurationMs].
  final bool lockedMoving;

  /// How long ago the picture was finished, while the finish celebration runs
  /// (its glow lies under the picture, so it is part of the still parts);
  /// null otherwise, so the finished board is recorded once.
  final int? glowAgeMs;

  @override
  bool operator ==(Object other) =>
      other is StaticBoardKey &&
      other.board == board &&
      other.size == size &&
      other.px == px &&
      other.field == field &&
      other.look == look &&
      listEquals(other.filled, filled) &&
      listEquals(other.ready, ready) &&
      listEquals(other.hints, hints) &&
      other.lockedMoving == lockedMoving &&
      other.glowAgeMs == glowAgeMs;

  @override
  int get hashCode => Object.hash(
    board,
    size,
    px,
    field,
    look,
    Object.hashAll(filled),
    Object.hashAll(ready),
    Object.hashAll(hints),
    lockedMoving,
    glowAgeMs,
  );
}

/// Keeps what a board draws the same way from frame to frame (M14 bugs3 B-016:
/// the TV's frame rate looked choppy with two players): its still parts as one
/// recorded picture, and each piece's path while the piece lies where it did.
/// A view makes one and hands it to its painter every frame, so the shaders,
/// the blurred slots and the dashed edges of a board are built once instead of
/// once a frame. It draws nothing itself and changes no rule.
final class BoardCache {
  BoardCache({this.onRecord});

  /// Called after each recording, with the key it was recorded from: a view
  /// hands none, and a test counts the recordings to see when a key changed.
  final void Function(StaticBoardKey key)? onRecord;

  /// The still parts kept: a match draws its two boards a frame, and a phone's
  /// camera one of them, so two is every layer a frame can want.
  static const keptLayers = 2;

  final _layers = <_BoardLayer>[];
  final _paths = <(int, int), _PiecePath>{};

  /// The picture of [key]'s still parts, recorded by [record] (which draws in
  /// the field's own units on a canvas at its top left) the first time it is
  /// asked for and drawn as it is until [key] changes. A layer drawn again goes
  /// to the end, so the next recording takes the layer a frame hasn't drawn.
  Picture stillParts(StaticBoardKey key, void Function(Canvas canvas) record) {
    final held = _layers.indexWhere((layer) => layer.key == key);
    if (held >= 0) {
      final layer = _layers.removeAt(held);
      _layers.add(layer);
      return layer.picture;
    }
    final recorder = PictureRecorder();
    record(Canvas(recorder));
    final picture = recorder.endRecording();
    if (_layers.length >= keptLayers) _layers.removeAt(0);
    _layers.add(_BoardLayer(key, picture));
    onRecord?.call(key);
    return picture;
  }

  /// Forgets every picture and path: a view given another puzzle draws a board
  /// the cache knows nothing about (M14 bugs3's still-key finding).
  void clear() {
    _layers.clear();
    _paths.clear();
  }

  /// Piece [piece] of [board]'s path while it lies at [at], turned [angle] and
  /// drawn at [scale], made by [build] when it has moved, turned or changed
  /// size since the last frame (M14 bugs3 B-016): a tray's pieces stand still
  /// frame after frame, and a piece's path is built from its shape every time
  /// otherwise.
  Path pathOf(int board, int piece, Offset at, double angle, double scale, Path Function() build) {
    final held = _paths[(board, piece)];
    if (held != null && held.at == at && held.angle == angle && held.scale == scale) return held.path;
    final path = build();
    _paths[(board, piece)] = _PiecePath(at, angle, scale, path);
    return path;
  }
}

/// What one board's still parts are drawn from (M14 bugs3 B-016): the box, the
/// field and the look, the targets that are filled, ready or hinted, and
/// whether a locked piece or the finish is moving — then they are recorded
/// again each frame.
extension _StillKey on PuzzlePainter {
  StaticBoardKey stillKey(Size size, double px) {
    final locked = [
      for (final (i, p) in s.pieces.indexed)
        if (p.state == PieceState.locked) i,
    ];
    final glowAgeMs = switch (_finishAge) {
      final age? when Celebration.isRunning(age) => age,
      _ => null,
    };
    return StaticBoardKey(
      board: board,
      size: size,
      px: px,
      field: field,
      look: look,
      filled: [for (final i in locked) _targetOf(i)]..sort(),
      ready: s.readyTargets.toList()..sort(),
      hints: s.hintTargets.toList()..sort(),
      lockedMoving: locked.any(_isLockedMoving),
      glowAgeMs: glowAgeMs,
    );
  }

  /// Whether piece [i] is still moving from its lock, its ✓ sparkling: a
  /// locked piece's boing (150 ms), wobble (120 ms) and sparkle (400 ms) are
  /// all over by [sparkleDurationMs], the longest of them.
  bool _isLockedMoving(int i) {
    final age = _age(i);
    return age != null && age < sparkleDurationMs;
  }
}

/// One recorded board: what it was recorded from, and the picture.
final class _BoardLayer {
  const _BoardLayer(this.key, this.picture);

  final StaticBoardKey key;
  final Picture picture;
}

/// Where a piece lay when its path was last built, and the path.
final class _PiecePath {
  const _PiecePath(this.at, this.angle, this.scale, this.path);

  final Offset at;
  final double angle;
  final double scale;
  final Path path;
}
