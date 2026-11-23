import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// What a phone lists to hear who wears what (M16 identity).
const _identityView = [Capability.view, Capability.identity];

/// Long enough that these tests end an away slot themselves, never by the clock.
const _longGrace = Duration(minutes: 1);

/// The look a phone wears before it drops: colour slot 5 with the crown, which no default gives player 1 or 2.
const _worn = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown);

/// The look its hello asks for when it pairs again: colour slot 3 with the bow.
const _asked = PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.bow);

/// The view a round shows (m12).
const _start = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: {}, hz: 60);

/// A client as [id] that says [character] in its hello, as a phone does when it pairs with a look.
ControllerClient _clientWith(TestTransport transport, {required String id, required PlayerCharacter character}) {
  final client = ControllerClient(
    identity: ControllerIdentity(
      controllerId: id,
      name: 'Phone $id',
      platform: 'test',
      appVersion: 'test',
      capabilities: _identityView,
      character: character,
    ),
    connector: connectorFor(transport),
    retryDelays: const [Duration(milliseconds: 50), Duration(milliseconds: 100)],
  );
  addTearDown(client.dispose);
  return client;
}

/// Connects [client] to [server] with the pairing code, and waits for it.
Future<ControllerClient> _join(HostServer server, TestTransport t, ControllerClient client) async {
  client.connect(addressOf(server, t), code: server.pairingCode);
  await clientStatus(client, ClientStatus.connected);
  return client;
}

/// The character [id] wears in the last `players` list [observer] heard.
PlayerCharacter _wearingIn(WirePhone observer, String id) =>
    observer.fromHost.whereType<PlayersMessage>().last.players.singleWhere((r) => r.id == id).character;

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a phone that pairs again mid-round keeps the look it wore until the round ends', () async {
        final server = await startHost(t, capabilities: _identityView);
        final game = ServerGameHost(server, awayGrace: _longGrace);
        addTearDown(game.dispose);
        final observer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: _identityView,
          code: server.pairingCode,
        );
        final first = await _join(server, t, _clientWith(t, id: 'phone-2', character: _worn));
        await hostUntil(server, (h) => h.connected.length == 2);

        game.startView(_start);
        first.disconnect();
        await hostUntil(server, (h) => h.connected.length == 1);

        // Pairing again mid-round: the hello asks for _asked, but the phone keeps _worn.
        final second = await _join(server, t, _clientWith(t, id: 'phone-2', character: _asked));
        await clientUntil(second, (s) => s.character == _worn);
        await observer.drain();
        expect(_wearingIn(observer, 'phone-2'), _worn);

        // The round's end applies the look the hello asked for.
        game.endView(const ViewEndMessage(reason: ViewEndReason.finished));
        await clientUntil(second, (s) => s.character == _asked);
        await observer.drain();
        expect(_wearingIn(observer, 'phone-2'), _asked);
      });

      test('a phone that pairs again outside a round wears the look its hello asks for at once', () async {
        final server = await startHost(t, capabilities: _identityView);
        final game = ServerGameHost(server, awayGrace: _longGrace);
        addTearDown(game.dispose);
        final observer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: _identityView,
          code: server.pairingCode,
        );
        final first = await _join(server, t, _clientWith(t, id: 'phone-2', character: _worn));
        await hostUntil(server, (h) => h.connected.length == 2);

        first.disconnect();
        await hostUntil(server, (h) => h.connected.length == 1);

        final second = await _join(server, t, _clientWith(t, id: 'phone-2', character: _asked));
        await clientUntil(second, (s) => s.character == _asked);
        await observer.drain();
        expect(_wearingIn(observer, 'phone-2'), _asked);
      });
    });
  }
}
