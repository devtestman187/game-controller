part of 'worker_moments.dart';

/// Where one worker stands: the point, and which way its body is from there.
typedef _Stand = ({Offset at, Offset away});

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
    final step = _step(effects);
    final happy = happyAgeMs;
    if (_within(happy, happyMomentMs)) return _happy(stand, happy!, step);
    if (_within(oopsAgeMs, oopsMomentMs)) return _oops(stand, step);
    if (board.phase != PuzzlePhase.playing) return _roundEnd(stand, step);
    if (piece == null || shape == null) return _empty(stand, effects, step);
    return _holding(stand, effects, step);
  }

  /// This frame's step cycle (design 5a): the stride the snapshots left, with
  /// the feet, bob, contact squash, accessory flop and arm swing worked out from
  /// it — or the still stand, with the feet side by side, when the effects are
  /// off (design D8).
  _Step _step(bool effects) {
    final walk = seen?.walk;
    if (walk == null) return const _Step.stand();
    if (!effects || walk.ease <= 0) return _Step.stand(walk.phase);
    return _Step.of(
      phase: walk.phase,
      ease: walk.ease,
      travel: travel,
      carrying: piece != null,
      working: piece != null && work != _Work.none,
    );
  }

  /// The way the dot travels, as a unit vector.
  Offset get travel => seen?.travel ?? Offset.zero;

  /// [stand]'s pose with the step cycle's feet, bob, squash and flop, and a
  /// moment's own face, hands, look, lean and motion laid over them (design 5a):
  /// a moment overrides the arms while the feet keep their last phase.
  WorkerPose _posed(
    _Stand stand,
    _Step step, {
    required WorkerFace face,
    required WorkerHands hands,
    Offset look = Offset.zero,
    double leanDeg = 0,
    ({double x, double y})? squash,
    Offset? motion,
    bool sweat = false,
  }) => WorkerPose(
    at: stand.at,
    away: stand.away,
    face: face,
    hands: hands,
    look: look,
    leanDeg: leanDeg,
    squash: squash ?? step.squash,
    motion: motion ?? step.bob,
    feet: step.feet,
    stride: step.ease,
    stridePhase: step.phase,
    tiltDeg: step.tiltDeg,
    walking: walking,
    sweat: sweat,
  );

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
  /// of the piece it holds, on the ray from its middle along the side it took
  /// the piece up on — so a carrying worker never covers the piece's middle.
  _Stand _stand() {
    final piece = this.piece;
    final shape = this.shape;
    if (piece == null || shape == null) return (at: dot, away: const Offset(0, -1));
    return _edge(away: _side);
  }

  /// Where the body stands on the piece it holds, on the side [away].
  _Stand _edge({required Offset away}) {
    final piece = this.piece!;
    final points = shape!.circle ? null : shape!.placed(Offset(piece.x, piece.y), piece.angle);
    final centre = points == null ? Offset(piece.x, piece.y) : _centreOf(points);
    final reach = points == null
        ? shape!.radius
        : _outlineReach(points, centre, away, PuzzleGame.pickupReach) ?? shape!.radius;
    return (at: centre + away * reach, away: away);
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

  WorkerPose _happy(_Stand stand, int ageMs, _Step step) => _posed(
    stand,
    step,
    face: WorkerFace.happy,
    hands: handsUp,
    look: const Offset(0, -0.4),
    squash: (x: happyWide, y: happyTall),
    motion: Offset(0, -hopShare * sin(pi * ageMs / happyMomentMs)),
  );

  /// A wrong drop: a wince, a hand up at its head and a sweat drop.
  WorkerPose _oops(_Stand stand, _Step step) =>
      _posed(stand, step, face: WorkerFace.oops, hands: handsOops, look: const Offset(0, 0.4), sweat: true);

  /// The round is over: a cheer when this board finished it, a shrug when it
  /// ran out of time or the other side finished first (a race's loser is
  /// `stopped`, not `timeUp`).
  WorkerPose _roundEnd(_Stand stand, _Step step) => board.phase == PuzzlePhase.finished
      ? _posed(
          stand,
          step,
          face: WorkerFace.happy,
          hands: handsUp,
          squash: (x: happyWide, y: happyTall),
          motion: Offset(0, -hopShare * sin(nowMs / 1000 * 2 * pi)),
        )
      : _posed(stand, step, face: WorkerFace.oops, hands: handsShrug, look: const Offset(0, 0.5));

  /// Empty-handed: walking, or standing with a blink, a breath and a glance now
  /// and then. The stride decides it rather than the speed, so a dot that has
  /// just stopped still eases its walk out (design 5a's 200 ms).
  WorkerPose _empty(_Stand stand, bool effects, _Step step) =>
      step.ease > 0 ? _walk(stand, step) : _standing(stand, effects, step);

  WorkerPose _walk(_Stand stand, _Step step) => _posed(
    stand,
    step,
    face: WorkerFace.smile,
    hands: swingingHands(phase: step.phase, ease: step.ease, travel: travel),
    look: travel,
    leanDeg: walkLeanDeg * travel.dx * step.ease,
  );

  /// A standing worker breathes, and now and then looks left then right (design
  /// 5a). Both are idle motion, so with the effects off it holds still (D8).
  WorkerPose _standing(_Stand stand, bool effects, _Step step) {
    final breath = effects ? breathAt(player.number, board.timeLeftMs) : 0.0;
    final glance = effects ? glanceAt(player.number, board.timeLeftMs) : null;
    return _posed(
      stand,
      step,
      face: effects && WorkerMoments.blinks(player.number, nowMs) ? WorkerFace.blink : WorkerFace.smile,
      hands: handsDown,
      look: glance ?? const Offset(0, 0.3),
      squash: (x: 1 - breathNarrowShare * breath, y: 1 + breathTallShare * breath),
    );
  }

  /// Holding a piece: the moments of carrying, in the design's order.
  WorkerPose _holding(_Stand stand, bool effects, _Step step) {
    if (calling) return walking ? _strain(stand, step) : _call(stand, effects, step);
    if (turned) return _turning(stand, step);
    if (holders > 1) return _together(stand, step);
    return switch (work) {
      _Work.push => _shove(stand, step),
      _Work.pull => _drag(stand, step),
      _Work.none => _carry(stand, step),
    };
  }

  /// A big piece carried alone, calling: one hand up and waving at the free
  /// teammate, the other on the piece.
  WorkerPose _call(_Stand stand, bool effects, _Step step) {
    final wave = effects ? sin(nowMs / 1000 * 2 * pi * callWavesPerS) : 0.0;
    return _posed(
      stand,
      step,
      face: WorkerFace.call,
      hands: (left: _handsOn(stand.away).left, right: Offset(callHandShare + callWaveShare * wave, -1.05)),
      look: -stand.away,
    );
  }

  /// A big piece carried alone and moving: the effort of it, with a shake.
  WorkerPose _strain(_Stand stand, _Step step) => _posed(
    stand,
    step,
    face: WorkerFace.effort,
    hands: _handsOn(stand.away),
    look: -stand.away,
    squash: (x: strainWide, y: strainTall),
    motion: Offset(shakeShare * sin(nowMs / 1000 * 2 * pi * shakePerS), 0),
    sweat: true,
  );

  /// Turning the piece it holds on the spot.
  WorkerPose _turning(_Stand stand, _Step step) => _posed(
    stand,
    step,
    face: WorkerFace.effort,
    hands: _handsOn(stand.away),
    look: -stand.away,
    squash: (x: strainWide, y: strainTall),
  );

  /// A big piece with a teammate: the two of them carry it, both hands on it.
  WorkerPose _together(_Stand stand, _Step step) =>
      _posed(stand, step, face: WorkerFace.smile, hands: _handsOn(stand.away), look: -stand.away);

  WorkerPose _shove(_Stand stand, _Step step) => _working(stand, step, pushLeanDeg, stand.away * -1);

  WorkerPose _drag(_Stand stand, _Step step) => _working(stand, step, pullLeanDeg, stand.away);

  /// Shoving or dragging: the effort of it, leaning [leanDeg] toward [toward].
  WorkerPose _working(_Stand stand, _Step step, double leanDeg, Offset toward) => _posed(
    stand,
    step,
    face: WorkerFace.effort,
    hands: _handsOn(stand.away),
    look: -stand.away,
    leanDeg: leanDeg * toward.dx,
    squash: (x: strainWide, y: strainTall),
  );

  /// Carrying a piece along, neither shoving nor dragging it.
  WorkerPose _carry(_Stand stand, _Step step) =>
      _posed(stand, step, face: WorkerFace.smile, hands: _handsOn(stand.away), look: -stand.away);
}

