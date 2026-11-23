import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// What a phone lists to hear who wears what (M16 identity).
const _identityView = [Capability.view, Capability.identity];

/// Long enough that these tests end an away slot themselves, never by the clock.
const _longGrace = Duration(minutes: 1);

/// A look no default gives player 1 or 2: colour slot 5 with the crown.
const _crown = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown);

/// The nearest free look to the keyboard's default (slot 1, ears): slot 2 with the antenna.
const _nearestToKeyboard = PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna);

/// The `players` messages [phone] has had so far, oldest first.
List<PlayersMessage> _playersTo(WirePhone phone) => phone.fromHost.whereType<PlayersMessage>().toList();

/// A client that says [character] in its hello, as a phone does when it pairs with a look.
ControllerClient _newClientWith(TestTransport transport, {required String id, required PlayerCharacter character}) {
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

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      // A player's slot is held for a phone on the socket only: the host phone's
      // own in-process link keeps no slot (m12 code health N5).
      if (t == TestTransport.webSocket) {
        test('an away player keeps the character it paired with in the players a phone hears', () async {
          final server = await startHost(t, capabilities: _identityView);
          final game = ServerGameHost(server, awayGrace: _longGrace);
          addTearDown(game.dispose);
          final phone = await WirePhone.open(
            server,
            t,
            controllerId: 'phone-1',
            name: 'Mia',
            capabilities: _identityView,
            code: server.pairingCode,
          );
          final dropped = await _join(server, t, _newClientWith(t, id: 'phone-2', character: _crown));
          await hostUntil(server, (h) => h.connected.length == 2);

          // Phone 1 paired first, so phone 2 is player 2; its slot is held, so it stays in the list.
          dropped.disconnect();
          await playersUntil(game, (ps) => ps.any((p) => p.away));
          await phone.drain();
          final awayRow = _playersTo(phone).last.players.singleWhere((r) => r.id == 'phone-2');
          expect(awayRow.number, 2);
          expect(awayRow.character, _crown);

          // The round goes on without it: its slot ends, and its row goes with it.
          game.goOnWithout('phone-2');
          await phone.drain();
          expect(_playersTo(phone).last.players.map((r) => r.id), ['phone-1']);
        });
      }

      test('a phone that asks for a local player\'s look is given the nearest free one instead', () async {
        final server = await startHost(t, capabilities: _identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        final keyboard = game.addLocalPlayer(nickname: 'Keyboard');
        expect(keyboard.number, 1);

        final phone = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: _identityView,
          character: PlayerCharacter.forPlayer(keyboard.number),
          code: server.pairingCode,
        );
        await phone.drain();

        final given = phone.fromHost.whereType<PlayerMessage>().last.character;
        expect(given, _nearestToKeyboard);
        final row = _playersTo(phone).last.players.singleWhere((r) => r.id == 'phone-1');
        expect(row.character, _nearestToKeyboard);
      });
    });
  }
}
