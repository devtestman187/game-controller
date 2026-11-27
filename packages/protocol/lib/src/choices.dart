part of 'messages.dart';

/// One card a player can pick in a choice round (M17 phone1a): its name, its
/// cost, and how many of it a player may take. A card the host cannot offer
/// now is sent with [enabled] false, so the phone shows it greyed out.
final class ChoiceCard {
  const ChoiceCard({
    required this.id,
    required this.title,
    this.detail,
    this.cost,
    this.maxCount = 1,
    this.enabled = true,
  });

  /// The most a card's [maxCount] may be. Above this, a card is not a valid wire card.
  static const int maxCountLimit = 9;

  /// The most code points of a title the host sends; a longer title is cut to this many (the owner's limit
  /// for the phone's card, M17 phone1a).
  static const int maxTitleLength = 24;

  /// The card's own ID, unique within its round, which a pick names. Never empty.
  final String id;

  /// The card's name as the phone shows it. The host cuts it to [maxTitleLength] code points.
  final String title;

  /// A line under the title, or null when there is none.
  final String? detail;

  /// What one unit costs, in the round's currency, or null when the card costs nothing to show.
  final int? cost;

  /// How many of the card a player may take, from 1 to [maxCountLimit]. Above 1
  /// the phone counts the picks, as in "Build 3".
  final int maxCount;

  /// Whether a player may pick the card. False shows it greyed out, and it cannot be picked.
  final bool enabled;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'detail': ?detail,
    'cost': ?cost,
    'maxCount': maxCount,
    'enabled': enabled,
  };

  static ChoiceCard fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('Field "cards" entry must be an object, got ${json.runtimeType}');
    }
    final p = json.cast<String, Object?>();
    final id = requireString(p, 'id');
    if (id.isEmpty) throw const FormatException('Field "cards.id" must not be empty');
    final maxCount = optionalInt(p, 'maxCount') ?? 1;
    if (maxCount < 1 || maxCount > maxCountLimit) {
      throw FormatException('Field "cards.maxCount" must be 1 to $maxCountLimit, got $maxCount');
    }
    return ChoiceCard(
      id: id,
      title: requireString(p, 'title'),
      detail: optionalString(p, 'detail'),
      cost: optionalInt(p, 'cost'),
      maxCount: maxCount,
      enabled: p['enabled'] == null ? true : requireBool(p, 'enabled'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChoiceCard &&
      other.id == id &&
      other.title == title &&
      other.detail == detail &&
      other.cost == cost &&
      other.maxCount == maxCount &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, title, detail, cost, maxCount, enabled);
}

/// Host → controller (M17 phone1a, needs [Capability.choices]): a choice round
/// for this player, with the time left to choose and what the host already has
/// for the player. A resend after a reconnect carries [picked] and [locked], so
/// the phone shows the earlier choice.
///
/// Only a phone that lists [Capability.choices] is sent it. The phone counts
/// [endsInMs] down on its own clock.
final class ChoicesMessage extends Message {
  const ChoicesMessage({
    required this.round,
    required this.title,
    required this.cards,
    required this.endsInMs,
    this.defaultId,
    this.currency,
    this.picked,
    this.pickedCount = 1,
    this.locked = false,
    this.paused = false,
  });

  static const String wireType = 'choices';

  /// The most cards one round may offer.
  static const int maxCards = 6;

  /// The round's number, so a pick can say which round it answers.
  final int round;

  /// The question the round asks, as the phone shows it.
  final String title;

  /// The cards to choose from, 1 to [maxCards] of them, with unique IDs.
  final List<ChoiceCard> cards;

  /// The time left to choose when the host sent the message, in milliseconds.
  final int endsInMs;

  /// The card that applies when nothing is chosen, or null when nothing does.
  final String? defaultId;

  /// The unit the costs are in, such as `Bolts`, or null when there are none.
  final String? currency;

  /// The card the player has picked so far, or null when nothing is picked.
  final String? picked;

  /// How many of [picked] the player has taken.
  final int pickedCount;

  /// Whether the host has locked [picked] in.
  final bool locked;

