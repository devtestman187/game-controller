import 'report_table.dart';

/// The tags a round carries in the session summary (M14's "By game and
/// feature"): short `kind_value` strings, written on the round's `round_end`
/// record by the game that played it and by the host. The report groups the
/// rounds by the kinds below; a tag of any other kind is kept in the summary
/// and ignored here, so a newer game can add one without a change to the
/// report.
///
/// Nothing in a tag names a person: a map's id, a level and a round's number
/// are all a summary may say.
abstract final class RoundTag {
  /// The round reached its game's own end: the Bumper Round's clock ran out,
  /// a race reached its goal, or a Shape Race side completed the picture (the
  /// finish celebration, T15). A Shape Race round that ran out of time is not
  /// finished.
  static const finished = 'finished';

  /// The Arena's mode: `mode_race` or `mode_bumper` (M14 G9).
  static const mode = 'mode';

  /// The Arena's map, by id: `map_playroom`, `map_toy-factory` (M14 k1b).
  static const map = 'map';

  /// Robo's level, on the rounds Robo had a seat in: `robo_easy`,
  /// `robo_medium`, `robo_hard` (party-night §7a).
  static const robo = 'robo';

  /// Shape Race's Chaos level: `chaos_off`, `chaos_little`, `chaos_party`
  /// (M14 G3).
  static const chaos = 'chaos';

  /// A party night's round: `night_1of3` … `night_3of3` (M14 G2). A night
  /// starts with its 1-of round and ends with its last one.
  static const night = 'night';

  /// [kind] and [value] as one tag.
  static String of(String kind, String value) => '${kind}_$value';

  /// [tag]'s value when its kind is [kind], or null for a tag of another kind.
  static String? valueOf(String tag, String kind) => tag.startsWith('${kind}_') ? tag.substring(kind.length + 1) : null;
}

/// A round is in seconds and the table shows minutes.
const _minuteS = 60.0;

/// Where each kind of row sits in the table: its kind first, then its name, so
/// the games and their modes come first and the rounds no tag can place last.
abstract final class _Group {
  static const game = '0';
  static const map = '1';
  static const robo = '2';
  static const chaos = '3';
  static const night = '4';
  static const unknown = '9';
}

/// The columns of "By game and feature" (M14).
const _headers = ['group', 'rounds', 'minutes', 'players', 'avg players', 'finished', 'good', 'okay', 'bad'];

/// One row of "By game and feature" (M14): what the rounds of one kind add up
/// to. A round counts in every row its tags name — its game and mode, its map,
/// Robo's level, its Chaos level and the night's round — so the rows answer
/// different questions about the same rounds; a rating counts where the round
/// it asked about counts.
final class FeatureRow {
  FeatureRow({required this.label, required this.sortKey});

  /// The row's first cell: `arena bumper`, `map playroom`, `robo easy`, ….
  final String label;

  /// Where the row sits in the table ([_Group] and its name).
  final String sortKey;

  /// The rounds counted here, their time in seconds and the players in them.
  int rounds = 0;
  double seconds = 0;
  int players = 0;

  /// The rounds that reached their game's own end ([RoundTag.finished]).
  int finished = 0;

  /// The ratings the rounds' players gave, by face.
  int good = 0;
  int okay = 0;
  int bad = 0;

  /// The row's rounds in minutes.
  double get minutes => seconds / _minuteS;

  /// How many players a round here had on average, or 0 with no round.
  double get averagePlayers => rounds == 0 ? 0 : players / rounds;

  /// The ratings in the row, whatever they said.
  int get ratings => good + okay + bad;

  /// Adds one round of the row: its time, its players and whether it finished.
  void addRound(Map round, {required bool finished}) {
    rounds++;
    seconds += _seconds(round['timeS']);
    players += _int(round['players']);
    if (finished) this.finished++;
  }

  /// Adds one rating's face; a skipped answer has none and isn't added.
  void addRating(String face) {
    switch (face) {
      case 'good':
        good++;
      case 'okay':
        okay++;
      case 'bad':
        bad++;
    }
  }
}

/// The rows of "By game and feature", from every session's rounds and the
/// ratings their players gave, keyed so that one row collects one kind.
///
/// A round with no tags counts as `unknown` rather than disappearing: it is
/// from a session before M14 recorded them, or from a game that writes none.
/// A rating always names its game; the host also copies the tags of the round
/// it asked about onto it, and a rating without them counts as `unknown` too.
Map<String, FeatureRow> gameFeatureRows(List<Map<String, Object?>> summaries) {
  final rows = <String, FeatureRow>{};
  for (final summary in summaries) {
    for (final round in (summary['rounds'] as List?) ?? const []) {
      if (round is! Map) continue;
      final features = _Features.ofRound(round);
      _addRows(rows, features, (row) => row.addRound(round, finished: features.finished));
    }
    for (final player in (summary['players'] as List?) ?? const []) {
      if (player is! Map) continue;
      for (final rating in (player['ratings'] as List?) ?? const []) {
        if (rating is! Map) continue;
        final face = rating['face'];
        if (face is! String) continue; // A skipped answer says nothing.
        _addRows(rows, _Features.ofRating(rating), (row) => row.addRating(face));
      }
    }
  }
  return rows;
}

/// The report's "By game and feature" table (M14): one row per game and mode,
/// then rows per map, Robo's level, Chaos level and night round, and the rounds
/// an older session recorded before these tags, which count as `unknown`.
String gameFeatureTable(List<Map<String, Object?>> summaries) {
  final rows = gameFeatureRows(summaries).values.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  return plainTable('By game and feature', _headers, [for (final row in rows) _cells(row)]);
}

