part of 'worker_moments.dart';

/// Where one worker stands: the point, which way its body is from there, and
/// whether that point is the grab point.
typedef _Stand = ({Offset at, Offset away, bool onDot});

/// How a worker is working the piece it holds: shoving it, dragging it, or
/// just carrying it along.
enum _Work { none, push, pull }

/// How big a sin of [sideDeadZoneDeg] is: the share of a travel along the
/// piece's side below which it is a sideways shuffle.
final _sideDeadZone = sin(sideDeadZoneDeg * pi / 180);

/// How far a worker's body may be slid from where it stands before it reads as
/// letting go of the piece it holds, as a share of its stand from the piece's
/// edge: past this it goes round to the piece's other side instead (design 5a
/// rule 4).
const _sideSlideShare = 0.6;

/// Everything one worker's pose is worked out from, gathered once.
final class _Frame {
  _Frame(this.puzzle, this.board, this.player, this.seen, this.nowMs);

  final Puzzle puzzle;
  final PuzzleSnapshot board;
  final PlayerView player;
  final _SeenPlayer? seen;
  final int nowMs;

  Offset get dot => Offset(player.x, player.y);

  PieceView? get piece {
    final index = player.held;
    return index != null && index < board.pieces.length ? board.pieces[index] : null;
  }

  PieceShape? get shape {
    final index = player.held;
    return index != null && index < puzzle.pieces.length ? puzzle.pieces[index].shape : null;
  }

  bool get walking => seen?.walking ?? false;
  bool get turned => seen?.turned ?? false;
  int get holders => piece?.holders.length ?? 0;
  bool get calling => piece?.calling ?? false;

  /// How long ago this player's own drop landed right, or wrong.
  int? get happyAgeMs => _age(seen?.happyAtMs);
  int? get oopsAgeMs => _age(seen?.oopsAtMs);

  int? _age(int? atMs) => atMs == null ? null : nowMs - atMs;

  /// The pose this worker shows (design 5a), from the moments in the order the
  /// design lists them, with its body slid (or taken round the piece) to keep
  /// its ink inside the field when the view says how it draws it ([fit]).
  WorkerPose pose({required bool effects, WorkerFit? fit}) {
    final (stand, slide) = _fitted(fit);
    final pose = _pose(stand, effects);
    return slide == Offset.zero ? pose : pose.slid(slide);
  }

  /// The pose of a worker standing [stand], from the moments in the design's
  /// order.
  WorkerPose _pose(_Stand stand, bool effects) {
    final happy = happyAgeMs;
    if (_within(happy, happyMomentMs)) return _happy(stand, happy!);
    if (_within(oopsAgeMs, oopsMomentMs)) return _oops(stand);
    if (board.phase != PuzzlePhase.playing) return _roundEnd(stand);
    if (piece == null || shape == null) return _empty(stand, effects);
    return _holding(stand, effects);
  }

  /// Whether [ageMs] is inside a moment that lasts [lengthMs]: it starts at
  /// once and is over at [lengthMs].
  static bool _within(int? ageMs, int lengthMs) => ageMs != null && ageMs >= 0 && ageMs < lengthMs;

  /// Where the body stands, and how far it is slid from there to keep its ink
  /// inside [fit]'s field (design 5a rule 4): in from the side its body would
  /// cross, or, where that would take it off the piece it holds, round to that
  /// piece's other side. Drawing only: the dot stays where the rules left it.
  (_Stand, Offset) _fitted(WorkerFit? fit) {
    final stand = _stand();
    if (fit == null) return (stand, Offset.zero);
    final body = stand.at + stand.away * fit.stand;
    final slid = Offset(
      body.dx.clamp(fit.inside.left + fit.ink, fit.inside.right - fit.ink),
      body.dy.clamp(fit.inside.top + fit.ink, fit.inside.bottom - fit.ink),
    );
    final slide = slid - body;
    if (slide == Offset.zero) return (stand, Offset.zero);
    if (piece != null && slide.distance > _sideSlideShare * fit.stand) {
      // Further in than the arms can stretch: the worker goes round the piece
      // rather than let go of it.
      return (_edge(away: -stand.away), Offset.zero);
    }
    return (stand, slide);
  }

