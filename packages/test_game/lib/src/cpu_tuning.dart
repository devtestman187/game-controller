import 'arena_robo.dart';

/// One Robo level's numbers (party-night §7a's table), in one place so the
/// three levels are tuned by changing a row.
///
/// The table's columns map onto these: "Reacts" is [reactionS], "Top speed" is
/// [speedShare], "Wobble" is [wobbleRad] and "Hazards" is [hazardMargin]. The
/// brief names the first three; the hazard berth is how "avoiding hazards"
/// grows from a wide one on Easy to a tight line on Hard.
final class CpuTuning {
  const CpuTuning({
    required this.reactionS,
    required this.speedShare,
    required this.wobbleRad,
    required this.hazardMargin,
    required this.shoveEveryS,
    required this.shoveRange,
    required this.shoveAimed,
  });

  /// A child around 8 wins about 4 rounds in 5 (design 7a).
  static const easy = CpuTuning(
    reactionS: 0.5,
    speedShare: 0.75,
    wobbleRad: 0.45,
    hazardMargin: 0.13,
    shoveEveryS: null,
    shoveRange: 0.4,
    shoveAimed: false,
  );

  /// About even with a child.
  static const medium = CpuTuning(
    reactionS: 0.3,
    speedShare: 0.85,
    wobbleRad: 0.2,
    hazardMargin: 0.1,
    shoveEveryS: 4,
    shoveRange: 0.4,
    shoveAimed: false,
  );

  /// An adult has to try.
  static const hard = CpuTuning(
    reactionS: 0.15,
    speedShare: 0.95,
    wobbleRad: 0.05,
    hazardMargin: 0.075,
    shoveEveryS: 2,
    shoveRange: 0.4,
    shoveAimed: true,
  );

  /// The level's row of numbers.
  static CpuTuning of(RoboLevel level) => switch (level) {
    RoboLevel.easy => easy,
    RoboLevel.medium => medium,
    RoboLevel.hard => hard,
  };

  /// How long it plays on a plan before it looks again, in seconds: the
  /// design's "Reacts" column.
  final double reactionS;

  /// Its top speed as a share of a marble's: the design's "Top speed" column.
  final double speedShare;

  /// How far it veers off its plan at each look, in radians: the design's
  /// "Wobble" column, applied to the aim.
  final double wobbleRad;

  /// The berth it gives a hazard, as a share of the field's shorter side: the
  /// design's "Hazards" column.
  final double hazardMargin;

  /// The shortest wait between the shoves it starts, in seconds: null for a
  /// level that never seeks one. The design's "Shoves" column, "at most one
  /// every 4 s" on Medium and "every 2 s" on Hard; Easy's row is "never seeks
  /// one", so it has no wait to keep.
  final double? shoveEveryS;

  /// How close a player with coins must be for it to shove them, as a share of
  /// the field's shorter side: the "when the player is close" of the design's
  /// "Shoves" column.
  final double shoveRange;

  /// Whether it shoves only when the push sends the player at a wall or a
  /// hazard: Hard's "aimed so the player goes toward a wall or hazard".
  final bool shoveAimed;
}

/// How hard a hazard's berth pushes the aim away, against the plan's pull: a
/// hazard near the way wins over the way.
const cpuHazardPush = 2.0;

/// How far ahead of the marble the way is followed, in cells: it steers at the
/// farthest point of the way it can see from where it stands, so corners are
/// cut as far as the walls allow and no further.
const cpuAimCells = 6.0;

/// How far ahead the marble checks its own steering for a wall, in cells: one
/// is a step's worth, enough to know the way it is about to take is free.
const cpuStepCells = 1.0;

/// How far the marble may fall short of the step it asked for before it
/// counts as held up, as a share of that step, in seconds.
const cpuStillShare = 0.25;

/// How long held up before it looks again, and how long before it steers out
/// of the corner: both under 2 s, the bound the design puts on a stuck
/// marble.
const cpuRetargetS = 0.6;
const cpuEscapeS = 1.2;

/// How long an escape direction is kept, in seconds.
const cpuEscapeHoldS = 0.4;

/// How long the marble may circle without getting nearer a coin before it
/// turns out and gives up on that coin, in seconds: the gates of Block Castle's
/// keep and the Toy Factory's press are movers the grid cannot see, and a coin
/// behind one is not worth pressing at all round.
const cpuProgressS = 1.0;

/// How far an escape probes, in cells, before it shortens: a marble pressed
/// into a wall's berth cannot see a way out a few cells off, but a step's worth
/// of free ground is enough to start moving.
const cpuEscapeCells = 1.0;

/// How much longer a way to the coin it already has may be than the shortest
/// one before it changes its mind.
const cpuKeepShare = 1.3;

/// How far, in cells, it looks for free ground when it stands in a wall's
/// berth: a marble against a wall is a cell the grid calls taken, and the free
/// cell beside it is a cell or two off.
const cpuFreeCells = 6;

/// How far past a player, in cells, a Hard shove looks for the wall or hazard
/// it aims them at (party-night §7a: "aimed so the player goes toward a wall
/// or hazard"). A dash covers a marble's share of the field in a moment, so a
/// few cells is what a shove can promise.
const cpuShoveCells = 3.0;

/// How far off a coin must be, in cells, before Robo dashes at it rather than
/// walking (party-night §7a: "dashes toward a far coin"): a dash covers more
/// than this in its third of a second, and one made at a coin nearer than that
/// would carry a marble past it.
const cpuDashCells = 25.0;
