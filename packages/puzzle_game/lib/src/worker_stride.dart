part of 'worker_moments.dart';

/// How far the dot travels for one whole step cycle — two steps — in field
/// units: the worker's body's diameter ([PuzzleGame.pickupReach] either side of
/// its middle), so a full stride covers its own width and its feet keep pace
/// with the stick at any speed (design 5a).
const strideUnits = 2 * PuzzleGame.pickupReach;

/// How long a walk's stride takes to rise to full when the dot starts walking,
/// and to settle when it stops, in milliseconds of game time (design 5a: 150
/// and 200): the worker eases into a walk and out of one, and a stop lets the
/// feet come together rather than freezing them apart.
const strideRiseMs = 150;
const strideFallMs = 200;

/// How far each foot swings either side of its rest, in body radii, and how far
/// the foot in the air lifts at the middle of its swing (design 5a: ±0.3 and
/// 0.15).
const footSwingShare = 0.3;
const footLiftShare = 0.15;

/// How much of its swing a worker loses while it shoves or drags the piece it
/// holds, in body radii: 0.7 of the full swing, a shorter stride under the
/// effort (design 5a).
const workSwingShare = 0.7;

/// How far the body bobs up twice a cycle, in body radii, and the share of that
/// a carrying worker's does (design 5a: 0.06, and half carrying).
const bobShare = 0.06;
const carryBobShare = 0.5;

/// How far the body squashes wider and shorter at each foot's contact, as a
/// share of its width and of its height (design 5a: 4 %).
const contactSquashShare = 0.04;

/// How far the accessory on top flops, in degrees, a quarter of a step behind
/// the body's bob (design 5a: up to ±8°).
const earFlopDeg = 8.0;

/// How fast a standing worker breathes, in breaths a second, and how much
/// taller and narrower it is at the top of a breath (design 5a: 0.4 Hz, 2 % and
/// 1 %).
const breathHz = 0.4;
const breathTallShare = 0.02;
const breathNarrowShare = 0.01;

/// The breath's period, in milliseconds: [breathHz] a second.
const breathPeriodMs = 1000 / breathHz;

/// How far apart two players' breaths are, in milliseconds: each number shifts
/// its breath along [breathPeriodMs] by a quarter, so four standing workers
/// don't breathe together (design 5a, as [blinkStaggerMs] staggers the blink).
const breathStaggerMs = 625;

/// How long a standing worker looks left and then right, and how often a glance
/// comes, in milliseconds of game time (design 5a: a 1.2 s glance every few
/// seconds), and how far each number's glance is shifted along the period.
const glanceLengthMs = 1200;
const glancePeriodMs = 4000;
const glanceStaggerMs = 1250;

/// One worker's step cycle as the snapshots show it (design 5a): where in the
/// stride it is, and how much of the stride shows.
///
/// The phase moves with the distance the dot travelled and nothing else, so the
/// feet keep pace with the stick at any speed, a strip at 30 Hz and one at
/// 60 Hz give the same picture at the same place, and a stop freezes the cycle
/// mid-step; the amount eases in and out over [strideRiseMs] and [strideFallMs]
/// of game time.
final class _Walk {
  /// Where in the stride the feet are, 0 to 1.
  double phase = 0;

  /// How much of the stride shows, 0 to 1.
  double ease = 0;

  /// Moves the cycle on by the dot's [step] over [elapsedMs] of game time: a dot
  /// that moved steps the phase on and fills the stride, one that didn't lets
  /// the stride settle.
  void note(Offset step, int elapsedMs) {
    if (step.distance <= 0) {
      ease = max(0.0, ease - elapsedMs / strideFallMs);
      return;
    }
    phase = (phase + step.distance / strideUnits) % 1;
    ease = min(1.0, ease + elapsedMs / strideRiseMs);
  }
}

/// What one frame of a worker's step cycle draws (design 5a): where in the
/// stride it is, where its two feet are, how far its body bobs, how it
/// squashes at a contact, and how far its accessory flops behind the bob. Every
/// value is in body radii, or a share of a body radius.
final class _Step {
  const _Step({
    required this.phase,
    required this.ease,
    required this.feet,
    required this.bob,
    required this.squash,
    required this.tiltDeg,
  });

