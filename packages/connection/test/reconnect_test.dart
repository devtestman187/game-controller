import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('reconnects after a drop without asking for the code', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    host.dropAllConnections();
    final dropped = await clientStatus(client, ClientStatus.reconnecting);
    expect(dropped.problem, ClientProblem.connectionLost);
    final back = await clientStatus(client, ClientStatus.connected);
    expect(back.attempt, 0);
    expect(back.problem, isNull);
    await hostUntil(host, (h) => stateOf(h, 'phone-1') == ControllerState.connected);
  });

  test('keeps retrying while the host is away, then reconnects', () async {
    final port = await freePort();
    final host = await startHost(port: port);
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    await host.stop();
    await clientUntil(client, (s) => s.status == ClientStatus.reconnecting && s.attempt >= 3);

    // The same host comes back on the same port with the same state.
    await host.start();
    expect(host.port, port);
    await clientStatus(client, ClientStatus.connected);
  });

  test('asks for the code again after the TV app restarts', () async {
    final first = await startHost();
    final port = first.port!;
    final client = newClient();
    client.connect(addressOf(first), code: first.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    await first.dispose();
    final restarted = await startHost(port: port); // Fresh state: no known controllers.
    final s = await clientUntil(client, (s) => s.problem == ClientProblem.pairingForgotten);
    expect(s.status, ClientStatus.waitingForCode);
    expect(client.tokens, isEmpty);

    client.submitCode(restarted.pairingCode);
    await clientStatus(client, ClientStatus.connected);
  });

  test('a saved token reconnects without a code after the phone app restarts', () async {
    final host = await startHost();
    final first = newClient();
    first.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(first, ClientStatus.connected);
    final saved = first.tokens;
    first.disconnect();
    await hostUntil(host, (h) => stateOf(h, 'phone-1') == ControllerState.disconnected);

    final relaunched = newClient(tokens: saved);
    relaunched.connect(addressOf(host));
    await clientStatus(relaunched, ClientStatus.connected);
  });

  test('reports new tokens through the callback', () async {
    final host = await startHost();
    final saved = <String, String?>{};
    final client = ControllerClient(
      identity: const ControllerIdentity(controllerId: 'p', name: 'P', platform: 'test', appVersion: 't'),
      onTokenChanged: (hostId, token) => saved[hostId] = token,
      heartbeatInterval: hb,
      heartbeatTimeout: hbTimeout,
    );
    addTearDown(client.dispose);
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
    expect(saved['host-1'], client.tokens['host-1']);
  });

  test('the host drops a controller that stops answering', () async {
    final host = await startHost();
    // A raw socket that pairs, then goes silent like a phone that lost Wi-Fi.
    final ws = await WebSocket.connect('ws://127.0.0.1:${host.port}$webSocketPath');
    const codec = MessageCodec();
    ws.add(codec.encode(const HelloMessage(controllerId: 'silent', name: 'Silent', platform: 'test', appVersion: 't')));
    ws.add(codec.encode(PairRequestMessage(code: host.pairingCode)));
    final closed = ws.drain<void>();

    await hostUntil(host, (h) => stateOf(h, 'silent') == ControllerState.connected);
    await hostUntil(host, (h) => stateOf(h, 'silent') == ControllerState.disconnected);
    await closed;
    expect(ws.closeCode, CloseCodes.heartbeatTimeout);
  });

  test('the phone notices a host that stops answering', () async {
    // A fake host that pairs, then goes silent like a TV that lost Wi-Fi.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final sockets = <WebSocket>[];
    server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      sockets.add(ws);
      const codec = MessageCodec();
      ws.listen((frame) {
        final m = codec.decode(frame as String);
        if (m is HelloMessage) {
          ws.add(codec.encode(const WelcomeMessage(hostId: 'h', hostName: 'Silent TV', appVersion: 't')));
        } else if (m is PairRequestMessage) {
          ws.add(codec.encode(const PairResultMessage.accepted(token: 'tok')));
        }
      });
    });
    addTearDown(() async {
      for (final s in sockets) {
        await s.close();
      }
    });

    final client = newClient();
    client.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port),
      code: '1234',
    );
    await clientStatus(client, ClientStatus.connected);
    final s = await clientStatus(client, ClientStatus.reconnecting);
    expect(s.detail, 'No heartbeat');
  });

  test('disconnect stops retrying', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
    await host.stop();
    await clientStatus(client, ClientStatus.reconnecting);

    client.disconnect();
    expect(client.snapshot.status, ClientStatus.idle);
    await host.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(client.snapshot.status, ClientStatus.idle);
    expect(host.snapshot.connected, isEmpty);
  });

  test('uses the new address when discovery finds the host elsewhere', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(
      HostAddress(addresses: ['127.0.0.1'], port: host.port!, hostId: 'host-1', name: 'TV'),
      code: host.pairingCode,
    );
    await clientStatus(client, ClientStatus.connected);

    client.updateAddress(HostAddress(addresses: ['127.0.0.2', '127.0.0.1'], port: host.port!, hostId: 'host-1'));
    expect(client.snapshot.target!.addresses, ['127.0.0.2', '127.0.0.1']);
    expect(client.snapshot.target!.name, 'TV');

    // A different host is ignored.
    client.updateAddress(HostAddress(addresses: ['10.0.0.9'], port: 1, hostId: 'other'));
    expect(client.snapshot.target!.addresses, ['127.0.0.2', '127.0.0.1']);
  });
}
