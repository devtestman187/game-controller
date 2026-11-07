import 'dart:math';

/// Delays in ms, kept as a 1 ms histogram (up to [maxMs], then one overflow
/// bin), so a whole session's medians and 95th percentiles cost a few KB
/// however long it runs.
class DelayStats {
  static const maxMs = 2000;

  final _bins = List<int>.filled(maxMs + 2, 0);
  int _count = 0;
  int _max = 0;

  int get count => _count;

  void add(int ms) {
    if (ms < 0) return;
    _bins[min(ms, maxMs + 1)]++;
    _count++;
    _max = max(_max, ms);
  }

  /// The value at fraction [q] (0.5 = median), or null without samples.
  int? quantile(double q) {
    if (_count == 0) return null;
    final rank = (q * (_count - 1)).round() + 1;
    var seen = 0;
    for (var i = 0; i < _bins.length; i++) {
      seen += _bins[i];
      if (seen >= rank) return i > maxMs ? _max : i;
    }
    return _max;
  }

  int? get median => quantile(0.5);
  int? get p95 => quantile(0.95);
  int? get maxValue => _count == 0 ? null : _max;

  /// `{n, median, p95, max}`, or null without samples.
  Map<String, Object>? toJson() => _count == 0 ? null : {'n': _count, 'median': median!, 'p95': p95!, 'max': _max};
}

/// Decides when to show the rating prompt (PRD v2 C19): at most once every
/// few games, and not too often in time either. The first time comes after
/// a few games, so a player has had a chance to get used to the controls.
class RatingScheduler {
  RatingScheduler({this.firstAfterGames = 3, this.everyGames = 5, this.minGapMs = 3 * 60 * 1000});

  final int firstAfterGames;
  final int everyGames;
  final int minGapMs;

  final _games = <String, int>{};
  final _lastAskMs = <String, int>{};

  /// A game (an arena round) ended for [playerId] at [atMs]. True if the
  /// player is due to be asked. Nothing counts as asked until [asked] says
  /// the prompt really went out: a phone that can't show it (an app older
  /// than 0.9.0, a keyboard player) must not use up the next chance (found
  /// in the M9 device test: an M8 phone's rounds delayed the first prompt
  /// on the updated phone past the end of play).
  bool gameEnded(String playerId, int atMs) {
    final games = (_games[playerId] ?? 0) + 1;
    _games[playerId] = games;
    final last = _lastAskMs[playerId];
    return last == null ? games >= firstAfterGames : games >= everyGames && atMs - last >= minGapMs;
  }

  /// The prompt went out to [playerId] at [atMs]: the count starts again.
  void asked(String playerId, int atMs) {
    _games[playerId] = 0;
    _lastAskMs[playerId] = atMs;
  }
}
