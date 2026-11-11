import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart' show RoundResult;
import 'package:puzzle_game/puzzle_game.dart' show Chaos, PuzzleSettings;

import '../providers.dart';
import 'night_award_results.dart';
import 'night_awards.dart';
import 'night_state.dart';

/// What a night's round scores at (design section 2 N3): the game multiplies
/// every award by this, so a night's rounds score as a plain one does and its
/// last round scores double.
const nightPointsScale = 1;
const lastRoundPointsScale = 2;

/// Whether a night can pick a Bumper Round (design section 2 N6): it can, now
/// that the Arena reports its round ([RoundResult]) and its waiting card and
/// results card are there (M14 b2). The start card and the scoreboard show the
/// button live, and a round it starts records into the night as any other.
const nightBumperRoundReady = true;

/// The night's Chaos touches, in one place (design section 5, G3): the start
/// card says the cat may visit while the host's Chaos setting is on, and the
/// night's last round keeps it away.
///
/// Both read the host's saved [PuzzleSettings.chaos] (job a2): the night has no
/// Chaos setting of its own.
abstract final class NightChaos {
  /// Whether the cat may visit tonight, for the start card's line (design
  /// section 4: it says so when Chaos isn't off).
  static bool catVisitsTonight(PuzzleSettings settings) => settings.chaos != Chaos.off;

  /// A night round's settings (design sections 4 and 5): the game counts points
  /// because it is a night, at the night's scale, doubled in the last round
  /// (N3), and the last round has the cat sit it out (G3: "none in a night's
  /// last round"). Everything else is the host's own settings, so a round of a
  /// night plays the game with the host's tolerances, speeds, time limit and
  /// Chaos.
  static PuzzleSettings settingsForRound(PuzzleSettings settings, {required bool lastRound}) {
    final night = settings
        .withValue('night', true)
        .withValue('pointsScale', lastRound ? lastRoundPointsScale : nightPointsScale);
    return lastRound ? night.withValue('chaos', Chaos.off.name) : night;
  }
}

/// The night running on this host (design section 2 N5), or null when no night
/// is running: the picker's Party night card opens the start card then, and the
/// scoreboard resumes a night that is still going.
///
/// A night starts on its start card's first game button, records each round on
/// the results' Next, and ends after the final scores or when the host answers
/// "End the party night?" with Yes. Nothing is saved: the hall of fame is M15.
/// Nothing in a game imports it: a game only builds a [RoundResult].
class PartyNight extends Notifier<NightState?> {
  @override
  NightState? build() {
    // A player who leaves keeps their row (design section 4): the night
    // remembers every player the roster shows while it runs, and the row goes
    // greyed rather than away.
    ref.listen(gamePlayersProvider, (_, players) {
      final night = state;
      if (night != null) state = night.remember(players);
    });
    return null;
  }

  /// Starts a night of [length] rounds playing for [awards], with the players
  /// joined now (the rest join at 0, design section 4). A night already
  /// running is left as it is.
  void start({required NightLength length, required List<NightAward> awards}) {
    if (state != null) return;
    state = NightState.start(length: length, awards: awards, players: ref.read(gamePlayersProvider));
  }

  /// Records a round played (N1, N5): its points, already scaled by the game
  /// (N3), and the counters the awards need. The final round's record leaves
  /// the night over and decides its three awards (G4), so the reveal and the
  /// final scores follow.
  void recordRound(RoundResult result) {
    final night = state;
    if (night == null || night.isOver) return;
    final recorded = night.remember(ref.read(gamePlayersProvider)).record(result);
    state = recorded.isOver ? recorded.awarded(_decide(recorded)) : recorded;
  }

  /// Notes the Arena map a round started on (party-night §7b): the night's
  /// Bumper Rounds each start on Surprise me, which picks a map it hasn't used.
  void usedMap(String mapId) {
    final night = state;
    if (night != null) state = night.usedMap(mapId);
  }

  /// The night's three awards, from the counters it has summed: the players it
  /// has met are the only ones who may win (so Robo never does).
  List<NightAwardOutcome> _decide(NightState night) => decideAwards(
    awards: night.awards,
    counters: night.counters,
    roundsWon: night.roundsWon,
    lastRoundPoints: night.lastRoundPoints,
    people: night.seen.keys.toSet(),
  );

  /// Ends the night, clearing it: the final scores' "Back to games" and the
  /// scoreboard's "End the party night?" Yes both do this, so the picker's card
  /// opens a fresh start card afterwards.
  void end() => state = null;
}

/// The night running on this host, or null: see [PartyNight].
final partyNightProvider = NotifierProvider<PartyNight, NightState?>(PartyNight.new);
