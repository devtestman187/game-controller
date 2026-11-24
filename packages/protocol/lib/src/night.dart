part of 'messages.dart';

/// One award of a night's awards reveal (M16 bugs4, owner B-040): the award's
/// name, the points it is worth, and who won it. An award nobody won has no
/// winners, and it may carry a [reason] for why.
final class NightAwardRow {
  const NightAwardRow({required this.id, required this.name, required this.points, required this.winners, this.reason});

  /// The award's own ID, such as `Fast`, so a phone can tell two awards apart.
  final String id;

  /// The award's name as the host shows it.
  final String name;

  /// The points the award adds to each of its winners.
  final int points;

  /// The player IDs who won the award, in the host's order. Empty when nobody
  /// won it.
  final List<String> winners;

  /// Why nobody won it, or null when the award has winners.
  final String? reason;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'pts': points, 'w': winners, 'reason': ?reason};

  static NightAwardRow fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('Field "awards" entry must be an object, got ${json.runtimeType}');
    }
    final p = json.cast<String, Object?>();
    final winners = p['w'] ?? const <Object?>[];
    if (winners is! List || winners.any((w) => w is! String)) {
      throw const FormatException('Field "awards.w" must be a list of player IDs');
    }
    return NightAwardRow(
      id: requireString(p, 'id'),
      name: requireString(p, 'name'),
      points: requireInt(p, 'pts'),
      winners: List.unmodifiable(winners.cast<String>()),
      reason: optionalString(p, 'reason'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NightAwardRow &&
      other.id == id &&
      other.name == name &&
      other.points == points &&
      _sameList(other.winners, winners) &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(id, name, points, Object.hashAll(winners), reason);
}

/// Host → controller (M16 bugs4, needs [Capability.night]): the night's final
/// awards and standings, once the host's awards reveal has ended or been
/// skipped. A phone shows them after the host reveal, as its results card.
///
/// It is sent once per night, and only to a phone that lists [Capability.night]:
/// a host never sends it to a phone one build older, and a phone with the
/// capability on an older host never gets it. The standings are the final
/// totals, award points included, first place first.
final class NightEndMessage extends Message {
  const NightEndMessage({required this.awards, required this.standings});

  static const String wireType = 'night_end';

  /// The night's awards, in the order the host revealed them.
  final List<NightAwardRow> awards;

  /// The final standings, first place first, with award points in each total.
  final List<ViewStanding> standings;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'awards': [for (final a in awards) a.toJson()],
    'standings': [for (final s in standings) s.toJson()],
  };

  static NightEndMessage fromPayload(Map<String, Object?> p) => NightEndMessage(
    awards: _list(p, 'awards').map(NightAwardRow.fromJson).toList(growable: false),
    standings: _list(p, 'standings').map(ViewStanding.fromJson).toList(growable: false),
  );

  @override
  bool operator ==(Object other) =>
      other is NightEndMessage && _sameList(other.awards, awards) && _sameList(other.standings, standings);

  @override
  int get hashCode => Object.hash(Object.hashAll(awards), Object.hashAll(standings));
}

/// Reads an optional list field. Missing means empty; anything else must be a list.
List<Object?> _list(Map<String, Object?> p, String field) {
  final value = p[field];
  if (value == null) return const [];
  if (value is! List) throw FormatException('Field "$field" must be a list, got ${value.runtimeType}');
  return value;
}

/// Whether two lists hold equal items in the same order.
bool _sameList<T>(List<T> a, List<T> b) =>
    a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