  /// Where the body stands: on the grab point holding nothing, else on the edge
  /// of the piece it holds, on the ray from its middle along the side the
  /// moments eased it onto — so a carrying worker never covers the piece's
  /// middle.
  _Stand _stand() {
    final piece = this.piece;
    final shape = this.shape;
    if (piece == null || shape == null) return (at: dot, away: const Offset(0, -1), onDot: true);
    return _edge(away: _side);
  }

  /// Where the body stands on the piece it holds, on the side [away].
  _Stand _edge({required Offset away}) {
    final piece = this.piece!;
    final middle = Offset(piece.x, piece.y);
    return (at: middle + away * _outlineReach(shape!, piece.angle, middle, away), away: away, onDot: false);
  }

  /// Which way the body is from the middle of the piece it holds: the side it
  /// took up with the piece, else above it.
  Offset get _side => seen?.side ?? const Offset(0, -1);

  /// Whether this worker is shoving or dragging: the way it travels against the
  /// side of the piece it is on. Sideways is neither, and standing is neither.
  _Work get work {
    final side = seen?.side;
    final travel = seen?.travel ?? Offset.zero;
    if (!walking || side == null) return _Work.none;
    final along = travel.dx * side.dx + travel.dy * side.dy;
    if (along.abs() < _sideDeadZone) return _Work.none;
    return along < 0 ? _Work.push : _Work.pull;
  }