  /// A worker standing still, its cycle stopped at [phase] (0 for a worker that
  /// never walked): the feet side by side, and nothing moving (design D8's still
  /// pose).
  const _Step.stand([this.phase = 0])
    : ease = 0,
      feet = feetTogether,
      bob = Offset.zero,
      squash = (x: 1.0, y: 1.0),
      tiltDeg = 0;

  /// The cycle at [phase] with [ease] of it showing, the worker walking along
  /// [travel], [carrying] a piece and, with [working], shoving or dragging it.
  factory _Step.of({
    required double phase,
    required double ease,
    required Offset travel,
    required bool carrying,
    required bool working,
  }) {
    final wave = 2 * pi * phase;
    final swing = footSwingShare * ease * (working ? workSwingShare : 1);
    final out = cos(wave);
    final up = sin(wave);
    WorkerFoot foot({required bool left}) => (
      at: Offset(left ? -footApartShare : footApartShare, footUnderShare) + travel * (swing * (left ? out : -out)),
      lift: footLiftShare * ease * max(0.0, left ? -up : up),
    );
    // Twice a cycle, at the middle of each step, and back down at each contact.
    final bob = bobShare * ease * up * up * (carrying ? carryBobShare : 1);
    final contact = contactSquashShare * ease * max(0.0, cos(2 * wave));
    return _Step(
      phase: phase,
      ease: ease,
      feet: (left: foot(left: true), right: foot(left: false)),
      bob: Offset(0, -bob),
      squash: (x: 1 + contact, y: 1 - contact),
      tiltDeg: -earFlopDeg * ease * sin(2 * wave),
    );
  }

  /// Where in the stride the feet are, 0 to 1.
  final double phase;

  /// How much of the stride shows, 0 to 1.
  final double ease;

  final WorkerFeet feet;

  /// How far the body is moved from where it stands by the bob, in body radii
  /// (up on screen while it walks).
  final Offset bob;

  /// The body's squash at the foot contacts, as a share of its width and of its
  /// height.
  final ({double x, double y}) squash;

  /// How far the accessory on top tilts with the bob's lag, in degrees.
  final double tiltDeg;
}

/// The hands of an empty-handed worker walking [phase] into its stride with
/// [ease] of it showing (design 5a): each arm swung up to [armSwingDeg] about
/// its shoulder from [handsDown], the two opposite each other and the left one
/// opposite the left foot, so the left arm is forward when the right foot is.
WorkerHands swingingHands({required double phase, required double ease, required Offset travel}) {
  final wave = 2 * pi * phase;
  final shoulder = workerShoulderShare;
  return (
    left: _swung(handsDown.left, Offset(-shoulder.dx, shoulder.dy), -cos(wave) * ease, travel),
    right: _swung(handsDown.right, shoulder, cos(wave) * ease, travel),
  );
}

/// [hand], from the body's middle, turned about its shoulder by [share] of
/// [armSwingDeg] the way that carries it along [travel] (forward when [share]
/// is positive).
Offset _swung(Offset hand, Offset shoulder, double share, Offset travel) {
  final rest = hand - shoulder;
  final forward = Offset(-rest.dy, rest.dx);
  final direction = forward.dx * travel.dx + forward.dy * travel.dy >= 0 ? 1.0 : -1.0;
  final by = direction * share * armSwingDeg * pi / 180;
  final (c, s) = (cos(by), sin(by));
  return shoulder + Offset(rest.dx * c - rest.dy * s, rest.dx * s + rest.dy * c);
}

/// How far a standing worker's breath has it taller (1 at the top of a breath,
/// -1 at the bottom), on the game's clock at [gameMs], each number's a quarter
/// of a breath behind the one before (design 5a).
double breathAt(int number, int gameMs) => sin(2 * pi * (gameMs + number * breathStaggerMs) / breathPeriodMs);

/// Which way a standing worker's eyes glance at [gameMs] on the game's clock,
/// or null while it looks ahead: it looks left for half of [glanceLengthMs] and
/// right for the other half, once every [glancePeriodMs], each number's glance
/// shifted along the period (design 5a).
Offset? glanceAt(int number, int gameMs) {
  final into = (gameMs + number * glanceStaggerMs) % glancePeriodMs;
  if (into >= glanceLengthMs) return null;
  return into < glanceLengthMs ~/ 2 ? const Offset(-0.8, 0.15) : const Offset(0.8, 0.15);
}
