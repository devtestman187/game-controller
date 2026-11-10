import 'dart:math';

import 'package:protocol/protocol.dart';

import 'arena_events.dart';
import 'arena_field.dart';

enum ArenaPhase {
  playing,

  /// Someone reached the goal. The next round starts after
  /// [ArenaGame.roundBreakS].
  won,
}

/// The test game's rules (PRD "Test game design"): sprites cross a field of
/// walls and moving hazards to the goal. Every connected controller drives
/// its own sprite, and the first to reach the goal wins the round. Hazards
/// never end a round; they knock the sprite back. Every round the field is
/// mirrored, so the start and the goal swap sides.
///
/// The field, the marbles and the movement they share are [ArenaFieldRules]'s
/// (party-night §7); this adds the race's round on top: who reached the goal
/// and the break before the next round. The map (M14 k1b) is the Playroom's
/// until the waiting card picks one (M14 b2).
///
/// The tuning values were tried on the devices in M5.
class ArenaGame extends ArenaFieldRules {
  /// The map to race on (M14 k1b), the Playroom's when none is given until the
  /// waiting card picks one (M14 b2).
  ArenaGame({super.map, super.size});

  /// The break after a won round, in seconds: the winner's banner stays up
  /// this long before the field mirrors and the next round starts.
  static const double roundBreakS = 2.0;

  // The shared tuning's public names, from [ArenaFieldRules]: the snapshot,
  // the HUD and the tests read them here.
  static const double playerRadius = ArenaFieldRules.playerRadius;
  static const double hazardRadius = ArenaFieldRules.hazardRadius;
  static const double speed = ArenaFieldRules.speed;
  static const double dashS = ArenaFieldRules.dashS;
  static const double dashCooldownS = ArenaFieldRules.dashCooldownS;

  double _roundTime = 0;
  double _breakLeft = 0;

  ArenaPhase phase = ArenaPhase.playing;

  int round = 1;

  /// Who won the current round (while [phase] is won) and how fast.
  String? winnerId;
  double? lastTimeS;

  /// The fastest round so far, and who ran it.
  double? bestTimeS;
  String? bestId;

  /// Seconds into the current round (frozen once won).
  double get roundTime => _roundTime;

  /// Seconds until the next round, while [phase] is won.
  double get breakLeft => _breakLeft;

  /// Advances the game by [dt] seconds with each player's input, and returns
  /// the events to play. Controllers missing from [inputs] leave the game,
  /// and new ones join it.
  List<GameEvent> update(double dt, Map<String, GameInput> inputs) {
    syncPlayers(inputs);

    dt = dt.clamp(0.0, 0.1);
    final events = <GameEvent>[];
    advanceTime(dt);

    if (phase == ArenaPhase.won) {
      _breakLeft -= dt;
      if (_breakLeft <= 0) _newRound();
      noteDashHeld(inputs);
      return events;
    }

    _roundTime += dt;
    for (final p in players) {
      _updatePlayer(p, dt, inputs[p.id]!, events);
      if (phase == ArenaPhase.won) break; // The first one in wins.
    }
    return events;
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
      _breakLeft = roundBreakS;
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
}
