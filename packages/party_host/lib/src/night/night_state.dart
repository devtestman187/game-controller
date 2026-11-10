import 'package:connection/connection.dart' show GamePlayer;
import 'package:flutter/foundation.dart';
import 'package:game_kit/game_kit.dart' show RoundResult;
import 'package:protocol/protocol.dart' show PlayerCharacter;

import 'night_awards.dart';

/// How many rounds a night plays (design section 4: "3 rounds" / "5 rounds").
enum NightLength {
  three(3),
  five(5);

  const NightLength(this.rounds);

  /// The night's rounds.
  final int rounds;
}

/// Who a player the night remembers is: their number, nickname and character,
/// kept when they leave so their row stays on the scoreboard, greyed (design
/// section 4), wearing what the host gave them (M14 L7).
typedef NightPlayer = ({int number, String? nickname, PlayerCharacter? character});

/// One player's row on the scoreboard (design section 4): their place, badge,
/// nickname, total and what the last round added.
@immutable
final class NightRow {
  const NightRow({
    required this.id,
    required this.number,
    required this.nickname,
    required this.total,
    required this.roundPoints,
    required this.place,
    required this.tied,
    required this.isHere,
    this.character,
  });

  /// The player's controller id: the night's key for them (N2).
  final String id;

  /// Their number, 1 to 6, or 0 when the night never met them (a result that
  /// names a player who left before the night heard of them): the row then
  /// draws no badge.
  final int number;

  /// Their nickname, when they have one.
  final String? nickname;

  /// Every round's points added up.
  final int total;

  /// What the last recorded round gave them: "+7" on the scoreboard (design
  /// section 4). Zero before any round is recorded.
  final int roundPoints;

  /// 1, 2, 3…, shared by the players level with them ("3=").
  final int place;

  /// Whether another player has the same [total].
  final bool tied;

  /// Whether this player is on the roster now; a leaver's row stays, greyed,
  /// and stops being greyed if they come back (design section 4).
  final bool isHere;

  /// The colour and accessory the host gave them (M14 L7), or null when the
  /// night never saw one: the row then wears their number's default.
  final PlayerCharacter? character;
}

/// The party night's state (design section 2 N5): its rounds, the round now,
/// each player's total keyed by controller id (N2), the three awards drawn, the
/// counters the awards need, and who has played.
///
/// It knows only [RoundResult] of the games (N1): a game's points arrive
/// already scaled (N3), so a last round's double needs nothing here. It is a
/// value: [record] and [remember] return the night's next state.
@immutable
final class NightState {
  NightState._({
    required this.length,
    required this.round,
    required this.awards,
    required Map<String, int> totals,
    required Map<String, Map<String, int>> counters,
    required Map<String, int> roundsWon,
    required Set<String> played,
    required Map<String, int> lastRoundPoints,
    required Map<String, NightPlayer> seen,
  }) : totals = Map.unmodifiable(totals),
       counters = Map.unmodifiable({
         for (final MapEntry(:key, :value) in counters.entries) key: Map<String, int>.unmodifiable(value),
       }),
       roundsWon = Map.unmodifiable(roundsWon),
       played = Set.unmodifiable(played),
       lastRoundPoints = Map.unmodifiable(lastRoundPoints),
       seen = Map.unmodifiable(seen);

  /// A night about to play its first round, with the awards drawn for it, and
  /// the players on the roster now remembered.
  factory NightState.start({
    required NightLength length,
    required List<NightAward> awards,
    Iterable<GamePlayer> players = const [],
  }) {
    assert(awards.length == nightAwardsPerNight, 'a night plays for $nightAwardsPerNight awards');
    return NightState._(
      length: length,
      round: 0,
      awards: List.unmodifiable(awards),
      totals: const {},
      counters: const {},
      roundsWon: const {},
      played: const {},
      lastRoundPoints: const {},
      seen: {for (final p in players) p.id: (number: p.number, nickname: p.nickname, character: p.character)},
    );
  }

  /// How many rounds the night plays: 3 or 5.
  final NightLength length;

  /// The rounds played so far, 0 before the first: the scoreboard's "round 2
  /// of 3" and "Pick round 3" both read it.
  final int round;

  /// The three awards drawn when the night started (design section 6).
  final List<NightAward> awards;

  /// Each player's points for the night, by controller id, all rounds added.
  final Map<String, int> totals;

  /// Each player's award counters, summed from [RoundResult.stats] over the
  /// night: `snaps`, `wrongDrops`, `carries`, `catsShooed`, `coins`… Job c2
  /// qualifies the awards from these.
  final Map<String, Map<String, int>> counters;

  /// How many rounds each player's side won: Comeback's and Round Winner's
  /// counter, which a [RoundResult] gives as its winners rather than a stat.
  final Map<String, int> roundsWon;

  /// The players who have played a round: a joiner starts at 0 and is not here
  /// until they do (design section 4).
  final Set<String> played;

