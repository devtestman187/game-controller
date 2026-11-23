import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The pick the contested tests ask for (M14 L7): slot 4's teal crown.
const contested = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// What a phone gets while [contested] is held by one other player: the
/// nearest free one, slot 5's tuft (identity_reservation_test.dart asks the same).
const nearestToContested = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.tuft);

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a dropped player\'s colour and accessory stay reserved for the reserve minute, then free', () async {
        var now = DateTime(2026, 11, 23, 12);
        final host = await startClockedHost(t, () => now);
        final dropped = controller(t, id: 'phone-1', character: contested);
        dropped.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(dropped)).character, contested);

        dropped.disconnect();
        await hostUntil(host, (s) => s.connected.every((c) => c.controllerId != 'phone-1'));

        // Within the minute, a phone asking for the same pick gets the nearest free one.
        final second = controller(t, id: 'phone-2', character: contested);
        second.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(second)).character, nearestToContested);

        // 61 s later the reserve minute is over, so the colour is free again.
        now = now.add(const Duration(seconds: 61));
        final third = controller(t, id: 'phone-3', character: contested);
        third.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(third)).character, contested);
      });

      test('a returning player gets its own colour and accessory back within the reserve minute', () async {
        var now = DateTime(2026, 11, 23, 12);
        final host = await startClockedHost(t, () => now);
        final returning = controller(t, id: 'phone-1', character: contested);
        returning.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(returning)).character, contested);

        returning.disconnect();
        await hostUntil(host, (s) => s.connected.every((c) => c.controllerId != 'phone-1'));

        // While it is away, another phone takes the nearest free pick.
        final other = controller(t, id: 'phone-2', character: contested);
        other.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(other)).character, nearestToContested);

        // 30 s after the drop, still within the minute, it comes back with its pick.
        now = now.add(const Duration(seconds: 30));
        returning.connect(addressOf(host, t));
        expect((await paired(returning)).character, contested);
      });
    });
  }
}

/// A host with the test timings and the clock [clock] (for the reserve minute),
/// listening the way [transport] does.
Future<HostServer> startClockedHost(TestTransport transport, DateTime Function() clock) async {
  final host = HostServer(
    hostId: 'host-1',
    hostName: 'Test TV',
    appVersion: 'test',
    listeners: [listenerFor(transport)],
    heartbeatInterval: hb,
    heartbeatTimeout: hbTimeout,
    clock: clock,
  );
  await host.start();
  addTearDown(host.dispose);
  return host;
}

/// A phone with the test timings, connecting the way [transport] does, whose
/// identity carries [character] (none when null).
ControllerClient controller(TestTransport transport, {required String id, PlayerCharacter? character}) {
  final client = ControllerClient(
    identity: ControllerIdentity(
      controllerId: id,
      name: 'Phone $id',
      platform: 'test',
      appVersion: 'test',
      character: character,
    ),
    connector: connectorFor(transport),
    heartbeatInterval: hb,
    heartbeatTimeout: hbTimeout,
    retryDelays: const [Duration(milliseconds: 50), Duration(milliseconds: 100)],
  );
  addTearDown(client.dispose);
  return client;
}

/// The client's state once the host has paired it and said which character it
/// wears.
Future<ClientSnapshot> paired(ControllerClient client) =>
    clientUntil(client, (s) => s.status == ClientStatus.connected && s.character != null);
