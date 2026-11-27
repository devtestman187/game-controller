/// Bot profiles for the City Rush night simulator (see docs/briefs/m17/board3c/sim-model-v2.md).
///
/// A profile decides how well a player performs in a game, what a last-place player does at a stop when Roadworks is on
/// offer, and whom the winner of the gate game gates. The numbers of [childBot] and [adultBot] are provisional guesses,
/// not measured values.
import 'dart:math';

/// What the last-place player does at a stop: build tiles, save bolts, or send a Roadworks crew.
enum LastPlaceChoice { build, save, roadworks }

/// How a bot picks the rival the gate goes against.
///
/// [leader] gates the best rival (the leader, or the nearest rival when the bot leads); [randomRival] picks any rival.
enum GatePolicy { leader, randomRival }

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
  /// are the odds of a save and of a Roadworks choice when those are possible; [gatePolicy] says whom a gate goes against
  /// and [noGateChance] the odds that the winner lets the 10 s run out and gates nobody.
  const BotProfile({
    required this.name,
    required this.skill,
    required this.noise,
    required this.saveChance,
    required this.roadworksChance,
    required this.gatePolicy,
    required this.noGateChance,
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

  /// How this bot picks the gate's target.
  final GatePolicy gatePolicy;

  /// Chance that this bot makes no gate pick.
  final double noGateChance;

  /// A copy that picks Roadworks with chance [chance] (the "always use it" sensitivity).
  BotProfile withRoadworksChance(double chance) => BotProfile(
    name: '$name-rw',
    skill: skill,
    noise: noise,
    saveChance: saveChance,
    roadworksChance: chance,
    gatePolicy: gatePolicy,
    noGateChance: noGateChance,
  );

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

  /// The rival to gate, or null for no pick. [rivals] are the gate-able rival indices, best first; the caller passes
  /// none when nobody can be gated (no draw is made then).
  int? chooseGateTarget(Random r, {required List<int> rivals}) {
    if (rivals.isEmpty) return null;
    if (r.nextDouble() < noGateChance) return null;
    return switch (gatePolicy) {
      GatePolicy.leader => rivals.first,
      GatePolicy.randomRival => rivals[r.nextInt(rivals.length)],
    };
  }
}

/// A child: performs at random (no skill), saves and picks Roadworks rarely, gates a random rival, and lets the pick run
/// out 30% of the time.
///
/// Provisional guesses (not measured): skill 0, noise 1.4, save 10%, Roadworks 10%, no pick 30%.
const childBot = BotProfile(
  name: 'child',
  skill: 0.0,
  noise: 1.4,
  saveChance: 0.1,
  roadworksChance: 0.1,
  gatePolicy: GatePolicy.randomRival,
  noGateChance: 0.3,
);

/// An adult: performs better and more steadily, saves and picks Roadworks more often, and gates the leader.
///
/// Provisional guesses (not measured): skill 0.6, noise 0.8, save 40%, Roadworks 50%, no pick 10%.
const adultBot = BotProfile(
  name: 'adult',
  skill: 0.6,
  noise: 0.8,
  saveChance: 0.4,
  roadworksChance: 0.5,
  gatePolicy: GatePolicy.leader,
  noGateChance: 0.1,
);
