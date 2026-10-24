import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('pairs with the right code and shows Connected on both sides', () async {
    final host = await startHost();
    final client = newClient();

    client.connect(addressOf(host), code: host.pairingCode);
    final s = await clientStatus(client, ClientStatus.connected);
    expect(s.hostName, 'Test TV');
    expect(s.target!.hostId, 'host-1');
    expect(client.tokens['host-1'], isNotNull);

    final h = await hostUntil(host, (h) => h.connected.isNotEmpty);
    expect(h.connected.single.name, 'Phone phone-1');
    expect(h.connected.single.platform, 'test');
  });

  test('measures the round-trip time on both sides', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);

    await clientUntil(client, (s) => s.isConnected && s.rttMs != null);
    final h = await hostUntil(host, (h) => h.connected.any((c) => c.rttMs != null));
    expect(h.connected.single.rttMs, lessThan(1000));
  });

  test('asks for the code when there is no saved pairing', () async {
    final host = await startHost();
    final client = newClient();

    client.connect(addressOf(host));
    await clientStatus(client, ClientStatus.waitingForCode);
    expect(stateOf(host.snapshot, 'phone-1'), ControllerState.pairing);

    client.submitCode(host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
  });

  test('rejects a wrong code, then accepts the right one', () async {
    final host = await startHost();
    final client = newClient();
    final wrong = host.pairingCode == '0000' ? '1111' : '0000';

    client.connect(addressOf(host), code: wrong);
    final s = await clientUntil(client, (s) => s.problem == ClientProblem.wrongCode);
    expect(s.status, ClientStatus.waitingForCode);
    expect(client.tokens, isEmpty);
    // The connection is closed and the controller never shows as connected.
    await hostUntil(host, (h) => h.controllers.isEmpty);

    client.submitCode(host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
  });

  test('changes the code after too many wrong codes', () async {
    final host = await startHost(maxWrongCodes: 2);
    final first = host.pairingCode;
    final wrong = first == '0000' ? '1111' : '0000';
    final client = newClient();

    client.connect(addressOf(host), code: wrong);
    await clientUntil(client, (s) => s.problem == ClientProblem.wrongCode);
    client.submitCode(wrong);
    await clientUntil(client, (s) => s.problem == ClientProblem.tooManyAttempts);
    expect(host.pairingCode, isNot(first));

    // The old code no longer works.
    client.submitCode(first);
    await clientUntil(client, (s) => s.status == ClientStatus.waitingForCode && s.problem == ClientProblem.wrongCode);
  });

  test('a new code on the TV keeps paired controllers paired', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    host.newPairingCode();
    host.dropAllConnections();
    await clientStatus(client, ClientStatus.reconnecting);
    await clientStatus(client, ClientStatus.connected);
  });

  test('closes connections that never pair', () async {
    final host = await startHost(pairingWindow: const Duration(milliseconds: 200));
    final client = newClient();
    client.connect(addressOf(host));
    await clientStatus(client, ClientStatus.waitingForCode);
    final s = await clientStatus(client, ClientStatus.failed);
    expect(s.problem, ClientProblem.pairingTimeout);
  });

  test('a newer connection from the same phone replaces the older one', () async {
    final host = await startHost();
    final first = newClient();
    final second = newClient();
    first.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(first, ClientStatus.connected);

    second.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(second, ClientStatus.connected);
    final s = await clientStatus(first, ClientStatus.failed);
    expect(s.problem, ClientProblem.replaced);
    expect(host.snapshot.connected.length, 1);
  });

  test('rejects a controller with a different protocol version', () async {
    final host = await startHost();
    final ws = await WebSocket.connect('ws://127.0.0.1:${host.port}$webSocketPath');
    ws.add(jsonEncode({'v': protocolVersion + 1, 't': 'hello'}));
    await ws.drain<void>();
    expect(ws.closeCode, CloseCodes.versionMismatch);
  });

  test('rejects pairing before hello', () async {
    final host = await startHost();
    final ws = await WebSocket.connect('ws://127.0.0.1:${host.port}$webSocketPath');
    ws.add(const MessageCodec().encode(PairRequestMessage(code: host.pairingCode)));
    await ws.drain<void>();
    expect(ws.closeCode, CloseCodes.protocolError);
    expect(host.snapshot.connected, isEmpty);
  });

  test('reports an unreachable host', () async {
    // Grab a free port, then close it so nothing listens there.
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final client = newClient();
    client.connect(HostAddress(addresses: ['127.0.0.1'], port: port));
    final s = await clientStatus(client, ClientStatus.failed);
    expect(s.problem, ClientProblem.unreachable);
    expect(s.detail, isNotNull);
  });

  test('answers plain HTTP so the firewall can be checked from a browser', () async {
    final host = await startHost();
    final http = HttpClient();
    addTearDown(http.close);
    final response = await (await http.get('127.0.0.1', host.port!, '/')).close();
    expect(response.statusCode, 200);
    expect(await response.transform(utf8.decoder).join(), contains('Test TV'));
  });
}
