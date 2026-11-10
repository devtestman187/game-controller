import 'dart:math';
import 'dart:ui';

import 'arena_specs.dart';

/// A spring's radius, as a fraction of the field's shorter side: about a
/// marble and a half across, so one reads on a TV and on a phone.
const springRadius = 0.05;

/// How much faster than the marble's own speed a spring, and a bouncy wall,
/// send it back (party-night §7b: "bounces off at 1.5× its speed").
const springKick = 1.5;

/// A post's radius, a fraction of the field's shorter side: a little wider
/// than a marble, so a tower or a column reads as solid.
const postRadius = 0.055;

/// A belt's width, as a fraction of the field's shorter side, and the share
/// of a marble's walking speed it carries at ("carry a marble along at half
/// its speed").
const beltWidth = 0.09;
const beltCarryShare = 0.5;

/// How many poses of a mover's cycle the map rules sample to find what it
/// sweeps: enough for a swing's two ends and a slide's two places.
const moverSamples = 16;

/// How big a decor piece is, as a fraction of the field's shorter side, when
/// a map says no size.
const decorSize = 0.09;

/// The scenery a map may paint round the play (party-night §7b): pennants,
/// lights and gears. Drawn only — it has no collision and no effect on play.
enum DecorKind { flag, light, gear }

/// The kinds a map file may name, in the order the schema and the parser list
/// them.
List<String> get decorKinds => [for (final kind in DecorKind.values) kind.name];

/// The refusal of a decor kind this build has not got, in the same words in
/// the schema and the parser.
String notADecorKind(Object? kind) => '"$kind" is not a decor kind: use ${decorKinds.join(', ')}';

/// One piece of a map's scenery: a [kind] at a spot, with no effect on play.
final class DecorSpec {
  const DecorSpec(this.kind, this.at, {this.size = decorSize});

  final DecorKind kind;

  /// Where it stands, in fractions of the field.
  final Offset at;

  /// How big it is drawn, a fraction of the field's shorter side.
  final double size;

  @override
  bool operator ==(Object other) => other is DecorSpec && other.kind == kind && other.at == at && other.size == size;

  @override
  int get hashCode => Object.hash(kind, at, size);
}

/// A round toy spring fixed to the floor (party-night §7b): a yellow coil
/// under a green cap, never red, since red means a hazard. A marble that
/// meets one bounces off at [springKick] times its speed, with a `bump`; it
/// drops nothing, so it is no hazard.
final class SpringSpec {
  const SpringSpec(this.at, {this.radius = springRadius});

  /// Where it stands, in fractions of the field.
  final Offset at;

  /// Its radius, a fraction of the field's shorter side.
  final double radius;

  @override
  bool operator ==(Object other) => other is SpringSpec && other.at == at && other.radius == radius;

  @override
  int get hashCode => Object.hash(at, radius);
}

/// A round solid pillar (party-night §7b): a castle's tower, a factory's
/// column. A marble cannot pass through it, and it never moves.
final class PostSpec {
  const PostSpec(this.at, {this.radius = postRadius});

  /// Where it stands, in fractions of the field.
  final Offset at;

  /// Its radius, a fraction of the field's shorter side.
  final double radius;

  @override
  bool operator ==(Object other) => other is PostSpec && other.at == at && other.radius == radius;

  @override
  int get hashCode => Object.hash(at, radius);
}

/// A conveyor strip from [from] to [to] (party-night §7b): it carries a
/// marble along at [beltCarryShare] of its walking speed, toward [to]. Its
/// arrows, not its colour, say which way it goes (G5).
final class BeltSpec {
  const BeltSpec(this.from, this.to, {this.width = beltWidth});

  final Offset from;
  final Offset to;

  /// The strip's width, a fraction of the field's shorter side.
  final double width;

  /// Whether [point] (fractions of the field) is over the strip in [field],
  /// within [reach] (a fraction of the shorter side) of its middle line.
  bool carries(Offset point, {Size field = mapFieldSize, double reach = 0}) {
    final p = mapUnits(point, field);
    final middle = nearestOnLine(p, mapUnits(from, field), mapUnits(to, field));
    return (p - middle).distance <= (width / 2 + reach) * field.shortestSide;
  }

  /// The unit direction it carries along, in [field]'s units, or zero for a
  /// strip with no length.
  Offset directionIn(Size field) {
    final d = mapUnits(to, field) - mapUnits(from, field);
    return d.distance < 1e-9 ? Offset.zero : d / d.distance;
  }

  @override
  bool operator ==(Object other) => other is BeltSpec && other.from == from && other.to == to && other.width == width;

