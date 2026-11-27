import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyCard, ToyLookScope;
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// A card's text as the player reads it: "Build 2" for a counted card holding 2, else its title.
String choiceCardLabel(ChoiceCard card, int count) => card.maxCount > 1 ? '${card.title} $count' : card.title;

/// What the round gave the player, once the host ended it (M17 phone1b): the card they got, the card chosen
/// for them, or "No choice".
class ChoicesResult extends StatelessWidget {
  const ChoicesResult({super.key, required this.state, required this.end});

  final ChoicesState state;
  final ChoicesEndMessage end;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final result = end.result;
    final card = result == null ? null : state.message.cards.where((c) => c.id == result).firstOrNull;
    // A result that names no card of this round is shown as no choice, never as a raw id.
    final label = card == null ? null : choiceCardLabel(card, end.count);
    final text = label == null
        ? PhoneText.choicesNoChoice
        : end.byDefault
        ? PhoneText.choicesChosenForYou(label)
        : PhoneText.choicesYouGot(label);
    return ToyCard(
      key: const Key('choicesResult'),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: look.type.title.copyWith(color: look.colors.ink),
      ),
    );
  }
}