  /// What the last recorded round gave each player, for the scoreboard's "+7".
  final Map<String, int> lastRoundPoints;

  /// Everyone the night has met, so a leaver keeps their badge and nickname.
  final Map<String, NightPlayer> seen;

  /// The night's rounds.
  int get rounds => length.rounds;

  /// How many rounds are still to play.
  int get roundsLeft => rounds - round;

  /// Whether every round has been played: the final scores follow (design
  /// section 6).
  bool get isOver => round >= rounds;

  /// Whether the next round is the night's last: the scoreboard shows the
  /// double-points banner before it (design section 4), and the round itself
  /// plays at the doubled scale (N3).
  bool get isNextRoundTheLast => !isOver && round + 1 >= rounds;

  /// How many rounds [playerId] has won.
  int roundsWonBy(String playerId) => roundsWon[playerId] ?? 0;

  /// One of [playerId]'s award counters, 0 when they have none.
  int counter(String playerId, String name) => counters[playerId]?[name] ?? 0;

  /// The night that has remembered [players]: the roster now, kept for the
  /// rows of players who leave it (design section 4).
  NightState remember(Iterable<GamePlayer> players) => _copyWith(
    seen: {...seen, for (final p in players) p.id: (number: p.number, nickname: p.nickname, character: p.character)},
  );

  /// The night with one more round played (design section 2 N5): its points
  /// added to each player's total, its counters summed, its winners counted.
  NightState record(RoundResult result) {
    final totals = {...this.totals};
    for (final MapEntry(:key, :value) in result.points.entries) {
      totals[key] = (totals[key] ?? 0) + value;
    }
    final counters = {
      for (final MapEntry(:key, :value) in this.counters.entries) key: {...value},
    };
    for (final MapEntry(key: id, value: stats) in result.stats.entries) {
      final mine = counters.putIfAbsent(id, () => <String, int>{});
      for (final MapEntry(:key, :value) in stats.entries) {
        mine[key] = (mine[key] ?? 0) + value;
      }
    }
    final roundsWon = {...this.roundsWon};
    for (final id in result.winners) {
      roundsWon[id] = (roundsWon[id] ?? 0) + 1;
    }
    return _copyWith(
      round: round + 1,
      totals: totals,
      counters: counters,
      roundsWon: roundsWon,
      played: {...played, ...result.points.keys, ...result.stats.keys, ...result.lines.keys, ...result.winners},
      lastRoundPoints: result.points,
    );
  }

  /// The scoreboard's rows (design section 4): every player on the roster and
  /// every player with points, in total order, ties sharing a place. A player
  /// who left keeps their row ([NightRow.isHere] says they are away).
  List<NightRow> rows(Iterable<GamePlayer> players) {
    final here = {for (final p in players) p.id: p};
    final order =
        [
          for (final id in {...here.keys, ...totals.keys}) (id: id, total: totals[id] ?? 0),
        ]..sort((a, b) {
          final byTotal = b.total.compareTo(a.total);
          return byTotal != 0 ? byTotal : _numberOf(a.id, here[a.id]).compareTo(_numberOf(b.id, here[b.id]));
        });
    return [
      for (final entry in order)
        NightRow(
          id: entry.id,
          number: _numberOf(entry.id, here[entry.id]),
          nickname: _nicknameOf(entry.id, here[entry.id]),
          character: _characterOf(entry.id, here[entry.id]),
          total: entry.total,
          roundPoints: lastRoundPoints[entry.id] ?? 0,
          place: _placeOf(entry, order),
          tied: order.where((other) => other.total == entry.total).length > 1,
          isHere: here.containsKey(entry.id),
        ),
    ];
  }

  /// 1-based place of [entry] in [order], which is sorted by total: the first
  /// player on the same total holds it.
  int _placeOf(({String id, int total}) entry, List<({String id, int total})> order) =>
      order.indexWhere((other) => other.total == entry.total) + 1;

  int _numberOf(String id, GamePlayer? player) => player?.number ?? seen[id]?.number ?? 0;

  String? _nicknameOf(String id, GamePlayer? player) => player != null ? player.nickname : seen[id]?.nickname;

  PlayerCharacter? _characterOf(String id, GamePlayer? player) =>
      player != null ? player.character : seen[id]?.character;

  NightState _copyWith({
    int? round,
    Map<String, int>? totals,
    Map<String, Map<String, int>>? counters,
    Map<String, int>? roundsWon,
    Set<String>? played,
    Map<String, int>? lastRoundPoints,
    Map<String, NightPlayer>? seen,
  }) => NightState._(
    length: length,
    round: round ?? this.round,
    awards: awards,
    totals: totals ?? this.totals,
    counters: counters ?? this.counters,
    roundsWon: roundsWon ?? this.roundsWon,
    played: played ?? this.played,
    lastRoundPoints: lastRoundPoints ?? this.lastRoundPoints,
    seen: seen ?? this.seen,
  );
}
