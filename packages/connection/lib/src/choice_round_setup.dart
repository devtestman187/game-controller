import 'package:protocol/protocol.dart';

/// What one [ChoiceRound] shows the phones and settles with (M17 phone1a): the
/// question, the cards each player may pick from, and the default and currency.
final class ChoiceRoundSetup {
  /// Groups what a round shows and settles with; [defaultId] and [currency] may be null.
  const ChoiceRoundSetup({
    required this.round,
    required this.title,
    required this.cardsFor,
    this.defaultId,
    this.currency,
  });

  /// The round's number, which a phone's pick must name.
  final int round;

  /// The question the phones show.
  final String title;

  /// The cards one player may pick from, asked each time so a list may change.
  final List<ChoiceCard> Function(String playerId) cardsFor;

  /// The card that applies when nothing is chosen, or null when nothing does.
  final String? defaultId;

  /// The unit the costs are in, or null when there are none.
  final String? currency;
}

/// The timing of one [ChoiceRound] (M17 phone1a): how long it lasts, how long a
/// player may stay away, and the clock the time left is counted on.
final class ChoiceTiming {
  /// Groups the round's timing; [nowMs] is the clock, injected so tests can fake it.
  const ChoiceTiming({required this.duration, required this.grace, required this.nowMs});

  /// How long the round lasts, from start.
  final Duration duration;

  /// How long a player may stay away before getting the default.
  final Duration grace;

  /// The clock the time left in each message comes from, in ms.
  final int Function() nowMs;
}
