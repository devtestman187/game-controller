import 'dart:math' as math;

/// One tie-break step for a night's champion: which value decides the next cut.
/// [shared] is the end of every chain: whoever is still level after it shares
/// the win.
enum ChampionStep {
  /// Most points wins.
  points,

  /// Closest to the Plaza wins: the least distance is best.
  plazaDistance,

  /// Most Bolts wins.
  bolts,

  /// Best place in the last game wins: place 1 is best, so the least is best.
  lastGamePlace,

  /// Terminal: everyone still level shares the win.
  shared;

  /// Whether a bigger value is better on this step (false: a smaller one is).
  bool get higherWins => switch (this) {
    ChampionStep.points || ChampionStep.bolts => true,
    ChampionStep.plazaDistance || ChampionStep.lastGamePlace || ChampionStep.shared => false,
  };
}

/// A player's numbers for the champion chain. A null value on a step is the
/// worst that step can give: it loses to any number on that step.
final class ChampionEntry {
  /// A player's numbers; [id] is the player's id as the night knows it.
  const ChampionEntry({required this.id, required this.points, this.plazaDistance, this.bolts, this.lastGamePlace});

  /// The player's id as the night knows it.
  final String id;

  /// Points the player has in the night.
  final int points;

  /// Distance to the Plaza, in the game's own units; less is better.
  final int? plazaDistance;

  /// Bolts the player holds; more is better.
  final int? bolts;

  /// The player's place in the last game, 1 being first; less is better.
  final int? lastGamePlace;
}

/// The ordered tie-break steps that decide a night's champion. Each step keeps
/// only the entries best on it, and the chain stops as soon as one entry is
/// left. The steps end in [ChampionStep.shared], so a chain that is still level
/// shares the win.
///
/// Where the owner's other option goes: 'best place in the last game breaks a
/// tie' is one added step, `quickNight = [points, lastGamePlace, shared]`.
final class ChampionChain {
  /// A chain of [steps]; it must not be empty, and [ChampionStep.shared] must
  /// be its last step and the only one. Not `const`: Dart cannot check a list's
  /// length or contents in a constant expression, so the checks run as asserts
  /// in debug builds when the chain is made.
  ChampionChain(this.steps) {
    assert(steps.isNotEmpty, 'a champion chain needs at least one step');
    assert(
      steps.last == ChampionStep.shared && steps.where(_isShared).length == 1,
      'shared must be the last step, and the only one',
    );
  }

  /// Quick night: most points wins; tied players share the win.
  static final quickNight = ChampionChain(const [ChampionStep.points, ChampionStep.shared]);

  /// City Rush: closest to the Plaza, then most Bolts, then shared.
  static final cityRush = ChampionChain(const [ChampionStep.plazaDistance, ChampionStep.bolts, ChampionStep.shared]);

  /// The steps in the order they are tried.
  final List<ChampionStep> steps;

  static bool _isShared(ChampionStep step) => step == ChampionStep.shared;

  /// The champion ids: one id when a single entry is best through every step,
  /// several when the chain ends level on [ChampionStep.shared]. Empty input
  /// gives an empty set.
  Set<String> champions(Iterable<ChampionEntry> entries) {
    var left = entries.toList();
    for (final step in steps) {
      if (left.length <= 1 || step == ChampionStep.shared) break;
      left = _bestOn(left, step);
    }
    return {for (final entry in left) entry.id};
  }

  /// The entries best on [step]. When every entry is null on it, nobody is
  /// better than anybody, so all of them stay.
  static List<ChampionEntry> _bestOn(List<ChampionEntry> left, ChampionStep step) {
    final values = [for (final entry in left) ?_valueOn(entry, step)];
    if (values.isEmpty) return left;
    final best = step.higherWins ? values.reduce(math.max) : values.reduce(math.min);
    return [
      for (final entry in left)
        if (_valueOn(entry, step) == best) entry,
    ];
  }

  static int? _valueOn(ChampionEntry entry, ChampionStep step) => switch (step) {
    ChampionStep.points => entry.points,
    ChampionStep.plazaDistance => entry.plazaDistance,
    ChampionStep.bolts => entry.bolts,
    ChampionStep.lastGamePlace => entry.lastGamePlace,
    ChampionStep.shared => null,
  };
}
