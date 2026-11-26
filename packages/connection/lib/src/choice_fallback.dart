import 'dart:async';

import 'package:protocol/protocol.dart';

import 'choice_round.dart';
import 'game_host.dart';
import 'host_types.dart';

/// The buttons the cards take, in card order (owner O3, Nov 26).
const _cardButtons = [ControllerButton.a, ControllerButton.b, ControllerButton.x];

/// Y clears the pick, or takes the fourth card when there is one.
const _yButton = ControllerButton.y;

/// One button of an old phone, as the round's cards map onto it.
final class OldPhoneButton {
  const OldPhoneButton({required this.button, required this.label, this.cardId, required this.counted});

  /// The phone button.
  final ControllerButton button;

  /// The short text under the button, cut to [GameLayoutMessage.maxLabelLength].
  final String label;

  /// The card the button picks, or null for Clear.
  final String? cardId;

  /// Whether each new press adds one to the count (the card's maxCount is above 1).
  final bool counted;
}

/// The one mapping from a round's cards to an old phone's buttons: the cards take A, B and X in
/// order; Y is "Clear", or the fourth card when there are four. Only the first four cards are
/// reachable from a phone without the choices capability.
List<OldPhoneButton> oldPhoneButtons(List<ChoiceCard> cards) {
  final buttons = [
    for (var i = 0; i < cards.length && i < _cardButtons.length; i++) _cardButton(_cardButtons[i], cards[i]),
  ];
  if (cards.length > _cardButtons.length) {
    buttons.add(_cardButton(_yButton, cards[_cardButtons.length]));
  } else {
    buttons.add(const OldPhoneButton(button: _yButton, label: 'Clear', counted: false));
  }
  return buttons;
}

/// The status text an old phone shows: the pick with its count and total cost (e.g. "Build 3 =
/// 9 Bolts"), or "Default: <title>" when nothing is chosen. Null [card] and [defaultTitle] hides
/// it. Cut to [StatusMessage.maxTextLength].
StatusMessage oldPhoneStatus({ChoiceCard? card, int count = 1, String? currency, String? defaultTitle}) {
  if (card == null) {
    if (defaultTitle == null) return StatusMessage.hidden();
    return StatusMessage(text: _cut('Default: $defaultTitle', StatusMessage.maxTextLength));
  }
  final cost = card.cost;
  final text = card.maxCount <= 1
      ? card.title
      : [
          '${card.title} $count',
          if (cost != null) '= ${cost * count}',
          if (cost != null && currency != null) currency,
        ].join(' ');
  return StatusMessage(text: _cut(text, StatusMessage.maxTextLength));
}

/// Plays the phones of a [ChoiceRound] that do not list [Capability.choices] (old phones) with
/// their buttons: each press of a button is a pick in the round, and the phone shows the labels
/// and the status. When the round closes, or on [dispose], each old phone goes back to its usual
/// buttons and no status.
final class OldPhoneChoices {
  OldPhoneChoices({required this.round, required this.host, required this.input});

  /// The round the old phones pick in.
  final ChoiceRound round;

  /// Where the labels and the status go.
  final GameHost host;

  /// The controllers' input, from the host.
  final Stream<ControllerMessage> input;

  final _phones = <String, _OldPhone>{};
  StreamSubscription<ControllerMessage>? _inputSub;
  StreamSubscription<void>? _roundSub;
  bool _started = false;
  bool _finished = false;

  /// Sets the labels and the status of each old phone in the round and starts counting its
  /// presses. A phone with the capability is left alone.
  void start() {
    if (_started || round.isClosed) return;
    _started = true;
    final controllers = round.server.snapshot.controllers;
    for (final id in round.players) {
      final controller = controllers.where((c) => c.controllerId == id).firstOrNull;
      if (controller == null || controller.supports(Capability.choices)) continue;
      final buttons = oldPhoneButtons(round.cardsFor(id));
      final phone = _OldPhone(buttons);
      _phones[id] = phone;
      host.setLayout(id, _layoutFor(buttons));
      _showStatus(id, phone);
    }
    _inputSub = input.listen(_onInput);
    _roundSub = round.changes.listen((_) {
      if (round.isClosed) unawaited(_finish());
    }, onDone: () => unawaited(_finish()));
  }

  /// Puts the old phones back to their usual buttons and no status, and stops counting. Safe to
  /// call more than once.
  Future<void> dispose() => _finish();

  void _onInput(ControllerMessage m) {
    final phone = _phones[m.controllerId];
    final message = m.message;
    if (phone == null || message is! InputStateMessage || round.isClosed) return;
    final pressed = message.buttons.difference(phone.held);
    phone.held = message.buttons;
    for (final button in pressed) {
      final slot = phone.buttons.where((b) => b.button == button).firstOrNull;
      if (slot != null) _press(m.controllerId, phone, slot);
    }
  }

  /// A press of [slot] is a pick: a counted card adds one to the count while it is the same card,
  /// up to its maxCount; any other card picks with count 1; Clear picks nothing.
  void _press(String playerId, _OldPhone phone, OldPhoneButton slot) {
    final cardId = slot.cardId;
    if (cardId == null) {
      phone.pickId = null;
      phone.count = 0;
      round.pick(playerId);
    } else {
      final card = round.cardsFor(playerId).where((c) => c.id == cardId).firstOrNull;
      if (card == null || !card.enabled) return;
      final again = slot.counted && phone.pickId == cardId;
      final count = again ? (phone.count < card.maxCount ? phone.count + 1 : card.maxCount) : 1;
      phone.pickId = cardId;
      phone.count = count;
      round.pick(playerId, pickId: cardId, count: count);
    }
    _showStatus(playerId, phone);
  }

  void _showStatus(String playerId, _OldPhone phone) {
    final cards = round.cardsFor(playerId);
    final card = cards.where((c) => c.id == phone.pickId).firstOrNull;
    final defaultCard = cards.where((c) => c.id == round.defaultId).firstOrNull;
    host.setStatus(
      playerId,
      oldPhoneStatus(card: card, count: phone.count, currency: round.currency, defaultTitle: defaultCard?.title),
    );
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    for (final id in _phones.keys) {
      host.setLayout(id, GameLayoutMessage.standard());
      host.setStatus(id, StatusMessage.hidden());
    }
    await _inputSub?.cancel();
    await _roundSub?.cancel();
  }
}

/// One old phone's state: its buttons, the buttons held down, and the pick the round holds for it.
final class _OldPhone {
  _OldPhone(this.buttons);

  final List<OldPhoneButton> buttons;
  Set<ControllerButton> held = const {};
  String? pickId;
  int count = 0;
}

OldPhoneButton _cardButton(ControllerButton button, ChoiceCard card) => OldPhoneButton(
  button: button,
  label: _cut(card.title, GameLayoutMessage.maxLabelLength),
  cardId: card.id,
  counted: card.maxCount > 1,
);

/// The labels of the buttons in use, and the unused A, B, X and Y hidden.
GameLayoutMessage _layoutFor(List<OldPhoneButton> buttons) {
  final used = {for (final b in buttons) b.button};
  return GameLayoutMessage(
    labels: {for (final b in buttons) b.button: b.label},
    hidden: {
      for (final b in [..._cardButtons, _yButton])
        if (!used.contains(b)) b,
    },
  );
}

String _cut(String text, int maxLength) => text.length <= maxLength ? text : text.substring(0, maxLength);
