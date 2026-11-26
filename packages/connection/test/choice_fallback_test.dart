import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

const _cards = [
  ChoiceCard(id: 'save', title: 'Save +2'),
  ChoiceCard(id: 'build', title: 'Build', cost: 3, maxCount: 3),
  ChoiceCard(id: 'roadworks', title: 'Roadworks'),
];

/// A round that lasts long enough for a test to close it by hand.
const _longRound = Duration(seconds: 30);

/// The grace time of a player who is away; the tests never make one.
const _grace = Duration(seconds: 30);

/// A title longer than both the label and the status limits.
final _longTitle = List.filled(40, 'x').join();

final class _Setup {
  _Setup(this.host, this.round, this.choices, this.input);

  final MemoryGameHost host;
  final ChoiceRound round;
  final OldPhoneChoices choices;
  final StreamController<ControllerMessage> input;
}

/// Lets the old-phone listeners handle what was just added.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Sends one input state from [controllerId] with [buttons] held, then lets it be handled.
Future<void> _send(
  StreamController<ControllerMessage> input,
  String controllerId,
  int seq,
  Set<ControllerButton> buttons,
) async {
  input.add(ControllerMessage(controllerId, InputStateMessage(seq: seq, buttons: buttons)));
  await _settle();
}

Future<_Setup> _setup(TestTransport t, {List<ChoiceCard> cards = _cards}) async {
  final server = await startHost(t);
  await WirePhone.open(
    server,
    t,
    controllerId: 'phone-1',
    capabilities: const [Capability.choices],
    code: server.pairingCode,
  );
  await WirePhone.open(server, t, controllerId: 'phone-2', code: server.pairingCode);
  final host = MemoryGameHost();
  final round = ChoiceRound(
    server: server,
    round: 7,
    title: 'Shop',
    cardsFor: (_) => cards,
    players: const ['phone-1', 'phone-2'],
    duration: _longRound,
    grace: _grace,
    defaultId: 'save',
    currency: 'Bolts',
    nowMs: () => 0,
  );
  addTearDown(round.dispose);
  final input = StreamController<ControllerMessage>();
  addTearDown(input.close);
  final choices = OldPhoneChoices(round: round, host: host, input: input.stream);
  addTearDown(choices.dispose);
  round.start();
  choices.start();
  return _Setup(host, round, choices, input);
}

