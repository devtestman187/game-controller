import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// What a phone lists to hear who wears what (M16 identity), and to show the
/// game.
const identityView = [Capability.view, Capability.identity];

/// The name a phone sends when its player left the nickname blank: "Phone"
/// and its controller ID's first four characters, as the phone builds it.
const phoneOwnName = 'Phone AB12';

void main() {
  test('isPhoneStyleName is true for the phone\'s own name, with or without spaces around it', () {
    expect(isPhoneStyleName('Phone AB12'), isTrue);
    expect(isPhoneStyleName(' Phone 1a2b '), isTrue);
  });

  test('isPhoneStyleName is false for anything else', () {
    expect(isPhoneStyleName('Phone'), isFalse);
    expect(isPhoneStyleName('Phone AB1'), isFalse);
    expect(isPhoneStyleName('Phone ABCDE'), isFalse);
    expect(isPhoneStyleName('Mia'), isFalse);
  });

  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a phone that sent its own phone name gets a blank name in the players message', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        final phone = await WirePhone.open(
          server,
          t,
          controllerId: 'ab12cd34',
          name: phoneOwnName,
          capabilities: identityView,
          code: server.pairingCode,
        );
        await playersUntil(game, (ps) => ps.length == 1);
        await phone.drain();

        expect(phone.fromHost.whereType<PlayersMessage>().last.players.single.name, '');
      });

      test('a phone with a nickname keeps it in the players message', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        final phone = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: identityView,
          code: server.pairingCode,
        );
        await playersUntil(game, (ps) => ps.length == 1);
        await phone.drain();

        expect(phone.fromHost.whereType<PlayersMessage>().last.players.single.name, 'Mia');
      });

      test('the game lists no nickname for a phone-style name', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        await WirePhone.open(
          server,
          t,
          controllerId: 'ab12cd34',
          name: phoneOwnName,
          capabilities: identityView,
          code: server.pairingCode,
        );
        final players = await playersUntil(game, (ps) => ps.length == 1);

        expect(players.single.nickname, isNull);
      });
    });
  }
}
