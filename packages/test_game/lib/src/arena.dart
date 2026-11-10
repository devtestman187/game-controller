import 'dart:math';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'arena_coin.dart';
import 'arena_events.dart';
import 'arena_field.dart';
import 'arena_map.dart';
import 'arena_mode.dart';
import 'map_grid.dart';

part 'arena_bumper.dart';

/// The seed the Bumper Round's coins draw from when a game brings none: the
/// same round plays the same way every time (rule 4).
const defaultArenaSeed = 0;

/// What a Bumper Round's winner scores beside its coins (party-night §7, N3):
/// five, times the round's `pointsScale`.
const bumperWinBonus = 5;

/// The game's name in analytics records and results (S7).
const arenaGame = 'arena';

/// The Bumper Round's clock, in seconds (party-night §7, G9).
const double bumperRoundS = 60;

enum ArenaPhase {
  playing,

  /// Someone reached the goal (the race). The next round starts after
  /// [ArenaGame.roundBreakS].
  won,

  /// The Bumper Round's clock ran out: the round is over and its result is
  /// ready.
  over,
}

/// The test game's rules (PRD "Test game design"): sprites cross a field of
/// walls and moving hazards to the goal. Every connected controller drives
/// its own sprite, and the first to reach the goal wins the round. Hazards
/// never end a round; they knock the sprite back. Every round the field is
/// mirrored, so the start and the goal swap sides.
///
/// The field, the marbles and the movement they share are [ArenaFieldRules]'s
/// (party-night §7); this adds a round on top, in one of two modes (G9): the
/// race, as the game has played since M12, and the Bumper Round, where four
/// marbles shove each other and pick up coins for 60 seconds. The race is the
/// default, so every game built before the Bumper Round plays as it did. The
/// map (M14 k1b) is the Playroom's until the waiting card picks one (M14 b2).
///
/// The tuning values were tried on the devices in M5.
abstract class ArenaGame extends ArenaFieldRules {
  ArenaGame._base({super.map, super.mode, super.size, required this.random, required this.pointsScale});

  /// A game playing [mode] on [map] (M14 k1b), the Playroom's until the
  /// waiting card picks one (M14 b2), drawn in a window of [size]. [random]
  /// seeds the Bumper Round's coins; it draws its own (always the same) when
  /// none is given.
  ///
  /// [pointsScale] multiplies the round's night points (party-night §7, N3):
  /// the host passes the night's last round's double, 1 otherwise.
  factory ArenaGame({
    ArenaMap map = ArenaMap.playroom,
    ArenaMode mode = ArenaMode.race,
    Size size = ArenaFieldRules.defaultSize,
    Random? random,
    int pointsScale = 1,
  }) {
    assert(pointsScale >= 1, 'a round scores at least its points');
    final seeded = random ?? Random(defaultArenaSeed);
    return switch (mode) {
      ArenaMode.race => _RaceGame(map: map, size: size, random: seeded, pointsScale: pointsScale),
      ArenaMode.bumper => _BumperGame(map: map, size: size, random: seeded, pointsScale: pointsScale),
    };
  }

  /// The break after a won race round, in seconds: the winner's banner stays
  /// up this long before the field mirrors and the next round starts.
  static const double roundBreakS = 2.0;

  // The shared tuning's public names, from [ArenaFieldRules]: the snapshot,
  // the HUD and the tests read them here.
  static const double playerRadius = ArenaFieldRules.playerRadius;
  static const double hazardRadius = ArenaFieldRules.hazardRadius;
  static const double speed = ArenaFieldRules.speed;
  static const double dashS = ArenaFieldRules.dashS;
  static const double dashCooldownS = ArenaFieldRules.dashCooldownS;

  /// The random the Bumper Round draws its coins' places from. The race never
  /// uses it.
  final Random random;

  /// What the round's points score at (party-night §7, N3): 1 outside a night
  /// and in its other rounds, and the night's last round's 2. It scales the
  /// points only; the counters and the lines keep the coins as they were won.
  final int pointsScale;

