import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The stats answers a host receives, in order (sentry1 stats option B).
Stream<StatsShareMessage> statsShares(HostServer host) async* {
  await for (final m in host.messages) {
    if (m.message case final StatsShareMessage share) yield share;
  }
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a phone that gives no answer sends no stats_share', () async {
        final host = await startHost(t);
        final received = <ControllerMessage>[];
        host.messages.listen(received.add);
        final client = newClient(t);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);

        // This input goes out after everything a pairing phone sends, so when
        // the host has it, no stats_share is on its way.
        client.sendInput({ControllerButton.a});
        await host.messages.firstWhere((m) => m.message is InputStateMessage).timeout(const Duration(seconds: 5));

        expect([
          for (final m in received)
            if (m.message is StatsShareMessage) m.controllerId,
        ], isEmpty);
      });

      test('an answer given before pairing goes out as soon as the phone is paired', () async {
        final host = await startHost(t);
        final answer = statsShares(host).first;
        final client = newClient(t);
        client.setStatsShare(true);
        client.connect(addressOf(host, t), code: host.pairingCode);

        final share = await answer.timeout(const Duration(seconds: 5));
        expect(share.share, isTrue);
      });

      test('the answer goes out again after a reconnect', () async {
        final host = await startHost(t);
        final answers = statsShares(host).take(2).toList();
        final client = newClient(t);
        client.setStatsShare(true);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        // The pairing's own answer, before the link drops.
        await statsShares(host).first.timeout(const Duration(seconds: 5));

        host.dropAllConnections();
        await clientStatus(client, ClientStatus.reconnecting);
        final shares = await answers.timeout(const Duration(seconds: 5));

        expect([for (final s in shares) s.share], [true, true]);
      });

      test('a change while connected is sent at once', () async {
        final host = await startHost(t);
        final answers = statsShares(host).take(2).toList();
        final client = newClient(t);
        client.setStatsShare(true);
        client.connect(addressOf(host, t), code: host.pairingCode);
        await clientStatus(client, ClientStatus.connected);
        client.setStatsShare(false);

        final shares = await answers.timeout(const Duration(seconds: 5));

        expect([for (final s in shares) s.share], [true, false]);
      });
    });
  }
}
