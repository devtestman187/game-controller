import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// What a phone one build newer lists: it shows choice rounds.
const choicesCap = [Capability.choices];

/// A phone one build older: it shows the game and knows no choices.
const viewOnly = [Capability.view];

/// A round the host offers the player: two cards, one of them taken up to three times.
const round = ChoicesMessage(
  round: 1,
  title: 'Shop',
  cards: [
    ChoiceCard(id: 'save', title: 'Save +2', cost: 2),
    ChoiceCard(id: 'build', title: 'Build', maxCount: 3),
  ],
  endsInMs: 5000,
  defaultId: 'save',
);

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a choices message reaches a phone that lists choices and never reaches one that does not', () async {
        final server = await startHost(t, capabilities: choicesCap);
        final newer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: choicesCap,
          code: server.pairingCode,
        );
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-9',
          name: 'Ava',
          capabilities: viewOnly,
          code: server.pairingCode,
        );
        await newer.drain();
        await older.drain();

        expect(server.sendToAll(round), 1, reason: 'only the phone that lists choices is sent the round');
        await newer.drain();
        await older.drain();

        expect(newer.fromHost.whereType<ChoicesMessage>().single, round);
        expect(older.fromHost.whereType<ChoicesMessage>(), isEmpty);
      });

      test('a phone with only the view stays paired, and its input still reaches the host', () async {
        final server = await startHost(t, capabilities: choicesCap);
        final received = <Message>[];
        final subscription = server.messages.listen((m) => received.add(m.message));
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-9',
          name: 'Ava',
          capabilities: viewOnly,
          code: server.pairingCode,
        );

        older.send(InputStateMessage(seq: 1, buttons: {ControllerButton.a}));
        await older.drain();
        await subscription.cancel();

        expect(received.whereType<InputStateMessage>().single.seq, 1);
        expect(server.send('phone-9', round), isFalse, reason: 'a phone that lists no choices is never sent one');
      });

      test('a pick from a phone that lists no choices is ignored and does not close it', () async {
        final server = await startHost(t, capabilities: choicesCap);
        final received = <Message>[];
        final subscription = server.messages.listen((m) => received.add(m.message));
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-9',
          name: 'Ava',
          capabilities: viewOnly,
          code: server.pairingCode,
        );

        older.send(const ChoicePickMessage(round: 1, pick: 'save'));
        // A pong only comes back if the phone is still paired, so the drain shows it was not closed.
        await older.drain();
        await subscription.cancel();

        expect(received.whereType<ChoicePickMessage>(), isEmpty);
      });

      test('a pick from a phone that lists choices reaches the host', () async {
        final server = await startHost(t, capabilities: choicesCap);
        final received = <Message>[];
        final subscription = server.messages.listen((m) => received.add(m.message));
        final newer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: choicesCap,
          code: server.pairingCode,
        );

        const pick = ChoicePickMessage(round: 1, pick: 'build', count: 2, locked: true);
        newer.send(pick);
        await newer.drain();
        await subscription.cancel();

        expect(received.whereType<ChoicePickMessage>().single, pick);
      });
    });
  }
}
