import 'package:connection/connection.dart' show GamePlayer;
import 'package:protocol/protocol.dart';

import 'night_award_results.dart';
import 'night_state.dart';
import 'round_results.dart';

/// The message that ends the night on every phone (M16 bugs4 nh2): the night's
/// awards in the order the host revealed them, and the final standings with
/// their award points. The host sends it once, when the awards reveal ends or
/// is skipped, so a phone's own night ends with the host's.
///
/// [players] is the roster now, for the standings' names and characters.
NightEndMessage nightEndFor(NightState night, List<GamePlayer> players) => NightEndMessage(
  awards: [
    for (final outcome in night.outcomes)
      NightAwardRow(
        id: outcome.award.name,
        name: outcome.award.title,
        points: outcome.isWon ? awardPoints : 0,
        winners: outcome.winners,
        reason: outcome.reason,
      ),
  ],
  standings: viewStandingsOf(night.rows(players)),
);
