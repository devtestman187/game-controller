import 'package:party_host/src/night/night_flow.dart';

/// The plain caption for [event], built from its facts only (round numbers, the last-round flag, avatar ids and reason
/// phrases), never a nickname.
///
/// Stub: Thumby (P4) replaces this; the event type does not change.
String captionFor(NightEvent event) => switch (event) {
  NightSetup(rounds: final n) => 'Tonight: $n rounds',
  NightHowTo(round: final r) => 'How to play round $r',
  NightRoundStarted(round: final r, lastRound: final last) => 'Round $r starts${_lastSuffix(last)}',
  NightLastRoundDoubled(round: final r) => 'Round $r is the last round: doubled points',
  NightRoundEnded(round: final r, lastRound: final last) => 'Round $r is over${_lastSuffix(last)}',
  NightScoreboard(round: final r, lastRound: final last) => 'Scoreboard after round $r${_lastSuffix(last)}',
  NightCeremony() => 'The ceremony begins',
  NightEnded() => 'The night is over',
  NightRoundSkipped(round: final r, reason: final why) => 'Round $r skipped: ${_reasonPhrase(why)}',
  NightRoundRerolled(round: final r, reason: final why) => 'Round $r rerolled: ${_reasonPhrase(why)}',
  NightPaused(round: final r) => 'Round $r paused',
  NightResumed(round: final r) => 'Round $r resumed',
  NightPlayerJoined(avatarId: final id, round: final r) => 'Avatar $id joined at round $r',
  NightPlayerLeft(avatarId: final id, round: final r, reason: final why) =>
    'Avatar $id left at round $r: ${_reasonPhrase(why)}',
};

/// The suffix that marks the last round, or nothing for any other round.
String _lastSuffix(bool lastRound) => lastRound ? ' (last round)' : '';

/// A short phrase for why something happened.
String _reasonPhrase(NightReason reason) => switch (reason) {
  NightReason.host => 'the host chose it',
  NightReason.noPlayers => 'no players left',
  NightReason.playerLeft => 'a player left',
  NightReason.timeUp => 'time ran out',
  NightReason.unavailable => 'it could not be played',
};
