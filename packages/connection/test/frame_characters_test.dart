import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// The character the phone asks for in the lobby: slot 4's teal crown.
const crown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// A character a frame gives the same phone, which the host does not agree
/// with: slot 2's orange bow.
const bow = PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow);

/// What a phone lists to hear who wears what (M16 identity), and to show the
/// game.
const identityView = [Capability.view, Capability.identity];

/// The view a round shows (m12).
const start = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: {}, hz: 60);

/// A frame of a round with one roster player, [characters] as the game gave
/// them (M16 identity).
FrameMessage frameWith(Map<String, PlayerCharacter> characters) => FrameMessage(
  n: 0,
  atMs: 0,
  snapshot: const {'score': 0},
  roster: const {'phone-1': (number: 1, name: 'Mia')},
  characters: characters,
);

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a roster player character in a frame is replaced by the host character when they differ', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        final phone = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: identityView,
          character: crown,
          code: server.pairingCode,
        );
        await phone.drain();

        game.startView(start);
        game.publishFrame(frameWith({'phone-1': bow}));
        await phone.drain();

        // The frame carries one character, as the frame it was given did, but
        // the host's crown, not the bow the game gave.
        final shown = phone.fromHost.whereType<FrameMessage>().single;
        expect(shown.characters, {'phone-1': crown});
      });

      test('a frame whose characters already match the host is sent with the same content', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = ServerGameHost(server);
        addTearDown(game.dispose);
        final phone = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: identityView,
          character: crown,
          code: server.pairingCode,
        );
        await phone.drain();

        game.startView(start);
        game.publishFrame(frameWith({'phone-1': crown}));
        await phone.drain();

        final shown = phone.fromHost.whereType<FrameMessage>().single;
        expect(shown.toPayload(), frameWith({'phone-1': crown}).toPayload());
      });
    });
  }
}
