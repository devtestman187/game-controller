import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';

/// The night's end the host sends: Mia won the one award and ends first.
const nightEnd = NightEndMessage(
  awards: [
    NightAwardRow(id: 'Fast', name: 'Fastest', points: 2, winners: ['phone-1']),
  ],
  standings: [
    ViewStanding(
      id: 'phone-1',
      number: 1,
      name: 'Mia',
      points: 2,
      character: PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
    ),
  ],
);

/// A player the host says is here, sent to show that a message after the night's end still arrives.
const dadRow = (
  id: 'phone-2',
  number: 2,
  name: 'Dad',
  character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow),
);

/// A scripted host that answers the hello with [capabilities] and pairs the phone at once. It writes the hello
/// into [hellos], the channel it paired on into [channels], and sends [beforePairing] just before the pair result.
Future<FakeHost> _pairingHost(
  TestTransport transport, {
  required List<String> capabilities,
  required List<HelloMessage> hellos,
  required List<MessageChannel> channels,
  Message? beforePairing,
}) async {
  const codec = MessageCodec();
  final host = await FakeHost.start(transport);
  host.onChannel = (channel) => channel.incoming.listen((data) {
    final message = codec.decode(data);
    if (message == null) return;
    switch (message) {
      case HelloMessage():
        hellos.add(message);
        channel.send(
          codec.encode(
            WelcomeMessage(hostId: 'tv-1', hostName: 'Test TV', appVersion: 'test', capabilities: capabilities),
          ),
        );
      case PairRequestMessage():
        channels.add(channel);
        if (beforePairing != null) channel.send(codec.encode(beforePairing));
        channel.send(codec.encode(const PairResultMessage.accepted(token: 'token')));
      case PingMessage():
        channel.send(codec.encode(PongMessage.answering(message)));
      default:
    }
  });
  return host;
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('the hello lists night beside identity, whatever the app listed', () async {
        final hellos = <HelloMessage>[];
        final host = await _pairingHost(t, capabilities: const [], hellos: hellos, channels: []);
        final client = newClient(t, connector: host);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);

        expect(hellos.single.capabilities, [
          Capability.identity,
          Capability.night,
        ], reason: 'the client library adds the identity and night it implements');
      });

      test('a paired client gets the night_end on nightEnds', () async {
        const codec = MessageCodec();
        final channels = <MessageChannel>[];
        final host = await _pairingHost(t, capabilities: const [Capability.night], hellos: [], channels: channels);
        final client = newClient(t, connector: host);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        final received = client.nightEnds.first;
        channels.single.send(codec.encode(nightEnd));

        expect(await received, nightEnd);
      });

      test('a night_end before pairing is dropped, as players is', () async {
        const codec = MessageCodec();
        final channels = <MessageChannel>[];
        final host = await _pairingHost(
          t,
          capabilities: const [Capability.night],
          hellos: [],
          channels: channels,
          beforePairing: nightEnd,
        );
        final client = newClient(t, connector: host);
        final events = <NightEndMessage>[];
        final sub = client.nightEnds.listen(events.add);
        addTearDown(sub.cancel);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        // A later message the phone does take, so the test knows the earlier one has been handled.
        channels.single.send(codec.encode(const PlayersMessage(players: [dadRow])));
        await clientUntil(client, (s) => s.players.isNotEmpty);

        expect(events, isEmpty, reason: 'the night_end came before the phone was paired');
      });

      test('an older host that never lists or sends night_end leaves the client working as before', () async {
        const codec = MessageCodec();
        final channels = <MessageChannel>[];
        final host = await _pairingHost(t, capabilities: const [Capability.identity], hellos: [], channels: channels);
        final client = newClient(t, connector: host);
        final events = <NightEndMessage>[];
        final sub = client.nightEnds.listen(events.add);
        addTearDown(sub.cancel);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        channels.single.send(codec.encode(const PlayersMessage(players: [dadRow])));
        final snapshot = await clientUntil(client, (s) => s.players.isNotEmpty);

        expect(events, isEmpty, reason: 'an older host sends no night_end, so nothing is reported');
        expect(snapshot.players.single.name, 'Dad', reason: 'the players list still works');
        expect(snapshot.status, ClientStatus.connected);
      });
    });
  }
}
