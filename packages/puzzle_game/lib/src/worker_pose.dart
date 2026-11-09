import 'dart:ui';

/// Which face a worker shows (design 5a).
enum WorkerFace {
  /// A soft smile, eyes open: standing, walking, carrying with a teammate.
  smile,

  /// Eyes screwed shut and a gritted mouth: shoving, dragging or turning a
  /// piece, or holding a big one alone.
  effort,

  /// A wide open mouth and a waving hand: calling a teammate to a big piece.
  call,

  /// Eyes shut and a flat mouth: a wrong drop, or a round lost.
  oops,

  /// Eyes shut and a wide grin: a right drop, or a round won.
  happy,

  /// Eyes shut and a soft smile for a moment: a standing worker's blink.
  blink,
}

/// Where a worker's mitten hands reach, in body radii from its middle.
typedef WorkerHands = ({Offset left, Offset right});

/// Where a worker's hands rest when it stands, reaches up in a cheer, raises
/// them for a surprise, shrugs at a lost round, and swings them walking, in
/// body radii from its middle: x to its right, y down.
const WorkerHands handsDown = (left: Offset(-1.05, 0.8), right: Offset(1.05, 0.8));
const WorkerHands handsUp = (left: Offset(-1.2, -1.15), right: Offset(1.2, -1.15));
const WorkerHands handsOops = (left: Offset(-0.92, -0.72), right: Offset(1.1, 0.75));
const WorkerHands handsShrug = (left: Offset(-1.35, -0.3), right: Offset(1.35, -0.3));
const WorkerHands handsWalk = (left: Offset(-1.15, 0.45), right: Offset(0.95, 0.9));

/// How high a calling worker's hand is raised, in body radii, and how far it
/// waves either side of that.
const callHandShare = 1.3;
const callWaveShare = 0.15;

/// How fast the calling hand waves, a second.
const callWavesPerS = 2.0;

/// How high a happy worker hops, in body radii, and how far a straining one
/// shakes from side to side, in body radii — and how fast it shakes, a second.
const hopShare = 0.18;
const shakeShare = 0.05;
const shakePerS = 9.0;

/// How far a worker leans when it shoves or drags a piece, and when it walks,
/// in degrees: toward the piece for a shove, away from it for a drag.
const pushLeanDeg = 12.0;
const pullLeanDeg = 14.0;
const walkLeanDeg = 8.0;

/// How far a worker squashes under a strain, and stretches in a cheer, as a
/// share of its width and its height (design 5a's mock-up: 1.13 by 0.87).
const strainWide = 1.13;
const strainTall = 0.87;
const happyWide = 0.94;
const happyTall = 1.07;

/// The room a worker is drawn in, for keeping its ink inside the field (design
/// 5a rule 4): the field's rect, how far the body's middle sits from the point
/// the worker stands on, and how far its ink reaches from that middle. The last
/// two are the painter's own sizes, in the field's units.
typedef WorkerFit = ({Rect inside, double stand, double ink});

/// One worker's whole pose (design 5a): where its body stands, which way it
/// leans, squashes, hops or shakes, where its hands reach, and what its face
/// shows. The rules decide it here and the view draws it in the player's
/// colour, so the host and every phone show the same worker (design section 7).
final class WorkerPose {
  const WorkerPose({
    required this.at,
    required this.away,
    required this.face,
    required this.hands,
    this.onDot = false,
    this.look = Offset.zero,
    this.leanDeg = 0,
    this.squash = (x: 1.0, y: 1.0),
    this.motion = Offset.zero,
    this.slide = Offset.zero,
    this.sweat = false,
  });

  /// A worker standing empty-handed on [dot]: what a view draws where it has
  /// no [WorkerMoments].
  const WorkerPose.on(Offset dot) : this(at: dot, away: const Offset(0, -1), face: WorkerFace.smile, hands: handsDown);

  /// The point the worker stands on, in the field's units: the grab point while
  /// it holds nothing, else the edge of the piece it holds.
  final Offset at;

  /// Which way its body is from [at], as a unit vector: up while it holds
  /// nothing, so the ring at [at] shows under its feet, else away from the
  /// piece's middle.
  final Offset away;

  /// Whether [at] is the grab point, which the view rings in ink (design 5a).
  final bool onDot;

  final WorkerFace face;

  /// Which way the eyes look, a unit vector at most.
  final Offset look;

  /// How far the body leans from upright, in degrees, clockwise about [at].
  final double leanDeg;

  /// How far the body is squashed, as a share of its width and of its height.
  final ({double x, double y}) squash;

  /// How far the body is moved from where it stands, in body radii: a hop or a
  /// shake. Zero with the effects off (design D8).
  final Offset motion;

  /// How far the body is slid from where it stands, in the field's units, to
  /// keep its ink inside the field (design 5a rule 4): the point the worker
  /// stands on stays where the rules put it. Drawing only, so the effects
  /// setting leaves it alone.
  final Offset slide;

  final WorkerHands hands;

  /// Whether a sweat drop is drawn.
  final bool sweat;

  /// The pose with the motion the effects setting turns off (design D8) taken
  /// out: no hop, no shake, no lean. The face, the squash, the arms and the
  /// slide stay, so a worker with the effects off still says what it is doing,
  /// and where it is drawn.
  WorkerPose still() => WorkerPose(
    at: at,
    away: away,
    onDot: onDot,
    face: face,
    look: look,
    squash: squash,
    hands: hands,
    slide: slide,
    sweat: sweat,
  );

  /// This pose with its body slid [by] in the field's units (design 5a rule 4).
  WorkerPose slid(Offset by) => WorkerPose(
    at: at,
    away: away,
    onDot: onDot,
    face: face,
    look: look,
    leanDeg: leanDeg,
    squash: squash,
    motion: motion,
    slide: by,
    hands: hands,
    sweat: sweat,
  );

  @override
  String toString() => 'WorkerPose(${face.name} at $at away $away onDot $onDot lean $leanDeg)';
}
