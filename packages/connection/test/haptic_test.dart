import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('haptic events from the host reach a paired phone, in order', () async {
        final host = await startHost(t);
        final client = newClient(t);
        final received = <HapticEventMessage>[];
        client.hapticEvents.listen(received.add);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);

        final sent = [
          for (final e in HapticEvent.values) HapticEventMessage(event: e, intensity: 0.5, durationMs: 200),
        ];
        for (final m in sent) {
          expect(host.send('phone-1', m), isTrue);
        }
        await client.hapticEvents.take(sent.length - received.length).drain<void>().timeout(const Duration(seconds: 5));
        expect(received, sent);
        expect(client.hapticsReceived, sent.length);
      });

      test('sendToAll reaches every paired phone and skips unpaired ones', () async {
        final host = await startHost(t);
        final a = newClient(t, id: 'a');
        final b = newClient(t, id: 'b');
        final unpaired = newClient(t, id: 'c');
        a.connect(addressOf(host, t), code: host.pairingCode);
        b.connect(addressOf(host, t), code: host.pairingCode);
        unpaired.connect(addressOf(host, t));
        await clientStatus(a, ClientStatus.connected);
        await clientStatus(b, ClientStatus.connected);
        await clientStatus(unpaired, ClientStatus.waitingForCode);

        final gotA = a.hapticEvents.first;
        final gotB = b.hapticEvents.first;
        var unpairedGot = 0;
        unpaired.hapticEvents.listen((_) => unpairedGot++);
        expect(host.sendToAll(HapticEventMessage(event: HapticEvent.success)), 2);
        expect((await gotA.timeout(const Duration(seconds: 5))).event, HapticEvent.success);
        expect((await gotB.timeout(const Duration(seconds: 5))).event, HapticEvent.success);
        // A message the unpaired phone gets after the haptics: had one been
        // sent to it, it would have arrived first.
        unpaired.submitCode(host.pairingCode);
        await clientUntil(unpaired, (s) => s.isConnected);
        expect(unpairedGot, 0);
      });

      test('a phone that sends a haptic event to the host is closed as a protocol error', () async {
        final host = await startHost(t);
        const codec = MessageCodec();
        final channel = await rawPeer(host, t);
        final closed = Completer<int?>();
        channel.incoming.listen((_) {}, onDone: () => closed.complete(channel.closeCode));
        channel.send(
          codec.encode(const HelloMessage(controllerId: 'raw', name: 'Raw', platform: 'test', appVersion: 't')),
        );
        channel.send(codec.encode(HapticEventMessage(event: HapticEvent.hit)));
        expect(await closed.future.timeout(const Duration(seconds: 5)), CloseCodes.protocolError);
      });

      test('an unknown event name from a newer TV keeps the connection open', () async {
        final host = await FakeHost.start(t);
        const codec = MessageCodec();
        host.onChannel = (channel) => channel.incoming.listen((data) {
          final m = codec.decode(data);
          if (m is HelloMessage) {
            channel.send(codec.encode(const WelcomeMessage(hostId: 'new-tv', hostName: 'New TV', appVersion: '9')));
          } else if (m is PairRequestMessage) {
            channel.send(codec.encode(const PairResultMessage.accepted(token: 't')));
            channel.send('{"v":$protocolVersion,"t":"haptic","event":"explosion","intensity":1,"ms":100}');
            channel.send(codec.encode(HapticEventMessage(event: HapticEvent.hit)));
          } else if (m is PingMessage) {
            channel.send(codec.encode(PongMessage.answering(m)));
          }
        });
        final client = newClient(t, connector: host);
        final first = client.hapticEvents.first;
        client.connect(host.address, code: '0000');
        expect((await first.timeout(const Duration(seconds: 5))).event, HapticEvent.hit);
        expect(client.snapshot.status, ClientStatus.connected);
      });
    });
  }
}
