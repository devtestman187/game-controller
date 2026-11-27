import 'package:party_host/src/night/night_director.dart';
import 'package:party_host/src/night/night_flow.dart';

/// The plain caption for [event], built from its facts only (round numbers, the last-round flag, avatar ids and reason
/// phrases), never a nickname.
///
/// Stub: Thumby (P4) replaces this; the event type does not change.
String captionFor(NightEvent event) => switch (event) {
  NightSetup(rounds: final n) => 'Tonight: $n ${n == 1 ? 'round' : 'rounds'}',
  NightHowTo(round: final r, reason: final why) =>
    why == null ? 'How to play round $r' : 'How to play round $r: ${_howToPhrase(why)}',
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
  NightPlayerJoined(avatarId: final id, round: final r) => 'Avatar $id joined ${_whenPhrase(r)}',
  NightPlayerLeft(avatarId: final id, round: final r, reason: final why) =>
    'Avatar $id left ${_whenPhrase(r)}: ${_reasonPhrase(why)}',
};

/// The suffix that marks the last round, or nothing for any other round.
String _lastSuffix(bool lastRound) => lastRound ? ' (last round)' : '';

/// When a player joined or left: round 0 is the lobby, before round 1 starts.
String _whenPhrase(int round) => round == 0 ? 'before round 1' : 'at round $round';

/// Why the round is the game it is, in plain words, for the how-to card. Exhaustive: a new rule needs its phrase here.
String _howToPhrase(DirectorReason reason) => switch (reason) {
  DirectorReason.opening => 'an easy start',
  DirectorReason.steady => 'the same level again',
  DirectorReason.easedAfterLopsided => 'an easier game, as the scores were far apart',
  DirectorReason.raisedAtCloseTable => 'a harder game, as the scores are close',
  DirectorReason.kindForLastPlace => 'a gentle game first, for the player behind',
};

/// A short phrase for why something happened.
String _reasonPhrase(NightReason reason) => switch (reason) {
  NightReason.host => 'the host chose it',
  NightReason.noPlayers => 'no players left',
  NightReason.playerLeft => 'they went away',
  NightReason.timeUp => 'time ran out',
  NightReason.unavailable => 'it could not be played',
};
