import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('haptic events from the host reach a paired phone, in order', () async {
    final host = await startHost();
    final client = newClient();
    final received = <HapticEventMessage>[];
    client.hapticEvents.listen(received.add);
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    final sent = [for (final e in HapticEvent.values) HapticEventMessage(event: e, intensity: 0.5, durationMs: 200)];
    for (final m in sent) {
      expect(host.send('phone-1', m), isTrue);
    }
    await client.hapticEvents.take(sent.length - received.length).drain<void>().timeout(const Duration(seconds: 5));
    expect(received, sent);
    expect(client.hapticsReceived, sent.length);
  });

  test('sendToAll reaches every paired phone and skips unpaired ones', () async {
    final host = await startHost();
    final a = newClient(id: 'a');
    final b = newClient(id: 'b');
    final unpaired = newClient(id: 'c');
    a.connect(addressOf(host), code: host.pairingCode);
    b.connect(addressOf(host), code: host.pairingCode);
    unpaired.connect(addressOf(host));
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
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(unpairedGot, 0);
  });

  test('a phone that sends a haptic event to the host is closed as a protocol error', () async {
    final host = await startHost();
    const codec = MessageCodec();
    final ws = await WebSocket.connect('ws://127.0.0.1:${host.port}$webSocketPath');
    final closed = Completer<int?>();
    ws.listen((_) {}, onDone: () => closed.complete(ws.closeCode));
    ws.add(codec.encode(const HelloMessage(controllerId: 'raw', name: 'Raw', platform: 'test', appVersion: 't')));
    ws.add(codec.encode(HapticEventMessage(event: HapticEvent.hit)));
    expect(await closed.future.timeout(const Duration(seconds: 5)), CloseCodes.protocolError);
  });

  test('an unknown event name from a newer TV keeps the connection open', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    const codec = MessageCodec();
    server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      ws.listen((data) {
        final m = codec.decode(data as String);
        if (m is HelloMessage) {
          ws.add(codec.encode(const WelcomeMessage(hostId: 'new-tv', hostName: 'New TV', appVersion: '9')));
        } else if (m is PairRequestMessage) {
          ws.add(codec.encode(const PairResultMessage.accepted(token: 't')));
          ws.add('{"v":$protocolVersion,"t":"haptic","event":"explosion","intensity":1,"ms":100}');
          ws.add(codec.encode(HapticEventMessage(event: HapticEvent.hit)));
        } else if (m is PingMessage) {
          ws.add(codec.encode(PongMessage.answering(m)));
        }
      });
    });
    final client = newClient();
    final first = client.hapticEvents.first;
    client.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port),
      code: '0000',
    );
    expect((await first.timeout(const Duration(seconds: 5))).event, HapticEvent.hit);
    expect(client.snapshot.status, ClientStatus.connected);
  });
}
