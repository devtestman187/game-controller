/// Bot profiles for the City Rush night simulator (see docs/briefs/m17/board3b/sim-model.md).
///
/// A profile decides three things: how well a player performs in a game, what a last-place player does at a stop when
/// Roadworks is on offer, and which road a Roadworks crew works on. The numbers of [childBot] and [adultBot] are
/// provisional guesses, not measured values; the owner Nov 27 rule (greedy, child random) is the firm part.
import 'dart:math';

/// What the last-place player does at a stop: build tiles, save bolts, or send a Roadworks crew.
enum LastPlaceChoice { build, save, roadworks }

/// How a bot picks the road a Roadworks crew works on.
///
/// [greedy] works the player's own road unless blocking the leader gains more; [randomAny] picks uniformly among the
/// own road (when available) and every rival road.
enum RoadworksPickPolicy { greedy, randomAny }

/// Draws a standard normal value (mean 0, deviation 1) with the Box-Muller transform.
///
/// The first uniform draw is taken from (0, 1] so that its logarithm is finite.
double standardNormal(Random r) {
  final u1 = 1.0 - r.nextDouble();
  final u2 = r.nextDouble();
  return sqrt(-(2 * log(u1))) * cos(2 * pi * u2);
}

/// One bot's play style for the night simulator.
final class BotProfile {
  /// Creates a profile. [skill] is the mean game performance, [noise] its spread; [saveChance] and [roadworksChance]
  /// are the odds of a save and of a Roadworks choice when those are possible; [blockGap] is the tile lead of the
  /// leader over the placer at which a greedy crew blocks the leader instead of working its own road.
  const BotProfile({
    required this.name,
    required this.skill,
    required this.noise,
    required this.saveChance,
    required this.roadworksChance,
    required this.pickPolicy,
    required this.blockGap,
  });

  /// Name shown in logs and reports.
  final String name;

  /// Mean game performance; a higher value places better.
  final double skill;

  /// Standard deviation of the game performance around [skill].
  final double noise;

  /// Chance that a last-place player who may build saves instead.
  final double saveChance;

  /// Chance that a last-place player picks Roadworks when it is on offer.
  final double roadworksChance;

  /// How this bot picks the road a Roadworks crew works on.
  final RoadworksPickPolicy pickPolicy;

  /// Tile lead of the leader over the placer at which a greedy crew blocks the leader.
  /// Unused by [RoadworksPickPolicy.randomAny].
  final int blockGap;

  /// One game performance: [skill] plus [noise] times a standard normal draw from [r].
  double performance(Random r) => skill + noise * standardNormal(r);

  /// The last-place choice at a stop.
  ///
  /// Roadworks wins first when it is available and the roll passes [roadworksChance]. Otherwise a player who cannot
  /// build saves, and a player who can saves with [saveChance], else builds.
  LastPlaceChoice chooseLastPlace(
    Random r, {
    required bool canBuild,
    required bool roadworksAvailable,
  }) {
    if (roadworksAvailable && r.nextDouble() < roadworksChance)
      return LastPlaceChoice.roadworks;
    if (!canBuild) return LastPlaceChoice.save;
    if (r.nextDouble() < saveChance) return LastPlaceChoice.save;
    return LastPlaceChoice.build;
  }

  /// The player index whose road a Roadworks crew works on; [self] is the placer's own road.
  ///
  /// [rivals] are the pickable rival indices, best first; [ownAvailable] says whether the own road can be picked; and
  /// [leaderGap] is the tile lead of the best pickable rival over the placer. The caller guarantees that at least one
  /// road can be picked.
  /// Greedy: the first rival when there is one and the own road is not available or the gap reaches [blockGap];
  /// otherwise [self]. Random: a uniform pick among [self] (when available) and [rivals].
  int chooseRoadworksTarget(
    Random r, {
    required int self,
    required List<int> rivals,
    required bool ownAvailable,
    required int leaderGap,
  }) {
    if (pickPolicy == RoadworksPickPolicy.greedy) {
      if (rivals.isEmpty && !ownAvailable) {
        throw StateError('no road can be picked');
      }
      if (rivals.isNotEmpty && (!ownAvailable || leaderGap >= blockGap))
        return rivals.first;
      return self;
    }
    final options = [if (ownAvailable) self, ...rivals];
    return options[r.nextInt(options.length)];
  }
}

/// A child: performs at random (no skill), saves and picks Roadworks rarely, and picks any road at random.
///
/// Provisional guesses (not measured): skill 0, noise 1.4, save 10%, Roadworks 10%.
const childBot = BotProfile(
  name: 'child',
  skill: 0.0,
  noise: 1.4,
  saveChance: 0.1,
  roadworksChance: 0.1,
  pickPolicy: RoadworksPickPolicy.randomAny,
  blockGap: 0,
);

/// An adult: performs better and more steadily, saves and picks Roadworks more often, and crews play greedily.
///
/// Provisional guesses (not measured): skill 0.6, noise 0.8, save 40%, Roadworks 50%, block gap 2 tiles.
const adultBot = BotProfile(
  name: 'adult',
  skill: 0.6,
  noise: 0.8,
  saveChance: 0.4,
  roadworksChance: 0.5,
  pickPolicy: RoadworksPickPolicy.greedy,
  blockGap: 2,
);
