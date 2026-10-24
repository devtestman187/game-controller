import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:test/test.dart';

/// Fast timings so the tests finish quickly, with enough slack for a busy CI
/// machine (a stalled event loop must not look like a dropped connection).
const hb = Duration(milliseconds: 100);
const hbTimeout = Duration(milliseconds: 1500);

Future<HostServer> startHost({
  int port = 0,
  int maxWrongCodes = 5,
  Duration pairingWindow = const Duration(minutes: 5),
  List<String>? log,
}) async {
  final host = HostServer(
    hostId: 'host-1',
    hostName: 'Test TV',
    appVersion: 'test',
    preferredPort: port,
    heartbeatInterval: hb,
    heartbeatTimeout: hbTimeout,
    pairingWindow: pairingWindow,
    maxWrongCodes: maxWrongCodes,
    log: log?.add,
  );
  await host.start();
  addTearDown(host.dispose);
  return host;
}

ControllerClient newClient({String id = 'phone-1', Map<String, String> tokens = const {}}) {
  final client = ControllerClient(
    identity: ControllerIdentity(controllerId: id, name: 'Phone $id', platform: 'test', appVersion: 'test'),
    tokens: tokens,
    heartbeatInterval: hb,
    heartbeatTimeout: hbTimeout,
    connectTimeout: const Duration(seconds: 1),
    retryDelays: const [Duration(milliseconds: 50), Duration(milliseconds: 100)],
  );
  addTearDown(client.dispose);
  return client;
}

HostAddress addressOf(HostServer host) => HostAddress(addresses: ['127.0.0.1'], port: host.port!);

Future<ClientSnapshot> clientUntil(
  ControllerClient client,
  bool Function(ClientSnapshot s) test, {
  Duration timeout = const Duration(seconds: 5),
}) {
  if (test(client.snapshot)) return Future.value(client.snapshot);
  return client.changes
      .firstWhere(test)
      .timeout(timeout, onTimeout: () => throw TimeoutException('Client stuck at ${client.snapshot}'));
}

Future<ClientSnapshot> clientStatus(ControllerClient client, ClientStatus status) =>
    clientUntil(client, (s) => s.status == status);

Future<HostSnapshot> hostUntil(
  HostServer host,
  bool Function(HostSnapshot s) test, {
  Duration timeout = const Duration(seconds: 5),
}) {
  if (test(host.snapshot)) return Future.value(host.snapshot);
  return host.changes
      .firstWhere(test)
      .timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Host stuck at ${host.snapshot.controllers.map((c) => '${c.name}: ${c.state.name}')}',
        ),
      );
}

ControllerState? stateOf(HostSnapshot s, String controllerId) =>
    s.controllers.where((c) => c.controllerId == controllerId).firstOrNull?.state;

/// A port that was free a moment ago, for tests that restart a host on the
/// same port.
Future<int> freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
