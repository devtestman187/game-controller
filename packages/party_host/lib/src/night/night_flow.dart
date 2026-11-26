import 'package:flutter/foundation.dart';

/// Why a round was skipped or rerolled, or why a player left: a reason code, never a name.
enum NightReason {
  /// The host chose it.
  host,

  /// No player is left to play.
  noPlayers,

  /// A player left the night.
  playerLeft,

  /// The round's time ran out.
  timeUp,

  /// The round could not be played.
  unavailable,
}

/// Where a night is now (design section 4's flow, in the order the TV shows it).
enum NightStage {
  /// The start card, before round 1.
  setup,

  /// A round's how-to card.
  howTo,

  /// The round is being played.
  round,

  /// The round has finished; its scores are not shown yet.
  roundEnd,

  /// The scoreboard after a round.
  scoreboard,

  /// The last-round ceremony.
  ceremony,

  /// The night is over: no event is accepted.
  ended,
}

/// One step of a night. Each event carries facts only (round numbers, the last-round flag, avatar ids and reason
/// codes), never a nickname, so a log of events can be shared without names.
@immutable
sealed class NightEvent {
  const NightEvent();

  /// The event's facts by name.
  Map<String, Object?> get facts;

  @override
  bool operator ==(Object other) =>
      other is NightEvent && other.runtimeType == runtimeType && mapEquals(other.facts, facts);

  @override
  int get hashCode => Object.hashAll([runtimeType, ...facts.values]);

  @override
  String toString() => '$runtimeType$facts';
}

/// The night's rounds are set: the start card names how many there are. Changes nothing.
final class NightSetup extends NightEvent {
  const NightSetup(this.rounds);

  /// How many rounds the night plays.
  final int rounds;

  @override
  Map<String, Object?> get facts => {'rounds': rounds};
}

/// A round's how-to card is shown.
final class NightHowTo extends NightEvent {
  const NightHowTo(this.round);

  /// The round the card is for.
  final int round;

  @override
  Map<String, Object?> get facts => {'round': round};
}

/// A round starts being played.
final class NightRoundStarted extends NightEvent {
  const NightRoundStarted(this.round, this.lastRound);

  /// The round that starts.
  final int round;

  /// Whether this is the night's last round.
  final bool lastRound;

  @override
  Map<String, Object?> get facts => {'round': round, 'lastRound': lastRound};
}

/// The last round is announced as doubled. Changes nothing.
final class NightLastRoundDoubled extends NightEvent {
  const NightLastRoundDoubled(this.round);

  /// The last round.
  final int round;

  @override
  Map<String, Object?> get facts => {'round': round};
}

/// A round finishes playing.
final class NightRoundEnded extends NightEvent {
  const NightRoundEnded(this.round, this.lastRound);

  /// The round that ended.
  final int round;

  /// Whether it was the night's last round.
  final bool lastRound;

  @override
  Map<String, Object?> get facts => {'round': round, 'lastRound': lastRound};
}

/// The scoreboard for a round is shown.
final class NightScoreboard extends NightEvent {
  const NightScoreboard(this.round, this.lastRound);

  /// The round whose scores are shown.
  final int round;

  /// Whether it was the night's last round.
  final bool lastRound;

  @override
  Map<String, Object?> get facts => {'round': round, 'lastRound': lastRound};
}

/// The last-round ceremony starts.
final class NightCeremony extends NightEvent {
  const NightCeremony();

  @override
  Map<String, Object?> get facts => const {};
}

/// The night is over.
final class NightEnded extends NightEvent {
  const NightEnded();

  @override
  Map<String, Object?> get facts => const {};
}

/// The round is skipped. Changes nothing.
final class NightRoundSkipped extends NightEvent {
  const NightRoundSkipped(this.round, this.reason);

  /// The round skipped.
  final int round;

  /// Why it was skipped.
  final NightReason reason;

  @override
  Map<String, Object?> get facts => {'round': round, 'reason': reason};
}

/// The round is rerolled (played again with new content). Changes nothing.
final class NightRoundRerolled extends NightEvent {
  const NightRoundRerolled(this.round, this.reason);

  /// The round rerolled.
  final int round;

  /// Why it was rerolled.
  final NightReason reason;

  @override
  Map<String, Object?> get facts => {'round': round, 'reason': reason};
}

/// The round in play is paused.
final class NightPaused extends NightEvent {
  const NightPaused(this.round);

  /// The round paused.
  final int round;

  @override
  Map<String, Object?> get facts => {'round': round};
}

/// The paused round carries on.
final class NightResumed extends NightEvent {
  const NightResumed(this.round);

  /// The round resumed.
  final int round;

