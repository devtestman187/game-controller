import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../../../tools/sim/bots.dart';

/// Ms in a second: the fuse counts in ms, the test's clock in seconds.
const _msPerS = 1000;

/// The test clock's step in seconds. Within one step a snap and the fuse's end cannot be told apart, so the timing
/// check allows two steps.
const _stepS = 0.1;

/// Seconds a bot of performance 0 takes to snap the present it holds: the slowest pace.
const _slowestReactionS = 4.0;

/// The quickest a bot snaps, in seconds, however well it performs.
const _fastestReactionS = 0.5;

/// Presents each bot plays in a simulation.
const _presentsPerBot = 200;

/// Most bats one present takes in the simulation. A snap that finds the fuse nearly out lifts it back to the floor
/// (PresentRules.onSnap), so a present may never pop; this cap ends such a present.
const _maxBatsPerPresent = 50;

/// The seed of every simulation's draws, so both bots face the same presents on every run.
const _seed = 42;

/// One simulated present: its bats, whether the cap ended it, and the lowest fuse a snap left, in ms.
typedef _Present = ({int bats, bool capped, int lowestFuseMs});

/// How long a bot takes to snap the present it holds, in seconds. The pace follows the bot's performance, drawn from
/// its profile each time it receives the present: a higher performance is quicker, never quicker than
/// [_fastestReactionS].
double _reactionS(BotProfile bot, Random r) => max(_fastestReactionS, _slowestReactionS - bot.performance(r));

/// Plays one present out, from its spawn to its pop, with [bot] on both sides: whichever side holds it snaps after its
/// pace and bats it across.
_Present _playPresent(BotProfile bot, Random r) {
  final rules = PresentRules();
  var clockS = 0.0;
  while (rules.state == null) {
    rules.update(_stepS, enabled: true, oneBoard: false);
    clockS += _stepS;
  }
  var dueS = clockS + _reactionS(bot, r);
  var bats = 0;
  var lowestFuseMs = FuseParams.startFuseMs;
  while (true) {
    final state = rules.state;
    if (state == null || state.popped) return (bats: bats, capped: false, lowestFuseMs: lowestFuseMs);
    if (bats == _maxBatsPerPresent) return (bats: bats, capped: true, lowestFuseMs: lowestFuseMs);
    if (clockS >= dueS) {
      rules.onSnap(state.holder);
      bats++;
      final after = rules.state;
      if (after != null && after.fuseMs < lowestFuseMs) lowestFuseMs = after.fuseMs;
      dueS = clockS + _reactionS(bot, r);
    }
    rules.update(_stepS, enabled: true, oneBoard: false);
    clockS += _stepS;
  }
}

/// Plays [_presentsPerBot] presents with [bot], all from one fixed seed.
List<_Present> _simulate(BotProfile bot) {
  final r = Random(_seed);
  return [for (var i = 0; i < _presentsPerBot; i++) _playPresent(bot, r)];
}

/// The mean bats per present.
double _meanBats(List<_Present> presents) => presents.fold(0, (sum, p) => sum + p.bats) / presents.length;

void main() {
  test('a present nobody bats pops when the start fuse runs out, within two steps of it', () {
    final rules = PresentRules();
    var clockS = 0.0;
    while (rules.state == null) {
      rules.update(_stepS, enabled: true, oneBoard: false);
      clockS += _stepS;
    }
    final spawnedAtS = clockS;
    while (rules.state?.popped != true) {
      rules.update(_stepS, enabled: true, oneBoard: false);
      clockS += _stepS;
    }
    expect(clockS - spawnedAtS, closeTo(FuseParams.startFuseMs / _msPerS, _stepS * 2));
  });

  test('after any number of snaps the fuse stays at or above minFuseMs, for a child and for an adult', () {
    for (final bot in [childBot, adultBot]) {
      final lowest = _simulate(bot).map((p) => p.lowestFuseMs).reduce((a, b) => a < b ? a : b);
      expect(lowest, greaterThanOrEqualTo(FuseParams.minFuseMs), reason: bot.name);
    }
  });

  test('a child bot still gets at least one bat in per present on average', () {
    expect(_meanBats(_simulate(childBot)), greaterThanOrEqualTo(1));
  });

  test('an adult bot makes more bats per present than a child bot', () {
    expect(_meanBats(_simulate(adultBot)), greaterThan(_meanBats(_simulate(childBot))));
  });
}
