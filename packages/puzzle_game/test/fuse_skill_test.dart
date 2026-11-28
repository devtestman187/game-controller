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

/// Most bats one present takes in the simulation: a safety stop so a present that never pops still ends. A fuse only
/// shortens (PresentRules.onSnap), so every simulated present pops first; the test checks that the cap is never hit.
const _maxBatsPerPresent = 50;

/// The seed of every simulation's draws, so both bots face the same presents on every run.
const _seed = 42;

/// One simulated present: its bats, whether the cap ended it, and how many snaps broke the snap rule: a snap that
/// raised the fuse, or took it below both the floor and the fuse it found.
typedef _Present = ({int bats, bool capped, int badSnaps});

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
  var badSnaps = 0;
  while (true) {
    final state = rules.state;
    if (state == null || state.popped) return (bats: bats, capped: false, badSnaps: badSnaps);
    if (bats == _maxBatsPerPresent) return (bats: bats, capped: true, badSnaps: badSnaps);
    if (clockS >= dueS) {
      rules.onSnap(state.holder);
      bats++;
      final after = rules.state;
      if (after != null && _breaksSnapRule(state.fuseMs, after.fuseMs)) badSnaps++;
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

/// Whether a snap that found the fuse at [beforeMs] and left it at [afterMs] broke the rule: it never raises the fuse,
/// and it takes it no lower than the floor, unless the fuse was already under the floor.
bool _breaksSnapRule(int beforeMs, int afterMs) => afterMs > beforeMs || afterMs < min(beforeMs, FuseParams.minFuseMs);

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

  test('no snap raises the fuse or takes it below minFuseMs, for a child and for an adult', () {
    for (final bot in [childBot, adultBot]) {
      final broken = _simulate(bot).fold(0, (sum, p) => sum + p.badSnaps);
      expect(broken, 0, reason: bot.name);
    }
  });

  test('no present reaches the bat cap, so every one pops, for a child and for an adult', () {
    for (final bot in [childBot, adultBot]) {
      final capped = _simulate(bot).where((p) => p.capped).length;
      expect(capped, 0, reason: bot.name);
    }
  });

  test('a child bot still gets at least one bat in per present on average', () {
    expect(_meanBats(_simulate(childBot)), greaterThanOrEqualTo(1));
  });

  test('an adult bot makes more bats per present than a child bot', () {
    expect(_meanBats(_simulate(adultBot)), greaterThan(_meanBats(_simulate(childBot))));
  });
}
