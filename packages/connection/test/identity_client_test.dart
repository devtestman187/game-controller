import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';

/// The character a player picks in the phone's settings (M16 identity): the
/// teal crown, which no player number's default gives.
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// The character they pick next: the orange bow, again no player's default.
const orangeBow = PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow);

/// A player the host says is here (M16 identity): Mia in the teal crown.
const mia = (id: 'phone-1', number: 1, name: 'Mia', character: tealCrown);

/// Another: Dad, who joined without a nickname, in the orange bow.
const dad = (id: 'phone-2', number: 2, name: '', character: orangeBow);

/// What the phone told a [FakeHost] after its hello, in order, and a stream of
/// the same for a test that waits for one kind of message.
final class PhoneWords {
  /// Every message the phone sent after its hello, oldest first.
  final messages = <Message>[];

  final _arrived = StreamController<Message>.broadcast();

  /// Records [message]; the fake host calls it for each one.
  void add(Message message) {
    messages.add(message);
    _arrived.add(message);
  }

  /// The messages of type [T] the phone sent so far.
  Iterable<T> of<T extends Message>() => messages.whereType<T>();

  /// The next message of type [T] the phone sends.
  Future<T> next<T extends Message>() => _arrived.stream.where((m) => m is T).cast<T>().first;

  /// Releases the stream; a test registers it with `addTearDown`.
  Future<void> close() => _arrived.close();
}

/// A scripted host that pairs the phone at once, recording what the phone says
/// after its hello in [words]. [capabilities] is what its welcome lists.
Future<FakeHost> pairedHost(
  TestTransport transport, {
  required PhoneWords words,
  List<String> capabilities = const [],
}) async {
  const codec = MessageCodec();
  final host = await FakeHost.start(transport);
  host.onChannel = (channel) => channel.incoming.listen((data) {
    final message = codec.decode(data);
    if (message == null) return;
    switch (message) {
      case HelloMessage():
        channel.send(
          codec.encode(
            WelcomeMessage(hostId: 'tv-1', hostName: 'Test TV', appVersion: 'test', capabilities: capabilities),
          ),
        );
      case PairRequestMessage():
        channel.send(codec.encode(const PairResultMessage.accepted(token: 'token')));
      case PingMessage():
        channel.send(codec.encode(PongMessage.answering(message)));
      default:
        words.add(message);
    }
  });
  return host;
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('the hello lists the identity capability, whatever the app listed', () async {
        final host = await FakeHost.start(t);
        const codec = MessageCodec();
        HelloMessage? hello;
        host.onChannel = (channel) => channel.incoming.listen((data) {
          final message = codec.decode(data);
          switch (message) {
            case HelloMessage():
              hello = message;
              channel.send(codec.encode(const WelcomeMessage(hostId: 'tv-1', hostName: 'Test TV', appVersion: '9')));
            case PairRequestMessage():
              channel.send(codec.encode(const PairResultMessage.accepted(token: 'token')));
            case PingMessage():
              channel.send(codec.encode(PongMessage.answering(message)));
            default:
          }
        });
        final client = newClient(t, connector: host, capabilities: const [Capability.view]);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);

        expect(hello?.capabilities, [
          Capability.view,
          Capability.identity,
          Capability.night,
        ], reason: 'the app listed view; the client library adds the identity and night it implements');
      });

      test('a character picked while joined goes to a host that lists identity as set_character', () async {
        final words = PhoneWords();
        addTearDown(words.close);
        final host = await pairedHost(t, words: words, capabilities: const [Capability.identity]);
        final client = newClient(t, connector: host);
        client.identity = client.identity.copyWith(character: tealCrown);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        expect(words.of<SetCharacterMessage>(), isEmpty, reason: 'the hello already asked for it');

        client.identity = client.identity.copyWith(character: orangeBow);
        final sent = await words.next<SetCharacterMessage>().timeout(const Duration(seconds: 5));

        expect(sent.character, orangeBow);
        expect(client.snapshot.askedCharacter, orangeBow, reason: 'the ask is recorded, so the answer is read right');
        // Three heartbeats later it is still one ask: the recorded ask covers it.
        await Future<void>.delayed(hb * 3);
        expect(words.of<SetCharacterMessage>(), hasLength(1));
      });

      test('a host one build older is sent no set_character, and the link stays up', () async {
        final words = PhoneWords();
        addTearDown(words.close);
        final host = await pairedHost(t, words: words);
        final client = newClient(t, connector: host);
        client.identity = client.identity.copyWith(character: tealCrown);

        client.connect(host.address, code: '0000');
        await clientStatus(client, ClientStatus.connected);
        client.identity = client.identity.copyWith(character: orangeBow);

        await Future<void>.delayed(hb * 3);
        expect(words.of<SetCharacterMessage>(), isEmpty, reason: 'its welcome listed no identity');
        expect(client.snapshot.status, ClientStatus.connected);
        expect(client.snapshot.character, isNull, reason: 'it sends no character either');
      });

      test('the players message fills the snapshot while paired, and the newest list replaces the old', () async {
        final host = await startHost(t);
        final client = newClient(t);
        expect(client.snapshot.players, isEmpty, reason: 'nothing said yet');

        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        expect(host.send('phone-1', const PlayersMessage(players: [mia, dad])), isTrue);
        await clientUntil(client, (s) => s.players.length == 2);
        expect(client.snapshot.players, [mia, dad]);

        // Dad leaves: the host sends the list again, without him.
        expect(host.send('phone-1', const PlayersMessage(players: [mia])), isTrue);
        await clientUntil(client, (s) => s.players.length == 1);
        expect(client.snapshot.players, [mia]);
      });
    });
  }

  group('the players a link was told about (M16 identity)', () {
    test('a reconnecting snapshot keeps none of them', () {
      const here = ClientSnapshot(status: ClientStatus.connected, players: [mia, dad]);

      expect(here.reconnecting(detail: 'gone', attempt: 1).players, isEmpty);
    });

    test('a failed snapshot keeps none of them', () {
      const here = ClientSnapshot(status: ClientStatus.connected, players: [mia, dad]);

      expect(here.failed(ClientProblem.connectionLost, 'gone').players, isEmpty);
    });
  });
}
