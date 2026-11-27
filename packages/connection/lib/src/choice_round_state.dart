part of 'choice_round.dart';

/// What one player got from a [ChoiceRound] (M17 phone1a): the card, how many
/// of it, and whether it came from the round's default rather than a pick.
final class ChoiceOutcome {
  /// Settles one player's outcome; [cardId] is null when no card applies.
  const ChoiceOutcome({required this.cardId, required this.count, required this.byDefault});

  /// The card the player got, or null when none applies (a vote that abstains).
  final String? cardId;

  /// How many of [cardId] the player got; 0 when [cardId] is null.
  final int count;

  /// Whether [cardId] is the round's default: the player chose nothing, or was away.
  final bool byDefault;

  @override
  bool operator ==(Object other) =>
      other is ChoiceOutcome && other.cardId == cardId && other.count == count && other.byDefault == byDefault;

  @override
  int get hashCode => Object.hash(cardId, count, byDefault);

  @override
  String toString() => 'ChoiceOutcome($cardId x$count${byDefault ? ', default' : ''})';
}

/// The pick the round holds for one player.
final class _Pick {
  const _Pick({required this.cardId, required this.count, required this.locked, this.byDefault = false});

  final String cardId;
  final int count;
  final bool locked;

  /// Whether the host set it (a player away for the grace time), not the player.
  final bool byDefault;
}
