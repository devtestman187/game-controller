part of 'messages.dart';

/// How a round went for the player whose phone shows the result (M14 design
/// section 9), in [ViewResult.outcome].
abstract final class ViewOutcome {
  /// Their side won.
  static const win = 'win';

  /// Their side lost.
  static const loss = 'loss';

  /// The win is shared, or nobody won.
  static const draw = 'draw';

  /// A round with no one to lose to (a board played alone) finished.
  static const done = 'done';

  static const all = [win, loss, draw, done];
}

/// What a [ViewResult]'s count counts, in [ViewResult.countOf].
abstract final class ViewCount {
  /// Pieces placed on the player's side of the board.
  static const pieces = 'pieces';

  /// Coins picked up in the Arena.
  static const coins = 'coins';

  static const all = [pieces, coins];
}

/// One row of a night's standings on a joined phone's results card (M14
/// design section 9): who, their points, and the character their badge wears.
final class ViewStanding {
  const ViewStanding({required this.number, required this.name, required this.points, required this.character});

  /// The player's number, 1 to 6.
  final int number;

  /// Their nickname, or their player label when they have none.
  final String name;

  /// Every round's points added up.
  final int points;

  /// The colour and accessory the host gave them.
  final PlayerCharacter character;

  Map<String, Object?> toJson() => {'n': number, 'name': name, 'pts': points, 'character': character.toJson()};

  static ViewStanding fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('Field "result.standings" entry must be an object, got ${json.runtimeType}');
    }
    final number = json['n'];
    if (number is! int || number < 1) {
      throw FormatException('Field "result.standings.n" must be 1 or more, got $number');
    }
    final name = json['name'];
    if (name is! String) {
      throw FormatException('Field "result.standings.name" must be a string, got ${name.runtimeType}');
    }
    final points = json['pts'];
    if (points is! int) {
      throw FormatException('Field "result.standings.pts" must be an integer, got ${points.runtimeType}');
    }
    return ViewStanding(
      number: number,
      name: name,
      points: points,
      character: PlayerCharacter.fromJson(json['character']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ViewStanding &&
      other.number == number &&
      other.name == name &&
      other.points == points &&
      other.character == character;

  @override
  int get hashCode => Object.hash(number, name, points, character);
}

/// A joined phone's own result, sent with the [ViewEndMessage] that ends a
/// round (M14 design section 9): its outcome, its side's time or pieces (or
/// coins), its points in a night, and in a night its place in the standings.
final class ViewResult {
  const ViewResult({
    required this.outcome,
    this.timeS,
    this.count,
    this.countOf,
    this.points,
    this.round,
    this.of,
    this.place,
    this.winners = const [],
    this.standings = const [],
  });

  /// One of [ViewOutcome].
  final String outcome;

  /// How long the round took, in seconds, for a board played alone.
  final double? timeS;

  /// How many [countOf] the player had, when the card counts them.
  final int? count;

  /// One of [ViewCount], or null when the card counts nothing.
  final String? countOf;

  /// The player's points this round, in a night.
  final int? points;

  /// The night's round this result belongs to, and how many it has: both null
  /// outside a night.
  final int? round;
  final int? of;

  /// The player's place in the night's standings, 1 first; null outside a
  /// night.
  final int? place;

  /// The names of the round's winners: several for a team or a shared win,
  /// none when nobody won.
  final List<String> winners;

  /// The night's standings, first place first: empty outside a night.
  final List<ViewStanding> standings;

  /// The wire form. Missing parts are left out, so a short result stays short.
  Map<String, Object?> toJson() => {
    'outcome': outcome,
    'time': ?timeS,
    'count': ?count,
    'countOf': ?countOf,
    'points': ?points,
    'round': ?round,
    'of': ?of,
    'place': ?place,
    'winners': ?(winners.isEmpty ? null : winners),
    'standings': ?(standings.isEmpty ? null : [for (final s in standings) s.toJson()]),
  };

  /// Reads [json], which must be an object with a known [outcome]; every other
  /// field is optional.
  static ViewResult fromJson(Object? json) {
    if (json is! Map) throw FormatException('Field "result" must be an object, got ${json.runtimeType}');
    final outcome = json['outcome'];
    if (outcome is! String || !ViewOutcome.all.contains(outcome)) {
      throw FormatException('Field "result.outcome" must be one of ${ViewOutcome.all.join(', ')}, got "$outcome"');
    }
    final countOf = json['countOf'];
    if (countOf != null && (countOf is! String || !ViewCount.all.contains(countOf))) {
      throw FormatException('Field "result.countOf" must be one of ${ViewCount.all.join(', ')}, got "$countOf"');
    }
    final time = json['time'];
    if (time != null && time is! num) {
      throw FormatException('Field "result.time" must be a number, got ${time.runtimeType}');
    }
    final winners = json['winners'];
    final standings = json['standings'];
    return ViewResult(
      outcome: outcome,
      timeS: (time as num?)?.toDouble(),
      count: _optionalInt(json, 'count'),
      countOf: countOf as String?,
      points: _optionalInt(json, 'points'),
      round: _optionalInt(json, 'round'),
      of: _optionalInt(json, 'of'),
      place: _optionalInt(json, 'place'),
      winners: winners == null ? const [] : _stringList(winners, 'result.winners'),
      standings: standings == null ? const [] : _standings(standings),
    );
  }

  static int? _optionalInt(Map json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('Field "result.$key" must be an integer, got ${value.runtimeType}');
    return value;
  }

  static List<String> _stringList(Object value, String field) {
    if (value is! List || value.any((e) => e is! String)) {
      throw FormatException('Field "$field" must be a list of strings');
    }
    return List.unmodifiable(value.cast<String>());
  }

  static List<ViewStanding> _standings(Object value) {
    if (value is! List) throw FormatException('Field "result.standings" must be a list');
    return List.unmodifiable(value.map(ViewStanding.fromJson));
  }
}