/// The least a night's tags say: which of the night's rounds one was, of how
/// many.
typedef _NightRound = ({int round, int rounds});

/// The report's party-night line (M14 G2): the nights the sessions ran — a
/// night starts with its first round and ends with its last — and how many
/// rounds one lasted on average.
///
/// A night's round 2 can be the first one a session sees (the session before
/// it ended while the night went on), so the rounds are counted apart from the
/// nights they started in.
String partyNights(List<Map<String, Object?>> summaries) {
  var started = 0;
  var ended = 0;
  var rounds = 0;
  for (final summary in summaries) {
    for (final round in (summary['rounds'] as List?) ?? const []) {
      if (round is! Map) continue;
      final night = _nightOf(_tags(round['tags']));
      if (night == null) continue;
      rounds++;
      if (night.round == 1) started++;
      if (night.round == night.rounds) ended++;
    }
  }
  if (rounds == 0) return 'Party nights: none\n';
  final perNight = started == 0 ? '-' : (rounds / started).toStringAsFixed(1);
  return 'Party nights: $started started, $ended finished, $perNight rounds a night\n';
}

/// What one round, or one rating's round, was: its game and its tags. The
/// report reads both the same way, so a rating counts in the rows of the round
/// it asked about.
final class _Features {
  _Features(this.game, this.tags);

  /// The round a summary recorded.
  factory _Features.ofRound(Map round) => _Features(_game(round['game']), _tags(round['tags']));

  /// The round a rating asked about: its answer carries the round's tags.
  factory _Features.ofRating(Map rating) => _Features(_game(rating['game']), _tags(rating['round']));

  /// The game's name in the records, or `unknown` when the round names none.
  final String game;

  /// The round's tags, in the order it wrote them.
  final List<String> tags;

  /// Whether the round reached its game's own end ([RoundTag.finished]).
  bool get finished => tags.contains(RoundTag.finished);
}

/// Adds one round's or one rating's counts to the rows it belongs to.
void _addRows(Map<String, FeatureRow> rows, _Features features, void Function(FeatureRow row) add) {
  if (features.tags.isEmpty) {
    add(_rowAt(rows, _Group.unknown, 'unknown', 'unknown'));
    return;
  }
  final mode = _valuesOf(features.tags, RoundTag.mode).firstOrNull;
  add(_rowAt(rows, _Group.game, '${features.game} ${mode ?? ''}', _gameLabel(features.game, mode)));
  for (final id in _valuesOf(features.tags, RoundTag.map)) {
    add(_rowAt(rows, _Group.map, id, 'map $id'));
  }
  for (final level in _valuesOf(features.tags, RoundTag.robo)) {
    add(_rowAt(rows, _Group.robo, level, 'robo $level'));
  }
  for (final chaos in _valuesOf(features.tags, RoundTag.chaos)) {
    add(_rowAt(rows, _Group.chaos, chaos, 'chaos $chaos'));
  }
  if (_nightOf(features.tags) case final night?) {
    final round = night.round.toString().padLeft(2, '0');
    final rounds = night.rounds.toString().padLeft(2, '0');
    add(_rowAt(rows, _Group.night, '$round $rounds', 'night ${night.round} of ${night.rounds}'));
  }
}

/// The row of [kind] and [key], made on its first use.
FeatureRow _rowAt(Map<String, FeatureRow> rows, String kind, String key, String label) =>
    rows['$kind $key'] ??= FeatureRow(label: label, sortKey: '$kind $key');

/// The game row's cell: the game and its mode, or the game alone when it has
/// none (Shape Race plays one way; the Arena two).
String _gameLabel(String game, String? mode) => mode == null ? game : '$game $mode';

/// The values of the tags of [kind] in [tags], in the order they came.
List<String> _valuesOf(List<String> tags, String kind) {
  final values = <String>[];
  for (final tag in tags) {
    if (RoundTag.valueOf(tag, kind) case final value?) values.add(value);
  }
  return values;
}

/// The night's round a tag list names, or null when it is no night's round.
///
/// The value is `NofM` (`2of3`): a round of a night that plays fewer rounds
/// than its round's number, or one that isn't a number, is left out rather
/// than guessed at.
_NightRound? _nightOf(List<String> tags) {
  for (final value in _valuesOf(tags, RoundTag.night)) {
    final parts = value.split('of');
    if (parts.length != 2) continue;
    final round = int.tryParse(parts[0]);
    final rounds = int.tryParse(parts[1]);
    if (round != null && rounds != null && round >= 1 && round <= rounds) return (round: round, rounds: rounds);
  }
  return null;
}

/// One row's cells, in the columns' order. A row no one rated shows a dash, so
/// a dash means "nobody said" and a zero means "nobody said bad".
List<String> _cells(FeatureRow row) => [
  row.label,
  '${row.rounds}',
  row.minutes.toStringAsFixed(1),
  '${row.players}',
  row.averagePlayers.toStringAsFixed(1),
  '${row.finished}',
  if (row.ratings == 0) ...const ['-', '-', '-'] else ...['${row.good}', '${row.okay}', '${row.bad}'],
];

/// The game a round or a rating names, or `unknown` when it names none.
String _game(Object? value) => value is String && value.isNotEmpty ? value : 'unknown';

/// The tags a round or a rating carries, since a summary's JSON may hold
/// anything.
List<String> _tags(Object? value) => [
  for (final tag in (value as List?) ?? const [])
    if (tag is String) tag,
];

double _seconds(Object? value) => value is num ? value.toDouble() : 0;

int _int(Object? value) => value is num ? value.round() : 0;