  @override
  int get hashCode => Object.hash(from, to, width);
}

/// The ways a wall can move on a timer (party-night §7b): [swing] about a
/// pivot between two angles (a flipper), [spin] round a pivot steadily (a
/// carousel) and [slide] between two places (a gate, a press).
enum MoverKind { swing, spin, slide }

/// A wall that moves on a timer: a bar of [length] (a fraction of the field's
/// shorter side) that swings, spins or slides, one full cycle every [periodS]
/// seconds. A mover pushes a marble out of its way and never crushes it: a
/// marble it pins against a wall stops it for that step (the field holds the
/// marble outside the walls).
final class MoverSpec {
  /// A bar of one end at [pivot], turning between [fromDeg] and [toDeg]
  /// (degrees clockwise from across), easing at each end like a pendulum.
  const MoverSpec.swing(
    this.pivot, {
    required this.length,
    required this.fromDeg,
    required this.toDeg,
    required this.periodS,
    this.phase = 0,
  }) : kind = MoverKind.swing,
       from = pivot,
       to = pivot,
       deg = 0;

  /// A bar of [length] centred on [pivot], turning a full circle every
  /// [periodS] at one steady speed.
  const MoverSpec.spin(this.pivot, {required this.length, required this.periodS, this.phase = 0})
    : kind = MoverKind.spin,
      from = pivot,
      to = pivot,
      fromDeg = 0,
      toDeg = 0,
      deg = 0;

  /// A bar of [length] at an angle of [deg] (degrees clockwise from across)
  /// whose middle travels from [from] to [to] and back.
  const MoverSpec.slide(
    this.from,
    this.to, {
    required this.length,
    required this.deg,
    required this.periodS,
    this.phase = 0,
  }) : kind = MoverKind.slide,
       pivot = from,
       fromDeg = 0,
       toDeg = 0;

  final MoverKind kind;

  /// The pivot a swing or a spin turns about; a slide's starting place.
  final Offset pivot;

  /// A slide's two places, in fractions of the field; a swing's and a spin's
  /// are their pivot, since they never travel.
  final Offset from;
  final Offset to;

  /// The bar's length, a fraction of the field's shorter side.
  final double length;

  /// A swing's two angles and a slide's bar's angle, in degrees clockwise
  /// from across (a bar at 0 lies across the field, at 90 down it).
  final double fromDeg;
  final double toDeg;
  final double deg;

  /// Seconds one full cycle takes.
  final double periodS;

  /// How far through its cycle it starts, 0 to 1.
  final double phase;

  /// The bar's two ends at time [t] seconds into the round, in fractions of
  /// [field]: a swing's first end is its pivot, a spin's and a slide's are
  /// either side of its middle.
  (Offset, Offset) endsAt(double t, Size field) {
    final turn = t / periodS + phase;
    final ease = 0.5 - 0.5 * cos(2 * pi * turn);
    switch (kind) {
      case MoverKind.swing:
        return (pivot, _along(pivot, fromDeg + (toDeg - fromDeg) * ease, length, field));
      case MoverKind.spin:
        final deg = 360 * (turn % 1);
        return (_along(pivot, deg + 180, length / 2, field), _along(pivot, deg, length / 2, field));
      case MoverKind.slide:
        final middle = Offset.lerp(from, to, ease)!;
        return (_along(middle, deg + 180, length / 2, field), _along(middle, deg, length / 2, field));
    }
  }

  /// The bar's poses over one full cycle, in fractions of [field]: what it
  /// sweeps, for the map rules.
  List<(Offset, Offset)> sweep({Size field = mapFieldSize}) => [
    for (var i = 0; i < moverSamples; i++) endsAt(periodS * i / moverSamples, field),
  ];

  /// [centre] reached [length] towards [deg], as fractions of [field].
  static Offset _along(Offset centre, double deg, double length, Size field) {
    final radians = deg * pi / 180;
    final reach = length * field.shortestSide;
    return Offset(centre.dx + cos(radians) * reach / field.width, centre.dy + sin(radians) * reach / field.height);
  }

  @override
  bool operator ==(Object other) =>
      other is MoverSpec &&
      other.kind == kind &&
      other.pivot == pivot &&
      other.from == from &&
      other.to == to &&
      other.length == length &&
      other.fromDeg == fromDeg &&
      other.toDeg == toDeg &&
      other.deg == deg &&
      other.periodS == periodS &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(kind, pivot, from, to, length, fromDeg, toDeg, deg, periodS, phase);
}