  /// Whether the host has paused the round: [endsInMs] is then the time left, and it stands still
  /// until a later message says paused is false. Written only when true, so an older phone never sees it.
  final bool paused;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'round': round,
    'title': title,
    'cards': [for (final c in cards) c.toJson()],
    'endsInMs': endsInMs,
    'defaultId': ?defaultId,
    'currency': ?currency,
    'picked': ?picked,
    'pickedCount': pickedCount,
    'locked': locked,
    if (paused) 'paused': true,
  };

  static ChoicesMessage fromPayload(Map<String, Object?> p) {
    final cards = _list(p, 'cards').map(ChoiceCard.fromJson).toList(growable: false);
    if (cards.isEmpty || cards.length > maxCards) {
      throw FormatException('Field "cards" must hold 1 to $maxCards cards, got ${cards.length}');
    }
    if (cards.map((c) => c.id).toSet().length != cards.length) {
      throw const FormatException('Field "cards" must not repeat an id');
    }
    return ChoicesMessage(
      round: requireInt(p, 'round'),
      title: requireString(p, 'title'),
      cards: cards,
      endsInMs: requireInt(p, 'endsInMs'),
      defaultId: optionalString(p, 'defaultId'),
      currency: optionalString(p, 'currency'),
      picked: optionalString(p, 'picked'),
      pickedCount: optionalInt(p, 'pickedCount') ?? 1,
      locked: p['locked'] == null ? false : requireBool(p, 'locked'),
      paused: p['paused'] == null ? false : requireBool(p, 'paused'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChoicesMessage &&
      other.round == round &&
      other.title == title &&
      _sameList(other.cards, cards) &&
      other.endsInMs == endsInMs &&
      other.defaultId == defaultId &&
      other.currency == currency &&
      other.picked == picked &&
      other.pickedCount == pickedCount &&
      other.locked == locked &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(
    round,
    title,
    Object.hashAll(cards),
    endsInMs,
    defaultId,
    currency,
    picked,
    pickedCount,
    locked,
    paused,
  );
}

/// Controller → host (M17 phone1a, needs [Capability.choices]): the player's
/// pick in the choice round [round]. A null [pick] clears it. A pick that is
/// not [locked] can still be changed until the round ends.
final class ChoicePickMessage extends Message {
  const ChoicePickMessage({required this.round, this.pick, this.count = 1, this.locked = false});

  static const String wireType = 'choice_pick';

  /// The round the pick answers.
  final int round;

  /// The card picked, or null to clear the pick.
  final String? pick;

  /// How many of [pick] the player takes.
  final int count;

  /// Whether the player has locked the pick in.
  final bool locked;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'round': round, 'pick': ?pick, 'count': count, 'locked': locked};

  static ChoicePickMessage fromPayload(Map<String, Object?> p) => ChoicePickMessage(
    round: requireInt(p, 'round'),
    pick: optionalString(p, 'pick'),
    count: optionalInt(p, 'count') ?? 1,
    locked: p['locked'] == null ? false : requireBool(p, 'locked'),
  );

  @override
  bool operator ==(Object other) =>
      other is ChoicePickMessage &&
      other.round == round &&
      other.pick == pick &&
      other.count == count &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(round, pick, count, locked);
}

/// Host → controller (M17 phone1a, needs [Capability.choices]): the round
/// [round] has ended. [result] is the card the host applied, or null when none
/// applies, and [byDefault] says the card came from the round's default.
final class ChoicesEndMessage extends Message {
  const ChoicesEndMessage({required this.round, this.result, required this.count, required this.byDefault});

  static const String wireType = 'choices_end';

  /// The round that ended.
  final int round;

  /// The card the host applied, or null when none applies.
  final String? result;

  /// How many of [result] the player got.
  final int count;

  /// Whether [result] came from the round's default rather than the player's pick.
  final bool byDefault;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {'round': round, 'result': ?result, 'count': count, 'byDefault': byDefault};

  static ChoicesEndMessage fromPayload(Map<String, Object?> p) => ChoicesEndMessage(
    round: requireInt(p, 'round'),
    result: optionalString(p, 'result'),
    count: requireInt(p, 'count'),
    byDefault: requireBool(p, 'byDefault'),
  );

  @override
  bool operator ==(Object other) =>
      other is ChoicesEndMessage &&
      other.round == round &&
      other.result == result &&
      other.count == count &&
      other.byDefault == byDefault;

  @override
  int get hashCode => Object.hash(round, result, count, byDefault);
}