  @override
  Map<String, Object?> get facts => {'round': round};
}

/// A player joins between rounds. Changes nothing.
final class NightPlayerJoined extends NightEvent {
  const NightPlayerJoined(this.avatarId, this.round);

  /// The joining player's avatar id (never their nickname).
  final String avatarId;

  /// The round the night is at.
  final int round;

  @override
  Map<String, Object?> get facts => {'avatarId': avatarId, 'round': round};
}

/// A player leaves between rounds. Changes nothing.
final class NightPlayerLeft extends NightEvent {
  const NightPlayerLeft(this.avatarId, this.round, this.reason);

  /// The leaving player's avatar id (never their nickname).
  final String avatarId;

  /// The round the night is at.
  final int round;

  /// Why they left.
  final NightReason reason;

  @override
  Map<String, Object?> get facts => {'avatarId': avatarId, 'round': round, 'reason': reason};
}

/// Where a night is: its stage, its round, how many rounds it plays and whether the round is paused. [apply] moves it
/// on one event at a time and returns null for an event that is not legal now.
@immutable
final class NightFlow {
  const NightFlow._({required this.stage, required this.round, required this.rounds, required this.paused});

  /// A night of [rounds] rounds before anything has happened: the setup stage, round 0.
  static NightFlow start(int rounds) {
    assert(rounds > 0, 'a night plays at least one round');
    return NightFlow._(stage: NightStage.setup, round: 0, rounds: rounds, paused: false);
  }

  /// The stage the night is in.
  final NightStage stage;

  /// The round in play or last played; 0 before the first.
  final int round;

  /// How many rounds the night plays.
  final int rounds;

  /// Whether the round in play is paused.
  final bool paused;

  /// Whether [round] is the night's last round.
  bool get isLastRound => round == rounds;

  /// The state after [event], or null when [event] is not legal now. An event that changes nothing returns this flow.
  NightFlow? apply(NightEvent event) {
    if (stage == NightStage.ended) return null;
    return switch (event) {
      NightSetup(rounds: final n) => n == rounds && stage == NightStage.setup && round == 0 ? this : null,
      NightHowTo(round: final r) => _canHowTo(r) ? _move(NightStage.howTo, toRound: r) : null,
      NightRoundStarted(round: final r, lastRound: final last) =>
        stage == NightStage.howTo && _matches(r, last) ? _move(NightStage.round, toRound: r) : null,
      NightLastRoundDoubled(round: final r) => _inHowToOrRound && r == round && isLastRound ? this : null,
      NightRoundEnded(round: final r, lastRound: final last) =>
        stage == NightStage.round && _matches(r, last) ? _move(NightStage.roundEnd) : null,
      NightScoreboard(round: final r, lastRound: final last) =>
        stage == NightStage.roundEnd && _matches(r, last) ? _move(NightStage.scoreboard) : null,
      NightCeremony() => stage == NightStage.scoreboard && isLastRound ? _move(NightStage.ceremony) : null,
      NightEnded() => stage == NightStage.ceremony ? _move(NightStage.ended) : null,
      NightRoundSkipped(round: final r) => _inHowToOrRound && r == round ? this : null,
      NightRoundRerolled(round: final r) => _inHowToOrRound && r == round ? this : null,
      NightPaused(round: final r) =>
        stage == NightStage.round && !paused && r == round ? _move(NightStage.round, paused: true) : null,
      NightResumed(round: final r) =>
        stage == NightStage.round && paused && r == round ? _move(NightStage.round) : null,
      NightPlayerJoined(round: final r) => _between && r == round ? this : null,
      NightPlayerLeft(round: final r) => _between && r == round ? this : null,
    };
  }

  /// A how-to card comes after the start card or a scoreboard, and only for the next round that exists.
  bool _canHowTo(int next) =>
      (stage == NightStage.setup || stage == NightStage.scoreboard) && next == round + 1 && next <= rounds;

  /// The event's round and last-round flag match this flow's round.
  bool _matches(int eventRound, bool lastRound) => eventRound == round && lastRound == isLastRound;

  bool get _inHowToOrRound => stage == NightStage.howTo || stage == NightStage.round;

  /// Between rounds: the start card, a how-to card, the round end and the scoreboard.
  bool get _between =>
      stage == NightStage.setup ||
      stage == NightStage.howTo ||
      stage == NightStage.roundEnd ||
      stage == NightStage.scoreboard;

  /// The flow in [next] stage, at [toRound] (this round when null), paused or not.
  NightFlow _move(NightStage next, {int? toRound, bool paused = false}) =>
      NightFlow._(stage: next, round: toRound ?? round, rounds: rounds, paused: paused);
}
