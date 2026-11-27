/// The City Rush night simulator's cell: one setting of the v2 matrix (population, players, road, Roadworks, gate) and
/// its nights. The population names, and the bots each population plays with.
import '../../packages/party_host/lib/src/city/rules.dart';
import 'bots.dart';
import 'sim_rules.dart';

/// Population name: every player is an adult ([adultBot]).
const adultPopulation = 'adult';

/// Population name: adults and children alternate, the first player an adult ([adultBot], [childBot]).
const mixedPopulation = 'mixed';

/// Population name: every player is a child ([childBot]); a kids night has no gate and no Roadworks.
const kidsPopulation = 'kids';

/// One cell of the matrix: the players, road, Roadworks and gate of one setting, and its nights. Night k of the cell uses
/// the seed [seed] + k.
final class SimCell {
  /// Creates a cell. [population] is one of the population names of this file. [rwAlways] makes every bot pick
  /// Roadworks whenever it can (a sensitivity: the adoption of the variant, not the bots' guess).
  const SimCell({
    required this.population,
    required this.players,
    required this.games,
    required this.road,
    required this.roadworks,
    required this.gate,
    required this.nights,
    required this.seed,
    required this.base,
    this.rwAlways = false,
    this.rules,
  });

  /// The population name.
  final String population;

  /// The number of players in each night (2-8).
  final int players;

  /// The number of games in each night.
  final int games;

  /// The road variant. A cell with [rules] set does not apply it: the field is required only so every cell has one, so
  /// a rules cell keeps whatever value it was given (the final-rules row passes v0).
  final RoadVariant road;

  /// The Roadworks variant.
  final RoadworksVariant roadworks;

  /// Whether the targeted gate is on.
  final bool gate;

  /// The number of nights in the cell.
  final int nights;

  /// The seed of the first night; night k uses this plus k.
  final int seed;

  /// The shipping rules the road variant is applied to.
  final CityRules base;

  /// Whether every bot always picks Roadworks when it can.
  final bool rwAlways;

  /// The exact rules of the night; when set the road variant is not applied, and [roadworks] and [gate] are not read
  /// either. Null for a matrix cell, whose rules come from [road] on [base].
  final SimRules? rules;
}

/// The bots of a night's players for [name], in player order.
List<BotProfile> populationProfiles(String name, int players) => switch (name) {
  adultPopulation => List.filled(players, adultBot),
  mixedPopulation => [
    for (var player = 0; player < players; player++)
      player.isEven ? adultBot : childBot,
  ],
  kidsPopulation => List.filled(players, childBot),
  _ => throw ArgumentError.value(name, 'name', 'is not a population name'),
};
