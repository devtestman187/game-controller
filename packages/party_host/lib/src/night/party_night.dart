import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart' show RoundResult;
import 'package:metrics/metrics.dart' show RoundTag;
import 'package:puzzle_game/puzzle_game.dart' show Chaos, PuzzleSettings;

import '../providers.dart';
import 'night_awards.dart';
import 'night_save.dart';
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
  /// last round"). A Kids night caps the cat at A little (owner, Nov 26): it
  /// never raises a setting, so Off stays Off. Everything else is the host's
  /// own settings, so a round of a night plays the game with the host's
  /// tolerances, speeds, time limit and Chaos.
  static PuzzleSettings settingsForRound(PuzzleSettings settings, {required bool lastRound, bool kids = false}) {
    final night = settings
        .withValue('night', true)
        .withValue('pointsScale', lastRound ? lastRoundPointsScale : nightPointsScale);
    final capped = kids && settings.chaos == Chaos.party ? night.withValue('chaos', Chaos.little.name) : night;
    return lastRound ? capped.withValue('chaos', Chaos.off.name) : capped;
  }
}

/// The night running on this host (design section 2 N5), or null when no night
/// is running: the picker's Party night card opens the start card then, and the
/// scoreboard resumes a night that is still going.
///
/// A night starts on its start card's first game button, records each round on
/// the results' Next, and ends after the final scores or when the host answers
/// "End the party night?" with Yes. The night is saved after each change and
/// resumes when the host restarts (NightSave); the hall of fame is M15.
/// Nothing in a game imports it: a game only builds a [RoundResult].
class PartyNight extends Notifier<NightState?> {
  @override
  NightState? build() {
    // A player who leaves keeps their row (design section 4): the night
    // remembers every player the roster shows while it runs, and the row goes
    // greyed rather than away.
    ref.listen(gamePlayersProvider, (_, players) {
      final night = state;
      if (night != null) _set(night.remember(players));
    });
    return ref.read(nightSaveProvider).load();
  }

  /// Starts a night of [length] rounds playing for [awards], with the players
  /// joined now (the rest join at 0, design section 4). A night already
  /// running is left as it is.
  void start({required NightLength length, required List<NightAward> awards}) {
    if (state != null) return;
    _set(NightState.start(length: length, awards: awards, players: ref.read(gamePlayersProvider)));
  }

  /// Records a round played (N1, N5): its points, already scaled by the game
  /// (N3), and the counters the awards need. The final round's record leaves
  /// the night over and decides its three awards (G4), so the reveal and the
  /// final scores follow.
  void recordRound(RoundResult result) {
    final night = state;
    if (night == null || night.isOver) return;
    final recorded = night.remember(ref.read(gamePlayersProvider)).record(result);
    _set(recorded.isOver ? recorded.withAwards() : recorded);
  }

  /// Ends the night on the round just played (B-021), before its last one: it
  /// records that round as [recordRound] does, then ends the night, so its
  /// awards are decided as the last round's are and the reveal, then the final
  /// scores, follow. The night keeps what it has: every round played, their
  /// points and their awards.
  void endNow(RoundResult result) {
    final night = state;
    if (night == null || night.isOver) return;
    final recorded = night.remember(ref.read(gamePlayersProvider)).record(result).endedEarly();
    _set(recorded.withAwards());
  }

  /// Notes the Arena map a round started on (party-night §7b): the night's
  /// Bumper Rounds each start on Surprise me, which picks a map it hasn't used.
  void usedMap(String mapId) {
    final night = state;
    if (night != null) _set(night.usedMap(mapId));
  }

  /// Ends the night, clearing it: the final scores' "Back to games" and the
  /// scoreboard's "End the party night?" Yes both do this, so the picker's card
  /// opens a fresh start card afterwards.
  void end() => _set(null);

  /// Drops a night the host never played (B-032): one whose round 1 was left
  /// before any round was recorded leaves nothing behind, so the start card is
  /// a fresh pick again. A night with a recorded round is kept.
  void dropIfUnplayed() {
    final night = state;
    if (night != null && night.round == 0) _set(null);
  }

  /// Sets the night, and saves it, or clears the save when no night runs (NightSave).
  void _set(NightState? night) {
    state = night;
    final save = ref.read(nightSaveProvider);
    if (night == null) {
      save.clear();
    } else {
      save.save(night);
    }
  }
}

/// The night running on this host, or null: see [PartyNight].
final partyNightProvider = NotifierProvider<PartyNight, NightState?>(PartyNight.new);

/// The round a night's next round is, for a viewer's "Round N of M" (M16 A2):
/// its number from 1 and how many the night runs, or null outside a night. Both
/// game screens pass it to their view when the round starts, as they do the
/// tags, since the night counts the round only when it ends.
({int round, int rounds})? nightRoundNumbers(NightState? night) =>
    night == null ? null : (round: night.round + 1, rounds: night.rounds);

/// The tags a round started while [night] runs puts on its summary (M14's "By
/// game and feature"): `night_2of3` for the night's second round of three, or
/// none outside a night. Both game screens read it when the round starts, since
/// the night counts the round only when it ends.
List<String> nightRoundTags(NightState? night) {
  final numbers = nightRoundNumbers(night);
  return numbers == null ? const [] : [RoundTag.of(RoundTag.night, '${numbers.round}of${numbers.rounds}')];
}