  WorkerPose _happy(_Stand stand, int ageMs) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.happy,
    hands: handsUp,
    look: const Offset(0, -0.4),
    squash: (x: happyWide, y: happyTall),
    motion: Offset(0, -hopShare * sin(pi * ageMs / happyMomentMs)),
  );

  /// A wrong drop: a wince, a hand up at its head and a sweat drop.
  WorkerPose _oops(_Stand stand) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.oops,
    hands: handsOops,
    look: const Offset(0, 0.4),
    sweat: true,
  );

  /// The round is over: a cheer when this board finished it, a shrug when it
  /// ran out of time or the other side finished first (a race's loser is
  /// `stopped`, not `timeUp`).
  WorkerPose _roundEnd(_Stand stand) => board.phase == PuzzlePhase.finished
      ? WorkerPose(
          at: stand.at,
          away: stand.away,
          onDot: stand.onDot,
          face: WorkerFace.happy,
          hands: handsUp,
          squash: (x: happyWide, y: happyTall),
          motion: Offset(0, -hopShare * sin(nowMs / 1000 * 2 * pi)),
        )
      : WorkerPose(
          at: stand.at,
          away: stand.away,
          onDot: stand.onDot,
          face: WorkerFace.oops,
          hands: handsShrug,
          look: const Offset(0, 0.5),
        );

  /// Empty-handed: walking, or standing with a blink now and then.
  WorkerPose _empty(_Stand stand, bool effects) => walking ? _walk(stand) : _standing(stand, effects);

  WorkerPose _walk(_Stand stand) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.smile,
    hands: handsWalk,
    look: seen?.travel ?? Offset.zero,
    leanDeg: walkLeanDeg * (seen?.travel.dx ?? 0),
  );

  WorkerPose _standing(_Stand stand, bool effects) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: effects && WorkerMoments.blinks(player.number, nowMs) ? WorkerFace.blink : WorkerFace.smile,
    hands: handsDown,
    look: const Offset(0, 0.3),
  );

  /// Holding a piece: the moments of carrying, in the design's order.
  WorkerPose _holding(_Stand stand, bool effects) {
    if (calling) return walking ? _strain(stand) : _call(stand, effects);
    if (turned) return _turning(stand);
    if (holders > 1) return _together(stand);
    return switch (work) {
      _Work.push => _shove(stand),
      _Work.pull => _drag(stand),
      _Work.none => _carry(stand),
    };
  }

  /// A big piece carried alone, calling: one hand up and waving at the free
  /// teammate, the other on the piece.
  WorkerPose _call(_Stand stand, bool effects) {
    final wave = effects ? sin(nowMs / 1000 * 2 * pi * callWavesPerS) : 0.0;
    return WorkerPose(
      at: stand.at,
      away: stand.away,
      onDot: stand.onDot,
      face: WorkerFace.call,
      hands: (left: _handsOn(stand.away).left, right: Offset(callHandShare + callWaveShare * wave, -1.05)),
      look: -stand.away,
    );
  }

  /// A big piece carried alone and moving: the effort of it, with a shake.
  WorkerPose _strain(_Stand stand) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.effort,
    hands: _handsOn(stand.away),
    look: -stand.away,
    squash: (x: strainWide, y: strainTall),
    motion: Offset(shakeShare * sin(nowMs / 1000 * 2 * pi * shakePerS), 0),
    sweat: true,
  );

  /// Turning the piece it holds on the spot.
  WorkerPose _turning(_Stand stand) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.effort,
    hands: _handsOn(stand.away),
    look: -stand.away,
    squash: (x: strainWide, y: strainTall),
  );

  /// A big piece with a teammate: the two of them carry it, both hands on it.
  WorkerPose _together(_Stand stand) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.smile,
    hands: _handsOn(stand.away),
    look: -stand.away,
  );

  WorkerPose _shove(_Stand stand) => _working(stand, pushLeanDeg, stand.away * -1);

  WorkerPose _drag(_Stand stand) => _working(stand, pullLeanDeg, stand.away);

  /// Shoving or dragging: the effort of it, leaning [leanDeg] toward [toward].
  WorkerPose _working(_Stand stand, double leanDeg, Offset toward) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.effort,
    hands: _handsOn(stand.away),
    look: -stand.away,
    leanDeg: leanDeg * toward.dx,
    squash: (x: strainWide, y: strainTall),
  );

  /// Carrying a piece along, neither shoving nor dragging it.
  WorkerPose _carry(_Stand stand) => WorkerPose(
    at: stand.at,
    away: stand.away,
    onDot: stand.onDot,
    face: WorkerFace.smile,
    hands: _handsOn(stand.away),
    look: -stand.away,
  );
}

/// Both mitten hands reaching at the piece on [away]'s far side — the piece a
/// worker holds — [reach] body radii out from its middle and [spread] apart.
WorkerHands _handsOn(Offset away, {double reach = 1.1, double spread = 0.55}) {
  final toward = -away;
  final across = Offset(-away.dy, away.dx);
  return (left: toward * reach - across * spread, right: toward * reach + across * spread);
}

/// How far [shape]'s edge is from the piece's middle [at], turned [angle],
/// going out along [dir]: a circle's radius, else where the ray leaves the
/// polygon.
double _outlineReach(PieceShape shape, double angle, Offset at, Offset dir) {
  if (shape.circle) return shape.radius;
  final points = shape.placed(at, angle);
  var best = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final across = _rayHit(points[i] - at, points[(i + 1) % points.length] - at, dir);
    if (across != null && across < best) best = across;
  }
  return best.isFinite ? best : shape.radius;
}

/// How far along [dir] a ray from the origin meets the segment from [a] to [b],
/// both as offsets from the origin, or null where it misses.
double? _rayHit(Offset a, Offset b, Offset dir) {
  final edge = b - a;
  final below = dir.dx * edge.dy - dir.dy * edge.dx;
  if (below.abs() < 1e-9) return null;
  final along = (a.dx * edge.dy - a.dy * edge.dx) / below;
  final onEdge = (a.dx * dir.dy - a.dy * dir.dx) / below;
  return along > 0 && onEdge >= -1e-9 && onEdge <= 1 + 1e-9 ? along : null;
}