  double _roundTime = 0;
  double _breakLeft = 0;
  bool _draw = false;
  RoundResult? _result;

  ArenaPhase phase = ArenaPhase.playing;

  int round = 1;

  /// Who won the current round (while [phase] is won) and how fast.
  String? winnerId;
  double? lastTimeS;

  /// The fastest round so far, and who ran it.
  double? bestTimeS;
  String? bestId;

  /// Seconds into the current round (frozen once it ends).
  double get roundTime => _roundTime;

  /// Seconds until the next round, while [phase] is won.
  double get breakLeft => _breakLeft;

  /// Whether the round had no single winner (a tie on coins, G9).
  bool get draw => _draw;

  /// The Bumper Round's result once its clock runs out (G9): the night's
  /// points (a coin for each coin, [bumperWinBonus] for each winner, times
  /// [pointsScale]), the winners, the counters the awards need and each
  /// player's line. Null while it plays, and always in the race, whose results
  /// card comes with M14 b2.
  RoundResult? get roundResult => _result;

  /// Seconds left on the Bumper Round's clock, or null in the race.
  double? get timeLeftS => null;

  /// The coins on the field, in the order they came out: the Bumper Round's,
  /// and none in the race.
  List<ArenaCoin> get coins => const [];

  /// Advances the game by [dt] seconds with each player's input, and returns
  /// the events to play. Controllers missing from [inputs] leave the game,
  /// and new ones join it.
  List<GameEvent> update(double dt, Map<String, GameInput> inputs) {
    syncPlayers(inputs);

    dt = dt.clamp(0.0, 0.1);
    final events = <GameEvent>[];
    advanceTime(dt);
    stepRound(dt, inputs, events);
    return events;
  }

  /// Plays one step of the mode's round: the race's goal, the Bumper Round's
  /// contacts, coins and clock. Every event it causes goes into [events].
  void stepRound(double dt, Map<String, GameInput> inputs, List<GameEvent> events);

  /// The round's own counters for its `round_end` record (S7): the time the
  /// round took and the winner, besides the players' control modes.
  Map<String, Object?> roundEndData(Map<String, String> modes);
}

/// The race (PRD "Test game design", M12): hold a direction to walk, A to
/// dash, and reach the goal pad first. Every round the field mirrors, so the
/// start and the goal swap sides.
final class _RaceGame extends ArenaGame {
  _RaceGame({required super.map, required super.size, required super.random, required super.pointsScale})
    : super._base(mode: ArenaMode.race);

  @override
  void stepRound(double dt, Map<String, GameInput> inputs, List<GameEvent> events) {
    if (phase == ArenaPhase.won) {
      _breakLeft -= dt;
      if (_breakLeft <= 0) _newRound();
      noteDashHeld(inputs);
      return;
    }

    _roundTime += dt;
    for (final p in players) {
      _updatePlayer(p, dt, inputs[p.id]!, events);
      if (phase == ArenaPhase.won) break; // The first one in wins.
    }
  }

  void _updatePlayer(ArenaPlayer p, double dt, GameInput input, List<GameEvent> events) {
    stepMarble(p, dt, input, events);

    if (reachedGoal(p)) {
      phase = ArenaPhase.won;
      winnerId = p.id;
      p.wins++;
      lastTimeS = _roundTime;
      p.bestTimeS = p.bestTimeS == null ? _roundTime : min(p.bestTimeS!, _roundTime);
      if (bestTimeS == null || _roundTime < bestTimeS!) {
        bestTimeS = _roundTime;
        bestId = p.id;
      }
      _breakLeft = ArenaGame.roundBreakS;
      stopDashes();
      events.add(GameEvent(p.id, HapticEvent.success, GameEventCause.goal));
    }
  }

  void _newRound() {
    phase = ArenaPhase.playing;
    mirrored = !mirrored;
    round++;
    winnerId = null;
    _roundTime = 0;
    resetMarbles();
  }

  @override
  Map<String, Object?> roundEndData(Map<String, String> modes) => {
    'timeS': lastTimeS,
    'modes': modes,
    'winner': winnerId,
  };
}