void main() {
  group('oldPhoneButtons', () {
    test('three cards take A, B and X in order, and Y clears the pick', () {
      final buttons = oldPhoneButtons(_cards);
      expect(buttons.map((b) => (b.button, b.label, b.cardId, b.counted)).toList(), [
        (ControllerButton.a, 'Save +2', 'save', false),
        (ControllerButton.b, 'Build', 'build', true),
        (ControllerButton.x, 'Roadworks', 'roadworks', false),
        (ControllerButton.y, 'Clear', null, false),
      ]);
    });

    test('two cards use A and B, leave X out, and keep Y for Clear', () {
      final buttons = oldPhoneButtons(_cards.take(2).toList());
      expect(buttons.map((b) => (b.button, b.label, b.cardId)).toList(), [
        (ControllerButton.a, 'Save +2', 'save'),
        (ControllerButton.b, 'Build', 'build'),
        (ControllerButton.y, 'Clear', null),
      ]);
    });

    test('four cards give the fourth card Y, with no Clear', () {
      final buttons = oldPhoneButtons([..._cards, const ChoiceCard(id: 'scout', title: 'Scout')]);
      expect(buttons.map((b) => (b.button, b.label, b.cardId)).toList(), [
        (ControllerButton.a, 'Save +2', 'save'),
        (ControllerButton.b, 'Build', 'build'),
        (ControllerButton.x, 'Roadworks', 'roadworks'),
        (ControllerButton.y, 'Scout', 'scout'),
      ]);
    });

    test('a 40-character title is cut to 12 characters on the label', () {
      final buttons = oldPhoneButtons([ChoiceCard(id: 'long', title: _longTitle)]);
      expect(buttons.first.label, _longTitle.substring(0, 12));
      expect(buttons.first.label.length, lessThanOrEqualTo(GameLayoutMessage.maxLabelLength));
    });
  });

  group('oldPhoneStatus', () {
    test('a counted card shows its count, total cost and currency', () {
      final status = oldPhoneStatus(card: _cards[1], count: 3, currency: 'Bolts');
      expect(status.text, 'Build 3 = 9 Bolts');
    });

    test('a plain card shows its title, and nothing chosen shows the default', () {
      expect(oldPhoneStatus(card: _cards[0]).text, 'Save +2');
      expect(oldPhoneStatus(defaultTitle: 'Save +2').text, 'Default: Save +2');
      expect(oldPhoneStatus().isHidden, isTrue);
    });

    test('a 40-character title stays within 24 characters', () {
      final long = ChoiceCard(id: 'long', title: _longTitle, cost: 3, maxCount: 3);
      expect(oldPhoneStatus(card: long, count: 3, currency: 'Bolts').text!.length, lessThanOrEqualTo(24));
      expect(oldPhoneStatus(defaultTitle: _longTitle).text!.length, lessThanOrEqualTo(24));
    });
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('start sets the labels and the status of an old phone only', () async {
        final s = await _setup(t);
        final layout = s.host.layouts['phone-2'];
        expect(layout?.labels, {
          ControllerButton.a: 'Save +2',
          ControllerButton.b: 'Build',
          ControllerButton.x: 'Roadworks',
          ControllerButton.y: 'Clear',
        });
        expect(layout?.hidden, isEmpty);
        expect(s.host.statuses['phone-2']?.text, 'Default: Save +2');
        expect(s.host.layouts.containsKey('phone-1'), isFalse);
        expect(s.host.statuses.containsKey('phone-1'), isFalse);
      });

      test('two cards hide the X button', () async {
        final s = await _setup(t, cards: _cards.take(2).toList());
        expect(s.host.layouts['phone-2']?.hidden, {ControllerButton.x});
      });

      test('three taps on a counted card give count 3, and a fourth stays at 3', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-2', 1, {ControllerButton.b});
        await _send(s.input, 'phone-2', 2, {});
        await _send(s.input, 'phone-2', 3, {ControllerButton.b});
        await _send(s.input, 'phone-2', 4, {});
        await _send(s.input, 'phone-2', 5, {ControllerButton.b});
        expect(s.host.statuses['phone-2']?.text, 'Build 3 = 9 Bolts');
        await _send(s.input, 'phone-2', 6, {});
        await _send(s.input, 'phone-2', 7, {ControllerButton.b});
        expect(s.host.statuses['phone-2']?.text, 'Build 3 = 9 Bolts');
        expect(s.round.close()['phone-2']?.count, 3);
      });

      test('a held button sends no extra count: hold, release, hold is 2', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-2', 1, {ControllerButton.b});
        await _send(s.input, 'phone-2', 2, {ControllerButton.b});
        expect(s.host.statuses['phone-2']?.text, 'Build 1 = 3 Bolts');
        await _send(s.input, 'phone-2', 3, {});
        await _send(s.input, 'phone-2', 4, {ControllerButton.b});
        expect(s.host.statuses['phone-2']?.text, 'Build 2 = 6 Bolts');
        expect(s.round.close()['phone-2']?.count, 2);
      });

      test('B after A switches the pick to the B card', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-2', 1, {ControllerButton.a});
        await _send(s.input, 'phone-2', 2, {});
        await _send(s.input, 'phone-2', 3, {ControllerButton.b});
        final outcome = s.round.close()['phone-2'];
        expect(outcome?.cardId, 'build');
        expect(outcome?.count, 1);
        expect(outcome?.byDefault, isFalse);
      });

      test('Y clears the pick, so the default applies', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-2', 1, {ControllerButton.b});
        await _send(s.input, 'phone-2', 2, {});
        await _send(s.input, 'phone-2', 3, {ControllerButton.y});
        expect(s.host.statuses['phone-2']?.text, 'Default: Save +2');
        final outcome = s.round.close()['phone-2'];
        expect(outcome?.cardId, 'save');
        expect(outcome?.byDefault, isTrue);
      });

      test('the outcome at close is the stored pick', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-2', 1, {ControllerButton.a});
        final outcome = s.round.close()['phone-2'];
        expect(outcome?.cardId, 'save');
        expect(outcome?.count, 1);
        expect(outcome?.byDefault, isFalse);
      });

      test('the layout and the status go back to standard and hidden at close', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-2', 1, {ControllerButton.a});
        s.round.close();
        await _settle();
        expect(s.host.layouts['phone-2']?.isStandard, isTrue);
        expect(s.host.statuses['phone-2']?.isHidden, isTrue);
      });

      test('a phone with the capability is left alone', () async {
        final s = await _setup(t);
        await _send(s.input, 'phone-1', 1, {ControllerButton.a});
        final outcomes = s.round.close();
        await _settle();
        expect(outcomes['phone-1']?.byDefault, isTrue);
        expect(s.host.layouts.containsKey('phone-1'), isFalse);
        expect(s.host.statuses.containsKey('phone-1'), isFalse);
      });
    });
  }
}
