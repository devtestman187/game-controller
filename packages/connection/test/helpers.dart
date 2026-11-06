import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// Fast timings so the tests finish quickly, with enough slack for a busy CI
/// machine (a stalled event loop must not look like a dropped connection).
const hb = Duration(milliseconds: 100);
const hbTimeout = Duration(milliseconds: 1500);

/// How a test's host and phone reach each other: a WebSocket on localhost, or
/// a link inside this process, as the host phone's own player will use it
/// (D1). Every test that opens a channel runs on both.
enum TestTransport { webSocket, inProcess }

/// This test file's in-process listener, made on first use, so a host that
/// restarts registers on it again and its phones still reach it.
InProcessListener? _inProcess;

InProcessListener _inProcessListener() => _inProcess ??= InProcessListener();

/// The listener a host of a [transport] test starts on: the WebSocket on
/// [port] (0 asks for a free one), or the test's in-process one, which no
/// phone on the network can reach.
ChannelListener listenerFor(TestTransport transport, {int port = 0, LogSink? log}) => switch (transport) {
  TestTransport.webSocket => WebSocketListener(preferredPort: port, hostName: 'Test TV', log: log),
  TestTransport.inProcess => _inProcessListener(),
};

/// Starts a host with the test timings, reachable the way [transport] does.
Future<HostServer> startHost(
  TestTransport transport, {
  int port = 0,
  int maxWrongCodes = 5,
  Duration pairingWindow = const Duration(minutes: 5),
  List<String> capabilities = const [],
}) async {
  final host = HostServer(
    hostId: 'host-1',
    hostName: 'Test TV',
    appVersion: 'test',
    listeners: [listenerFor(transport, port: port)],
    heartbeatInterval: hb,
    heartbeatTimeout: hbTimeout,
    pairingWindow: pairingWindow,
    maxWrongCodes: maxWrongCodes,
    capabilities: capabilities,
  );
  await host.start();
  addTearDown(host.dispose);
  return host;
}

/// A phone with the test timings, connecting the way [transport] does, or
/// through [connector] when a test brings a host of its own.
ControllerClient newClient(
  TestTransport transport, {
  String id = 'phone-1',
  Map<String, String> tokens = const {},
  List<String> capabilities = const [],
  Connector? connector,
}) {
  final client = ControllerClient(
    identity: ControllerIdentity(
      controllerId: id,
      name: 'Phone $id',
      platform: 'test',
      appVersion: 'test',
      capabilities: capabilities,
    ),
    connector: connector ?? connectorFor(transport),
    tokens: tokens,
    heartbeatInterval: hb,
    heartbeatTimeout: hbTimeout,
    retryDelays: const [Duration(milliseconds: 50), Duration(milliseconds: 100)],
  );
  addTearDown(client.dispose);
  return client;
}

/// How a phone of a [transport] test opens its channel: a WebSocket on
/// localhost with the test's 1 s timeout, or the test's in-process listener.
Connector connectorFor(TestTransport transport) => switch (transport) {
  TestTransport.webSocket => WebSocketConnector(connectTimeout: const Duration(seconds: 1)),
  TestTransport.inProcess => InProcessConnector(_inProcessListener()),
};

/// The address a phone uses for [host] on [transport]: its port on localhost,
/// or the host phone's own player, which has no address.
HostAddress addressOf(HostServer host, TestTransport transport) => switch (transport) {
  TestTransport.webSocket => HostAddress(addresses: ['127.0.0.1'], port: host.port!),
  TestTransport.inProcess => HostAddress.local(hostId: host.hostId, name: host.hostName),
};

/// A channel to [host] that the test drives itself, as a hand-made phone.
Future<MessageChannel> rawPeer(HostServer host, TestTransport transport) async {
  final channel = switch (transport) {
    TestTransport.webSocket => WebSocketChannelAdapter(
      await WebSocket.connect('ws://127.0.0.1:${host.port}$webSocketPath'),
      remoteAddress: '127.0.0.1',
    ),
    TestTransport.inProcess => _inProcessListener().connect(),
  };
  addTearDown(() => channel.close(CloseCodes.goingAway));
  return channel;
}

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
