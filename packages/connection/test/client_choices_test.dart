import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';

const _codec = MessageCodec();

/// A choice round the TV sends: a shop with one card, to be taken in five seconds.
const choiceRound = ChoicesMessage(
  round: 1,
  title: 'Shop',
  cards: [ChoiceCard(id: 'save', title: 'Save +2')],
  endsInMs: 5000,
  defaultId: 'save',
);

/// The round's end: the default card applied, nothing picked.
const choiceEnd = ChoicesEndMessage(round: 1, result: 'save', count: 1, byDefault: true);

/// A player the host says is here, sent as the sync message: a phone takes a players list whenever it is paired.
const dadRow = (
  id: 'phone-2',
  number: 2,
  name: 'Dad',
  character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow),
);

/// A scripted host that answers the hello with [capabilities] and pairs the phone at once. It writes the channel it
/// paired on into [channels], sends [beforePairing] just before the pair result, and sends every message the phone
/// sends after the hello into [fromPhone].
Future<FakeHost> _pairingHost(
  TestTransport transport, {
  required List<String> capabilities,
  required List<MessageChannel> channels,
  required StreamController<Message> fromPhone,
  Message? beforePairing,
}) async {
  final host = await FakeHost.start(transport);
  host.onChannel = (channel) => channel.incoming.listen((data) {
    final message = _codec.decode(data);
    if (message == null) return;
    switch (message) {
      case HelloMessage():
        channel.send(
          _codec.encode(
            WelcomeMessage(hostId: 'tv-1', hostName: 'Test TV', appVersion: 'test', capabilities: capabilities),
          ),
        );
      case PairRequestMessage():
        channels.add(channel);
        if (beforePairing != null) channel.send(_codec.encode(beforePairing));
        channel.send(_codec.encode(const PairResultMessage.accepted(token: 'token')));
      case PingMessage():
        channel.send(_codec.encode(PongMessage.answering(message)));
      default:
        fromPhone.add(message);
    }
  });
  return host;
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a paired phone that listed choices gets the round and its end', () async {
        final channels = <MessageChannel>[];
        final fromPhone = StreamController<Message>.broadcast();
        addTearDown(fromPhone.close);
        final host = await _pairingHost(
          t,
          capabilities: const [Capability.choices],
          channels: channels,
          fromPhone: fromPhone,
        );
        final client = newClient(t, connector: host, capabilities: const [Capability.choices]);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        final round = client.choices.first;
        final end = client.choicesEnds.first;
        channels.single.send(_codec.encode(choiceRound));
        channels.single.send(_codec.encode(choiceEnd));

        expect(await round, choiceRound);
        expect(await end, choiceEnd);
      });

      test('a phone that did not list choices gets no round or end, though the host sends them', () async {
        final channels = <MessageChannel>[];
        final fromPhone = StreamController<Message>.broadcast();
        addTearDown(fromPhone.close);
        final host = await _pairingHost(
          t,
          capabilities: const [Capability.choices],
          channels: channels,
          fromPhone: fromPhone,
        );
        final client = newClient(t, connector: host);
        final rounds = <ChoicesMessage>[];
        final ends = <ChoicesEndMessage>[];
        final subs = [client.choices.listen(rounds.add), client.choicesEnds.listen(ends.add)];
        addTearDown(() => Future.wait(subs.map((s) => s.cancel())));

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        channels.single.send(_codec.encode(choiceRound));
        channels.single.send(_codec.encode(choiceEnd));
        // A later message the phone does take, so the test knows the earlier ones have been handled.
        channels.single.send(_codec.encode(const PlayersMessage(players: [dadRow])));
        await clientUntil(client, (s) => s.players.isNotEmpty);

        expect(rounds, isEmpty, reason: 'the phone did not list choices');
        expect(ends, isEmpty, reason: 'the phone did not list choices');
      });

      test('a round sent before pairing is dropped, as the night end is', () async {
        final channels = <MessageChannel>[];
        final fromPhone = StreamController<Message>.broadcast();
        addTearDown(fromPhone.close);
        final host = await _pairingHost(
          t,
          capabilities: const [Capability.choices],
          channels: channels,
          fromPhone: fromPhone,
          beforePairing: choiceRound,
        );
        final client = newClient(t, connector: host, capabilities: const [Capability.choices]);
        final rounds = <ChoicesMessage>[];
        final sub = client.choices.listen(rounds.add);
        addTearDown(sub.cancel);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        channels.single.send(_codec.encode(const PlayersMessage(players: [dadRow])));
        await clientUntil(client, (s) => s.players.isNotEmpty);

        expect(rounds, isEmpty, reason: 'the round came before the phone was paired');
      });

      test('a pick reaches the host when the host listed choices', () async {
        final channels = <MessageChannel>[];
        final fromPhone = StreamController<Message>.broadcast();
        addTearDown(fromPhone.close);
        final host = await _pairingHost(
          t,
          capabilities: const [Capability.choices],
          channels: channels,
          fromPhone: fromPhone,
        );
        final client = newClient(t, connector: host, capabilities: const [Capability.choices]);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        final sent = fromPhone.stream.firstWhere((m) => m is ChoicePickMessage);
        client.sendChoicePick(const ChoicePickMessage(round: 1, pick: 'save', locked: true));

        expect(await sent, const ChoicePickMessage(round: 1, pick: 'save', locked: true));
      });

      test('a pick is not sent when the host did not list choices', () async {
        final channels = <MessageChannel>[];
        final fromPhone = StreamController<Message>.broadcast();
        addTearDown(fromPhone.close);
        final host = await _pairingHost(
          t,
          capabilities: const [Capability.identity],
          channels: channels,
          fromPhone: fromPhone,
        );
        final client = newClient(t, connector: host, capabilities: const [Capability.choices]);
        final picks = <Message>[];
        final sub = fromPhone.stream.where((m) => m is ChoicePickMessage).listen(picks.add);
        addTearDown(sub.cancel);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        client.sendChoicePick(const ChoicePickMessage(round: 1, pick: 'save', locked: true));
        // The stats share goes out on the same channel after the pick, so once the host has it the pick would be there.
        final afterPick = fromPhone.stream.firstWhere((m) => m is StatsShareMessage);
        client.setStatsShare(true);
        await afterPick;

        expect(picks, isEmpty, reason: 'the host did not list choices, so nothing is sent');
      });
    });
  }
}
