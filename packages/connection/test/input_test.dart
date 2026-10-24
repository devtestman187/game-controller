import 'dart:io';
import 'dart:math';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

InputStateMessage? inputOf(HostSnapshot s, String id) =>
    s.controllers.where((c) => c.controllerId == id).firstOrNull?.input;

void main() {
  test('input from a paired phone reaches the host snapshot and message stream', () async {
    final host = await startHost();
    final received = <ControllerMessage>[];
    host.messages.listen(received.add);
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    client.sendInput({ControllerButton.a}, dx: -1, dy: 1);
    final s = await hostUntil(host, (h) => inputOf(h, 'phone-1')?.buttons.contains(ControllerButton.a) ?? false);
    expect(inputOf(s, 'phone-1')!.dx, -1);
    expect(inputOf(s, 'phone-1')!.dy, 1);
    await Future<void>.delayed(const Duration(milliseconds: 20)); // The message stream fires right after.
    expect(received.last.controllerId, 'phone-1');
    expect((received.last.message as InputStateMessage).buttons, {ControllerButton.a});
  });

  test('a direction and buttons register at the same time', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    client.sendInput({ControllerButton.a, ControllerButton.b}, dx: 1);
    final s = await hostUntil(host, (h) => inputOf(h, 'phone-1')?.buttons.length == 2);
    expect(inputOf(s, 'phone-1')!.dx, 1);
  });

  test('ignores input before pairing and out of order', () async {
    final host = await startHost();
    const codec = MessageCodec();
    final ws = await WebSocket.connect('ws://127.0.0.1:${host.port}$webSocketPath');
    addTearDown(ws.close);
    ws.listen((_) {});
    ws.add(codec.encode(const HelloMessage(controllerId: 'raw', name: 'Raw', platform: 'test', appVersion: 't')));
    ws.add(codec.encode(InputStateMessage(seq: 1, buttons: {ControllerButton.x})));
    await hostUntil(host, (h) => h.controllers.isNotEmpty);
    ws.add(codec.encode(PairRequestMessage(code: host.pairingCode)));
    await hostUntil(host, (h) => stateOf(h, 'raw') == ControllerState.connected);
    expect(inputOf(host.snapshot, 'raw'), isNull, reason: 'input sent before pairing is dropped');

    ws.add(codec.encode(InputStateMessage(seq: 5, buttons: {ControllerButton.y})));
    ws.add(codec.encode(InputStateMessage(seq: 4, buttons: {ControllerButton.b}))); // Late, ignored.
    ws.add(codec.encode(InputStateMessage(seq: 6, buttons: {ControllerButton.y, ControllerButton.start})));
    final s = await hostUntil(host, (h) => inputOf(h, 'raw')?.seq == 6);
    expect(inputOf(s, 'raw')!.buttons, {ControllerButton.y, ControllerButton.start});
  });

  test('a held button is sent again after a reconnect', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
    client.sendInput({ControllerButton.b});
    await hostUntil(host, (h) => inputOf(h, 'phone-1')?.buttons.isNotEmpty ?? false);

    host.dropAllConnections();
    await clientStatus(client, ClientStatus.reconnecting);
    await clientStatus(client, ClientStatus.connected);
    final s = await hostUntil(host, (h) => inputOf(h, 'phone-1')?.buttons.isNotEmpty ?? false);
    expect(inputOf(s, 'phone-1')!.buttons, {ControllerButton.b});
  });

  test('a dropped controller releases everything', () async {
    final host = await startHost();
    final received = <ControllerMessage>[];
    host.messages.listen(received.add);
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
    client.sendInput({ControllerButton.a}, dx: 1);
    await hostUntil(host, (h) => inputOf(h, 'phone-1')?.buttons.isNotEmpty ?? false);

    client.disconnect();
    final s = await hostUntil(host, (h) => stateOf(h, 'phone-1') == ControllerState.disconnected);
    expect(inputOf(s, 'phone-1'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((received.last.message as InputStateMessage).isNeutral, isTrue);
  });

  test('both sides report lowest, average and highest ping', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    final c = await clientUntil(client, (s) => (s.rttStats?.samples ?? 0) >= 2);
    expect(c.rttStats!.minMs, lessThanOrEqualTo(c.rttStats!.maxMs));
    final h = await hostUntil(host, (h) => (h.connected.firstOrNull?.rttStats?.samples ?? 0) >= 2);
    expect(h.connected.single.rttStats!.avgMs, lessThan(1000));
  });

  test('the ping window keeps only the last 30 seconds', () {
    final w = RttWindow();
    w.add(0, 100);
    w.add(10000, 10);
    w.add(20000, 30);
    expect(w.summary(20000).toString(), 'min 10 · avg 47 · max 100 ms');
    final later = w.summary(35000)!; // The 100 ms sample is now older than 30 s.
    expect([later.minMs, later.avgMs, later.maxMs, later.samples], [10, 20, 30, 2]);
    expect(w.summary(60001), isNull);
  });

  test('the demo walks all directions and presses every button', () {
    final directions = demoSteps.map((s) => (s.dx, s.dy)).toSet();
    expect(directions.length, 9); // Eight directions plus centered.
    final buttons = demoSteps.expand((s) => s.buttons).toSet();
    expect(buttons, ControllerButton.values.toSet());
  });

  test('the demo also sweeps the gyro tilt and ends released', () {
    final tilts = demoSteps.where((s) => s.ax != null).toList();
    expect(tilts.length, greaterThan(8));
    expect(tilts.map((s) => s.ax!).reduce(max), closeTo(0.8, 1e-9));
    expect(demoSteps.last.ax, isNull);
    expect(demoSteps.last.buttons, isEmpty);
  });

  test('tilt reaches the host with the buttons', () async {
    final host = await startHost();
    final client = newClient();
    client.connect(addressOf(host), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);
    client.sendInput({ControllerButton.a}, ax: -0.25, ay: 0.5);
    final s = await hostUntil(host, (h) => inputOf(h, 'phone-1')?.ax == -0.25);
    expect(inputOf(s, 'phone-1')!.ay, 0.5);
    expect(inputOf(s, 'phone-1')!.buttons, {ControllerButton.a});
  });
}
