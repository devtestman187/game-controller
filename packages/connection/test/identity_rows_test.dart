import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// What a phone lists to hear who wears what (M16 identity).
const _identityView = [Capability.view, Capability.identity];

/// Long enough that these tests end an away slot themselves, never by the clock.
const _longGrace = Duration(minutes: 1);

/// The `players` messages [phone] has had so far, oldest first.
List<PlayersMessage> _playersTo(WirePhone phone) => phone.fromHost.whereType<PlayersMessage>().toList();

/// Connects [client] to [server] with the pairing code, and waits for it.
Future<ControllerClient> _join(HostServer server, TestTransport t, ControllerClient client) async {
  client.connect(addressOf(server, t), code: server.pairingCode);
  await clientStatus(client, ClientStatus.connected);
  return client;
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a local player is in the next players a phone hears, with its number\'s default character', () async {
        final server = await startHost(t, capabilities: _identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        final phone = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: _identityView,
          code: server.pairingCode,
        );
        await phone.drain();

        final keyboard = game.addLocalPlayer(nickname: 'Keyboard');
        await phone.drain();

        final row = _playersTo(phone).last.players.singleWhere((r) => r.id == keyboard.id);
        expect(row.number, keyboard.number);
        expect(row.name, 'Keyboard');
        expect(row.character, PlayerCharacter.forPlayer(keyboard.number));
      });

      // A player's slot is held for a phone on the socket only: the host phone's
      // own in-process link keeps no slot (m12 code health N5).
      if (t == TestTransport.webSocket) {
        test('an away player is in the next players a phone hears, and leaves the list when its slot ends', () async {
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
          final dropped = await _join(server, t, newClient(t, id: 'phone-2', capabilities: _identityView));
          await hostUntil(server, (h) => h.connected.length == 2);

          // Phone 1 paired first, so phone 2 is player 2; its slot is held, so it stays in the list.
          dropped.disconnect();
          await playersUntil(game, (ps) => ps.any((p) => p.away));
          await phone.drain();
          final awayRow = _playersTo(phone).last.players.singleWhere((r) => r.id == 'phone-2');
          expect(awayRow.number, 2);
          expect(awayRow.character, PlayerCharacter.forPlayer(2));

          // The round goes on without it: its slot ends, and its row goes with it.
          game.goOnWithout('phone-2');
          await phone.drain();
          expect(_playersTo(phone).last.players.map((r) => r.id), ['phone-1']);
        });
      }
    });
  }
}
