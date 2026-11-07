import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'fake_host.dart';
import 'helpers.dart';

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('reconnects after a drop without asking for the code', () async {
        final host = await startHost(t);
        final client = newClient(t);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);

        host.dropAllConnections();
        final dropped = await clientStatus(client, ClientStatus.reconnecting);
        expect(dropped.problem, ClientProblem.connectionLost);
        final back = await clientStatus(client, ClientStatus.connected);
        expect(back.attempt, 0);
        expect(back.problem, isNull);
        await hostUntil(host, (h) => stateOf(h, 'phone-1') == ControllerState.connected);
      });

      test('a host that stopped is reached again after it restarts', () async {
        // The host comes back on the port it had, as the TV app does, so the
        // phone's saved address still finds it.
        final host = await startHost(t, port: await freePort());
        final client = newClient(t);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);

        await host.stop();
        await clientStatus(client, ClientStatus.reconnecting);
        await host.start();
        final s = await clientStatus(client, ClientStatus.connected);
        expect(s.problem, isNull);
        expect(host.snapshot.connected.single.controllerId, 'phone-1');
      });

      test('asks for the code again after the TV app restarts', () async {
        final first = await startHost(t);
        final port = first.port ?? 0;
        final client = newClient(t);
        client.connect(addressOf(first, t), code: first.pairingCode);
        await clientStatus(client, ClientStatus.connected);

        await first.dispose();
        final restarted = await startHost(t, port: port); // Fresh state: no known controllers.
        final s = await clientUntil(client, (s) => s.problem == ClientProblem.pairingForgotten);
        expect(s.status, ClientStatus.waitingForCode);
        expect(client.tokens, isEmpty);

        client.submitCode(restarted.pairingCode);
        await clientStatus(client, ClientStatus.connected);
      });

      test('a saved token reconnects without a code after the phone app restarts', () async {
        final host = await startHost(t);
        final first = newClient(t);
        first.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(first, ClientStatus.connected);
        final saved = first.tokens;
        first.disconnect();
        await hostUntil(host, (h) => stateOf(h, 'phone-1') == ControllerState.disconnected);

        final relaunched = newClient(t, tokens: saved);
        relaunched.connect(addressOf(host, t));
        await clientStatus(relaunched, ClientStatus.connected);
      });

      test('reports new tokens through the callback', () async {
        final host = await startHost(t);
        final saved = <String, String?>{};
        final client = ControllerClient(
          identity: const ControllerIdentity(controllerId: 'p', name: 'P', platform: 'test', appVersion: 't'),
          connector: connectorFor(t),
          onTokenChanged: (hostId, token) => saved[hostId] = token,
          heartbeatInterval: hb,
          heartbeatTimeout: hbTimeout,
        );
        addTearDown(client.dispose);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        expect(saved['host-1'], client.tokens['host-1']);
      });

      test('the host drops a controller that stops answering', () async {
        final host = await startHost(t);
        // A hand-driven peer that pairs, then goes silent like a phone that lost Wi-Fi.
        final channel = await rawPeer(host, t);
        const codec = MessageCodec();
        channel.send(
          codec.encode(const HelloMessage(controllerId: 'silent', name: 'Silent', platform: 'test', appVersion: 't')),
        );
        channel.send(codec.encode(PairRequestMessage(code: host.pairingCode)));
        final closed = channel.incoming.drain<void>();

        await hostUntil(host, (h) => stateOf(h, 'silent') == ControllerState.connected);
        await hostUntil(host, (h) => stateOf(h, 'silent') == ControllerState.disconnected);
        await closed;
        expect(channel.closeCode, CloseCodes.heartbeatTimeout);
      });

      test('the phone notices a host that stops answering', () async {
        // A fake host that pairs, then goes silent like a TV that lost Wi-Fi.
        final host = await FakeHost.start(t);
        const codec = MessageCodec();
        host.onChannel = (channel) => channel.incoming.listen((data) {
          final m = codec.decode(data);
          if (m is HelloMessage) {
            channel.send(codec.encode(const WelcomeMessage(hostId: 'h', hostName: 'Silent TV', appVersion: 't')));
          } else if (m is PairRequestMessage) {
            channel.send(codec.encode(const PairResultMessage.accepted(token: 'tok')));
          }
        });

        final client = newClient(t, connector: host);
        client.connect(host.address, code: '1234');
        await clientStatus(client, ClientStatus.connected);
        final s = await clientStatus(client, ClientStatus.reconnecting);
        expect(s.detail, 'No heartbeat');
      });

      test('disconnect stops retrying', () async {
        final host = await startHost(t);
        final client = newClient(t);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        await host.stop();
        await clientStatus(client, ClientStatus.reconnecting);

        client.disconnect();
        expect(client.snapshot.status, ClientStatus.idle);
        await host.start();
        // Another phone's heartbeats take longer than the first phone's last
        // retry gap (its retryDelays end at 100 ms), so a retry would have
        // shown in its status by now.
        final other = newClient(t, id: 'other');
        other.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(other, ClientStatus.connected);
        await clientUntil(other, (s) => (s.rttStats?.samples ?? 0) >= 3);
        expect(client.snapshot.status, ClientStatus.idle);
        expect(host.snapshot.connected.map((c) => c.controllerId), ['other']);
      });
    });
  }

  // Web-socket only: it pins the port and follows the host to a new one.
  test('keeps retrying while the host is away, then reconnects', () async {
    const t = TestTransport.webSocket;
    final port = await freePort();
    final host = await startHost(t, port: port);
    final client = newClient(t);
    client.connect(addressOf(host, t), code: host.pairingCode);
    await clientStatus(client, ClientStatus.connected);

    await host.stop();
    await clientUntil(client, (s) => s.status == ClientStatus.reconnecting && s.attempt >= 3);

    // The same host comes back on the same port with the same state.
    await host.start();
    expect(host.port, port);
    await clientStatus(client, ClientStatus.connected);
  });

  // Web-socket only: it reorders network addresses and needs two of them.
  test('uses the new address when discovery finds the host elsewhere', () async {
    const t = TestTransport.webSocket;
    final host = await startHost(t);
    final client = newClient(t);
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
