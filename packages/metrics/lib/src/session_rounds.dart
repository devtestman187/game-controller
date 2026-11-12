part of 'session.dart';

/// A session's rounds (M14, M15): starting one, ending it, and the host
/// device's battery and heat at its edges. A part of `session.dart`, so the
/// collector keeps its fields to itself and the class stays the size the
/// coding guidelines ask (§3).
extension SessionRounds on SessionCollector {
  /// A round started at the rate of the view that runs it (m12 §0.4): [hz] is
  /// null when the host keeps the game on its own screen, and the round then
  /// has no rate to be filed under.
  void roundStarted({int? hz}) {
    _inGame = true;
    _roundHz = hz != null && hz >= minViewHz && hz <= maxViewHz ? hz : null;
  }

  /// A round ended. [modes] is each player's mode; [winnerId] won, or
  /// [winnerIds] (a team) did; [draw]: a race nobody won. The round keeps the
  /// rate of the view it started at.
  ///
  /// [abandoned] is a round nobody played, which the games write when the host
  /// abandons one (M14 design section 2 N1): it adds no round, no count and no
  /// game time, but it still ends the game.
  ///
  /// [tags] say what the round was (M14's "By game and feature"): the game
  /// and the host write short `kind_value` strings such as `mode_bumper`,
  /// `map_playroom` or `night_2of3` ([RoundTag] names the kinds the report
  /// reads). A string that isn't one of those is dropped, a tag a reader
  /// doesn't know is ignored, and a round from before these tags has none: the
  /// summary keeps its schema either way.
  void roundEnded(
    String game, {
    required double timeS,
    required Map<String, String> modes,
    String? winnerId,
    Set<String> winnerIds = const {},
    bool draw = false,
    bool abandoned = false,
    List<String> tags = const [],
  }) {
    final winners = {...winnerIds, ?winnerId};
    _inGame = false;
    if (abandoned) {
      _roundHz = null;
      return;
    }
    if (_rounds.length < 1000) {
      final roundTags = _roundTags(tags);
      _rounds.add({
        'game': game,
        'hz': ?_roundHz,
        'timeS': double.parse(timeS.toStringAsFixed(2)),
        'players': modes.length,
        'winner': ?_players[winners.firstOrNull]?.number,
        if (winners.length > 1) 'winners': [for (final id in winners) ?_players[id]?.number],
        if (draw) 'draw': true,
        if (roundTags.isNotEmpty) 'tags': roundTags,
      });
    }
    _roundHz = null;
    for (final MapEntry(key: id, value: mode) in modes.entries) {
      final p = _players[id];
      if (p == null) continue;
      final m = SessionCollector._mode(mode);
      p.modeGames[m] = (p.modeGames[m] ?? 0) + 1;
      if (draw) p.modeDraws[m] = (p.modeDraws[m] ?? 0) + 1;
      if (winners.contains(id)) {
        p.modeWins[m] = (p.modeWins[m] ?? 0) + 1;
        final counts = p.games[game] ??= {};
        counts['wins'] = (counts['wins'] ?? 0) + 1;
      }
      final counts = p.games[game] ??= {};
      counts['rounds'] = (counts['rounds'] ?? 0) + 1;
    }
  }

  /// Gives the round that just ended its battery and heat (m12 §0.8): [start]
  /// is the level when it began, [end] when it ended, [charging] whether the
  /// device was on the charger then (the report leaves such a round out of the
  /// battery drop, m12 §1), and [thermal] the device's state at the end.
  /// Nothing is written when no round is waiting (a game that didn't record a
  /// start) or when the round has them already.
  void roundBattery({double? start, double? end, String? thermal, bool charging = false}) {
    if (_rounds.isEmpty) return;
    final round = _rounds.last;
    if (round.containsKey('battery') || round.containsKey('thermal')) return;
    final battery = {'start': ?batteryLevel(start), 'end': ?batteryLevel(end), if (charging) 'charging': true};
    if (battery.isNotEmpty) round['battery'] = battery;
    if (thermal != null) round['thermal'] = thermal;
  }
}

/// The most tags a round or a rating keeps: a game writes a handful, and a
/// runaway one must not fill the summary.
const maxRoundTags = 8;

/// The tags of [tags] that look like a round's own (M14): short `kind_value`
/// strings such as `mode_bumper`, `map_toy-factory` or `night_2of3`. Anything
/// else — a name, a sentence — is dropped, so no tag can carry a person's
/// words.
List<String> _roundTags(List<String> tags) => [
  for (final tag in tags.take(maxRoundTags))
    if (_roundTagPattern.hasMatch(tag)) tag,
];

/// A round's tag: lower case and digits, with `_` between a kind and its
/// value and `-` inside a map's id (`map_toy-factory`).
final _roundTagPattern = RegExp(r'^[a-z0-9_.-]{1,32}$');
