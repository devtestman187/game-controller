import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Future<ControllerClient> paired(HostServer host, {String id = 'phone-1', ControllerClient? client}) async {
  final c = client ?? newClient(id: id);
  c.connect(addressOf(host), code: host.pairingCode);
  await clientStatus(c, ClientStatus.connected);
  return c;
}

void main() {
  group('player numbers', () {
    test('each controller gets its own number, on the TV and on the phone', () async {
      final host = await startHost();
      final one = await paired(host, id: 'phone-1');
      final two = await paired(host, id: 'phone-2');
      expect((await clientUntil(one, (s) => s.player != null)).player, 1);
      expect((await clientUntil(two, (s) => s.player != null)).player, 2);
      final h = await hostUntil(host, (h) => h.connected.length == 2);
      expect({for (final c in h.connected) c.controllerId: c.player}, {'phone-1': 1, 'phone-2': 2});
    });

    test('a controller that drops keeps its number, and a newcomer does not take it', () async {
      final host = await startHost();
      final one = await paired(host, id: 'phone-1');
      await paired(host, id: 'phone-2');
      one.disconnect();
      await hostUntil(host, (h) => h.connected.length == 1);

      final three = await paired(host, id: 'phone-3');
      expect((await clientUntil(three, (s) => s.player != null)).player, 3, reason: '1 is kept for phone-1');

      await paired(host, client: one);
      expect((await clientUntil(one, (s) => s.player != null)).player, 1);
    });

    test('the number is cleared on the phone when the connection drops', () async {
      final host = await startHost();
      final one = await paired(host);
      await clientUntil(one, (s) => s.player == 1);
      host.dropAllConnections();
      final s = await clientStatus(one, ClientStatus.reconnecting);
      expect(s.player, isNull);
      expect((await clientUntil(one, (s) => s.isConnected && s.player != null)).player, 1);
    });
  });

  group('saved pairings', () {
    test('a phone reconnects without a code after the TV app restarts', () async {
      List<SavedPairing> saved = const [];
      final first = HostServer(
        hostId: 'host-1',
        hostName: 'Test TV',
        appVersion: 'test',
        preferredPort: 0,
        heartbeatInterval: hb,
        heartbeatTimeout: hbTimeout,
        onPairingsChanged: (p) => saved = p,
      );
      await first.start();
      final port = first.port!;
      final phone = await paired(first);
      expect(saved.single.controllerId, 'phone-1');
      expect(saved.single.token, phone.tokens['host-1']);

      await first.dispose();
      await clientStatus(phone, ClientStatus.reconnecting);

      // The app starts again with the saved pairings (and a new code).
      final second = HostServer(
        hostId: 'host-1',
        hostName: 'Test TV',
        appVersion: 'test',
        preferredPort: port,
        heartbeatInterval: hb,
        heartbeatTimeout: hbTimeout,
        pairings: saved,
      );
      await second.start();
      addTearDown(second.dispose);
      if (second.port != port) {
        // The old port was still taken: discovery would report the new one.
        phone.updateAddress(HostAddress(addresses: ['127.0.0.1'], port: second.port!, hostId: 'host-1'));
      }
      final s = await clientStatus(phone, ClientStatus.connected);
      expect(s.problem, isNull);
      expect(second.snapshot.connected.single.controllerId, 'phone-1');
    });

    test('saved pairings show as disconnected until they come back, and can be forgotten', () async {
      final host = HostServer(
        hostId: 'host-1',
        hostName: 'Test TV',
        appVersion: 'test',
        preferredPort: 0,
        pairings: const [
          SavedPairing(controllerId: 'old', token: 't', name: 'Old phone', platform: 'ios', appVersion: '0.5.0'),
        ],
      );
      await host.start();
      addTearDown(host.dispose);
      expect(host.snapshot.controllers.single.state, ControllerState.disconnected);
      expect(host.snapshot.controllers.single.name, 'Old phone');
      expect(host.forgetDisconnected(), 1);
      expect(host.snapshot.controllers, isEmpty);
      expect(host.pairings, isEmpty);
    });

    test('forgetting keeps the pairing of a phone that is connected', () async {
      final host = await startHost();
      final phone = await paired(host);
      expect(host.forgetDisconnected(), 0);
      phone.disconnect();
      await hostUntil(host, (h) => h.connected.isEmpty);
      expect(host.forgetDisconnected(), 1);
    });

    test('only the most recent pairings are kept', () async {
      final host = HostServer(
        hostId: 'host-1',
        hostName: 'Test TV',
        appVersion: 'test',
        preferredPort: 0,
        maxSavedPairings: 2,
        pairings: [
          for (var i = 0; i < 2; i++)
            SavedPairing(controllerId: 'old-$i', token: 't$i', name: 'Old $i', platform: 'ios', appVersion: '1'),
        ],
        heartbeatInterval: hb,
        heartbeatTimeout: hbTimeout,
      );
      await host.start();
      addTearDown(host.dispose);
      await paired(host, id: 'new');
      expect(host.pairings, hasLength(2));
      expect(host.pairings.first.controllerId, 'new');
    });

    test('JSON round trip, and junk is ignored', () {
      const p = SavedPairing(
        controllerId: 'a',
        token: 'b',
        name: 'iPhone A',
        platform: 'ios',
        appVersion: '0.6.0',
        remoteAddress: '192.168.1.5',
      );
      final back = SavedPairing.fromJson(p.toJson())!;
      expect(
        [back.controllerId, back.token, back.name, back.platform, back.appVersion, back.remoteAddress],
        ['a', 'b', 'iPhone A', 'ios', '0.6.0', '192.168.1.5'],
      );
      for (final junk in [
        null,
        3,
        'x',
        <String, Object?>{},
        {'id': 'a'},
        {'id': '', 'token': 'b'},
      ]) {
        expect(SavedPairing.fromJson(junk), isNull, reason: '$junk');
      }
    });
  });

  group('input latency', () {
    test('the clock offset comes from the fastest ping, and input delay is measured against it', () {
      final l = InputLatency();
      // The phone's clock is 5000 ms ahead. One slow, lopsided ping first.
      l.addPong(sentAtMs: 0, peerMs: 5090, receivedMs: 100);
      l.addPong(sentAtMs: 1000, peerMs: 6005, receivedMs: 1010); // 5 ms each way.
      expect(l.offsetMs, 5000);
      expect(l.uncertaintyMs, 5);
      // Sent at 7000 on the phone (2000 on the TV), arrives at 2012.
      expect(l.addInput(peerSentMs: 7000, receivedMs: 2012), 12);
      expect(l.addInput(peerSentMs: 7100, receivedMs: 2108), 8);
      final s = l.summary(2108)!;
      expect([s.minMs, s.avgMs, s.maxMs, s.samples], [8, 10, 12, 2]);
      expect(l.session.count, 2);
    });

    test('no estimate before the first clock sample; estimation error never goes below 0', () {
      final l = InputLatency();
      expect(l.addInput(peerSentMs: 10, receivedMs: 10), isNull);
      l.addPong(sentAtMs: 0, peerMs: 100, receivedMs: 20);
      expect(l.addInput(peerSentMs: 200, receivedMs: 100), 0);
    });

    test('old clock samples are dropped, so drift between the clocks is followed', () {
      final l = InputLatency(clockWindow: const Duration(seconds: 20));
      l.addPong(sentAtMs: 0, peerMs: 1000, receivedMs: 2); // Very fast, offset 999.
      l.addPong(sentAtMs: 30000, peerMs: 31010, receivedMs: 30010); // Later, offset 1005.
      expect(l.offsetMs, 1005);
    });

    test('the host measures it for a phone that stamps its input, and logs it', () async {
      final log = <String>[];
      final host = HostServer(
        hostId: 'host-1',
        hostName: 'Test TV',
        appVersion: 'test',
        preferredPort: 0,
        heartbeatInterval: hb,
        heartbeatTimeout: hbTimeout,
        latencyLogInterval: const Duration(milliseconds: 300),
        log: log.add,
      );
      await host.start();
      addTearDown(host.dispose);
      final phone = await paired(host);
      await hostUntil(host, (h) => h.connected.single.latencyErrorMs != null);
      for (var i = 0; i < 5; i++) {
        phone.sendInput({ControllerButton.a}, dx: i.isEven ? 1 : 0);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final c = (await hostUntil(host, (h) => (h.connected.single.inputLatency?.samples ?? 0) >= 5)).connected.single;
      // On one machine the delay is a few ms; allow for a slow CI runner.
      expect(c.inputLatency!.avgMs, lessThan(200));
      expect(c.inputLatencySession!.samples, greaterThanOrEqualTo(5));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(log.where((l) => l.startsWith('Latency Phone phone-1: ping')), isNotEmpty);
      expect(log.where((l) => l.contains('input delay ~ avg')), isNotEmpty);
      phone.disconnect();
      await hostUntil(host, (h) => h.connected.isEmpty);
      expect(log.where((l) => l.startsWith('Session of Phone phone-1 ended')), hasLength(1));
    });
  });

  group('resume', () {
    test('a connection that went quiet while the app slept is replaced at once', () async {
      var now = DateTime(2026, 10, 25, 12);
      final host = await startHost();
      final phone = ControllerClient(
        identity: const ControllerIdentity(controllerId: 'p', name: 'Phone', platform: 'test', appVersion: 'test'),
        heartbeatInterval: hb,
        heartbeatTimeout: hbTimeout,
        retryDelays: const [Duration(seconds: 30)], // Long, so only resume() can reconnect in time.
        wallClock: () => now,
      );
      addTearDown(phone.dispose);
      await paired(host, client: phone);

      phone.resume();
      expect(phone.snapshot.status, ClientStatus.connected, reason: 'nothing to do right after a message');

      now = now.add(const Duration(seconds: 20)); // The phone slept.
      final states = <ClientStatus>[];
      final sub = phone.changes.listen((s) => states.add(s.status));
      phone.resume();
      await clientUntil(phone, (s) => s.isConnected && s.attempt == 0, timeout: const Duration(seconds: 3));
      await sub.cancel();
      expect(states, contains(ClientStatus.reconnecting));
      expect(host.snapshot.connected, hasLength(1));
    });

    test('resume tries a pending reconnect now instead of waiting', () async {
      final host = await startHost();
      final phone = ControllerClient(
        identity: const ControllerIdentity(controllerId: 'p', name: 'Phone', platform: 'test', appVersion: 'test'),
        heartbeatInterval: hb,
        heartbeatTimeout: hbTimeout,
        retryDelays: const [Duration(seconds: 30)],
      );
      addTearDown(phone.dispose);
      await paired(host, client: phone);
      host.dropAllConnections();
      await clientStatus(phone, ClientStatus.reconnecting);
      phone.resume();
      await clientStatus(phone, ClientStatus.connected).timeout(const Duration(seconds: 3));
    });
  });
}