/// Both mitten hands reaching at the piece on [away]'s far side — the piece a
/// worker holds — [reach] body radii out from its middle and [spread] apart.
WorkerHands _handsOn(Offset away, {double reach = 1.1, double spread = 0.55}) {
  final toward = -away;
  final across = Offset(-away.dy, away.dx);
  return (left: toward * reach - across * spread, right: toward * reach + across * spread);
}

/// Where a polygon's [points] balance, its area's centroid: always inside a
/// triangle, unlike the point the piece is held by, which a puzzle may put on
/// an edge (the boat's sail and flag: owner's test of m13.3).
Offset _centreOf(List<Offset> points) {
  var area = 0.0;
  var x = 0.0;
  var y = 0.0;
  for (var i = 0; i < points.length; i++) {
    final (a, b) = (points[i], points[(i + 1) % points.length]);
    final cross = a.dx * b.dy - b.dx * a.dy;
    area += cross;
    x += (a.dx + b.dx) * cross;
    y += (a.dy + b.dy) * cross;
  }
  if (area.abs() < 1e-9) return points.reduce((a, b) => a + b) / points.length.toDouble();
  return Offset(x, y) / (3 * area);
}

/// How far out along [dir] from [from] a body [half] wide, sliding in from
/// far away, first meets the polygon: the farthest the outline reaches along
/// [dir] within [half] of the line through [from]. So the body touches the
/// piece wherever it is widest there, and as the piece turns the place moves
/// smoothly, where a single ray would jump past a sharp corner (owner's test
/// of m13.3). Null where nothing of the outline is in that band.
double? _outlineReach(List<Offset> points, Offset from, Offset dir, double half) {
  final across = Offset(-dir.dy, dir.dx);
  double along(Offset p) => (p - from).dx * dir.dx + (p - from).dy * dir.dy;
  double side(Offset p) => (p - from).dx * across.dx + (p - from).dy * across.dy;
  double? best;
  for (var i = 0; i < points.length; i++) {
    final (a, b) = (points[i], points[(i + 1) % points.length]);
    final (sa, sb) = (side(a), side(b));
    // The edge's part inside the band, as shares of it from a to b.
    var (t0, t1) = (0.0, 1.0);
    if ((sb - sa).abs() < 1e-12) {
      if (sa.abs() > half) continue;
    } else {
      final (u, v) = ((-half - sa) / (sb - sa), (half - sa) / (sb - sa));
      t0 = max(t0, min(u, v));
      t1 = min(t1, max(u, v));
      if (t0 > t1) continue;
    }
    for (final t in [t0, t1]) {
      final reach = along(Offset.lerp(a, b, t)!);
      if (best == null || reach > best) best = reach;
    }
  }
  return best;
}
