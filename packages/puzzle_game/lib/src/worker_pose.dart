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
/// them for a surprise and shrugs at a lost round, in body radii from its
/// middle: x to its right, y down. Walking, they swing about [handsDown] (see
/// `swingingHands` in worker_stride.dart).
const WorkerHands handsDown = (left: Offset(-1.05, 0.8), right: Offset(1.05, 0.8));
const WorkerHands handsUp = (left: Offset(-1.2, -1.15), right: Offset(1.2, -1.15));
const WorkerHands handsOops = (left: Offset(-0.92, -0.72), right: Offset(1.1, 0.75));
const WorkerHands handsShrug = (left: Offset(-1.35, -0.3), right: Offset(1.35, -0.3));

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

/// Where a shoulder sits on a worker's body, in body radii from its middle: the
/// point each noodle arm swings about (design 5a), so the view can hang the arm
/// and the pose can swing the mitten.
const workerShoulderShare = Offset(0.62, 0.34);

/// How far a walking worker's arms swing either side of [handsDown], in
/// degrees about their shoulders (design 5a: ±35°).
const armSwingDeg = 35.0;

/// How far apart a worker's feet rest each side of its body's middle, in body
/// radii, and how far below it: side by side under the body (design 5a), close
/// enough that the body's own width holds them. Their middles sit just below
/// the body's round bottom, so their tops tuck under it and they read as feet
/// rather than floating dots (Claude's look at the run strip).
const footApartShare = 0.45;
const footUnderShare = 0.95;

/// A foot's oval, as shares of the body's diameter: a little shoe, wider than
/// tall, a quarter of the body across.
const footWideShare = 0.26;
const footTallShare = 0.17;

/// Where one foot is drawn, in body radii from the body's middle: [at] the
/// oval's middle, x to the screen's right and y down, and [lift] how far it is
/// raised off the ground toward the body (design 5a). The pose has already
/// turned the body, so the view draws a foot as it is.
typedef WorkerFoot = ({Offset at, double lift});

/// Where a worker's two feet are, its left then its right, in body radii from
/// the body's middle (design 5a).
typedef WorkerFeet = ({WorkerFoot left, WorkerFoot right});

/// The two feet side by side under the body: a standing worker's, and the pair
/// that shows with the effects off (design D8).
const WorkerFeet feetTogether = (
  left: (at: Offset(-footApartShare, footUnderShare), lift: 0.0),
  right: (at: Offset(footApartShare, footUnderShare), lift: 0.0),
);

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
    this.look = Offset.zero,
    this.leanDeg = 0,
    this.squash = (x: 1.0, y: 1.0),
    this.motion = Offset.zero,
    this.slide = Offset.zero,
    this.feet = feetTogether,
    this.stride = 0,
    this.stridePhase = 0,
    this.tiltDeg = 0,
    this.walking = false,
    this.sweat = false,
  });

  /// A worker standing empty-handed on [dot]: what a view draws where it has
  /// no [WorkerMoments].
  const WorkerPose.on(Offset dot) : this(at: dot, away: const Offset(0, -1), face: WorkerFace.smile, hands: handsDown);

  /// The point the worker stands on, in the field's units: the grab point while
  /// it holds nothing, else the edge of the piece it holds.
  final Offset at;

  /// Which way its body is from [at], as a unit vector: up while it holds
  /// nothing, else away from the middle of the piece it holds.
  final Offset away;

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

  /// Where the two feet are drawn (design 5a): side by side under the body
  /// while it stands, swinging and lifting one at a time while it walks.
  final WorkerFeet feet;

  /// How much of the step cycle shows, 0 (standing, or the effects off) to 1 (a
  /// full stride), and where in it the feet are, 0 to 1: 0 and 0.5 are the
  /// feet's contacts, 0.25 and 0.75 the middles of its two steps (design 5a).
  final double stride;
  final double stridePhase;

  /// How far the accessory on top is tilted, in degrees, as it flops a quarter
  /// of a step behind the body's bob (design 5a): 0 is upright, and a crown
  /// just tilts.
  final double tiltDeg;

  /// Whether the dot's speed has its worker walking (design 5a: walking is a
  /// speed, with [walkStartSpeed] and [walkStopSpeed] a stick's wobble can't
  /// flicker it): the stride eases in and out of it over [strideRiseMs] and
  /// [strideFallMs], so the first and last moments of a walk are short of it.
  final bool walking;

  /// Whether a sweat drop is drawn.
  final bool sweat;

  /// The pose with the motion the effects setting turns off (design D8) taken
  /// out: no hop, no shake, no lean, no stride, no flop. The face, the squash,
  /// the arms, the feet and the slide stay, so a worker with the effects off
  /// still says what it is doing, and where it is drawn.
  WorkerPose still() => WorkerPose(
    at: at,
    away: away,
    face: face,
    look: look,
    squash: squash,
    hands: hands,
    feet: feetTogether,
    stridePhase: stridePhase,
    slide: slide,
    sweat: sweat,
  );

  /// This pose with its body slid [by] in the field's units (design 5a rule 4).
  WorkerPose slid(Offset by) => WorkerPose(
    at: at,
    away: away,
    face: face,
    look: look,
    leanDeg: leanDeg,
    squash: squash,
    motion: motion,
    slide: by,
    hands: hands,
    feet: feet,
    stride: stride,
    stridePhase: stridePhase,
    tiltDeg: tiltDeg,
    walking: walking,
    sweat: sweat,
  );

  @override
  String toString() => 'WorkerPose(${face.name} at $at away $away lean $leanDeg)';
}
