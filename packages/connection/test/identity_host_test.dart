import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// The character the first test phone asks for: slot 4's teal crown.
const crown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// The character a phone changes to: slot 2's orange bow.
const bow = PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow);

/// What a phone lists to hear who wears what (M16 identity), and to show the
/// game.
const identityView = [Capability.view, Capability.identity];

/// A phone one build older: it shows the game and knows no identity.
const viewOnly = [Capability.view];

/// The view a round shows (m12).
const start = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: {}, hz: 60);

/// A frame of a round with both test players in its roster and no characters
/// of its own: the host fills them in (M16 identity).
FrameMessage frameOf(int n) => FrameMessage(
  n: n,
  atMs: n * 16,
  snapshot: const {'score': 0},
  roster: const {'phone-1': (number: 1, name: 'Mia'), 'phone-2': (number: 2, name: 'Dad')},
);

/// The `players` messages [phone] has had so far, oldest first.
List<PlayersMessage> playersTo(WirePhone phone) => phone.fromHost.whereType<PlayersMessage>().toList();

/// The game host over [server], disposed with the test: the round's start and
/// end are what a character change waits for.
ServerGameHost startGame(HostServer server) {
  final game = ServerGameHost(server);
  addTearDown(game.dispose);
  return game;
}

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a character chosen in the lobby applies, and its answer carries what the host gave', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = startGame(server);
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
        expect(phone.fromHost.whereType<PlayerMessage>().single.character, crown);

        final answer = await phone.ask<PlayerMessage>(const SetCharacterMessage(character: bow));

        expect(answer.character, bow);
        final players = await playersUntil(game, (ps) => ps.single.character == bow);
        expect(players.single.character, bow);
      });

      test('a change onto a taken pick gets the nearest free character', () async {
        final server = await startHost(t, capabilities: identityView);
        final first = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: identityView,
          character: crown,
          code: server.pairingCode,
        );
        await first.drain();
        final second = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-2',
          name: 'Dad',
          capabilities: identityView,
          code: server.pairingCode,
        );
        await second.drain();
        // Only the crown is taken, so the second phone keeps player 2's default.
        expect(second.fromHost.whereType<PlayerMessage>().single.character, PlayerCharacter.forPlayer(2));

        final answer = await second.ask<PlayerMessage>(const SetCharacterMessage(character: crown));

        // Slot 4 and the crown are taken: the next colour up and the accessory
        // down from the crown are free.
        expect(answer.character, const PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.tuft));
      });

      test('a change during a round waits for the round to end, so a running round\'s players never change', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = startGame(server);
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
        game.publishFrame(frameOf(0));
        await phone.drain();

        phone.send(const SetCharacterMessage(character: bow));
        await phone.drain();

        // Still the crown, and no answer yet: a running round's players never
        // change.
        expect(phone.fromHost.whereType<PlayerMessage>().map((m) => m.character), [crown]);
        expect(game.players.single.character, crown);

        game.endView(const ViewEndMessage(reason: ViewEndReason.finished));
        await phone.drain();

        // The round's end is when the change takes effect.
        expect(phone.fromHost.whereType<PlayerMessage>().map((m) => m.character), [crown, bow]);
        final players = await playersUntil(game, (ps) => ps.single.character == bow);
        expect(players.single.character, bow);
      });

      test('the players message goes to every identity phone on join, leave and change, and to no other', () async {
        final server = await startHost(t, capabilities: identityView);
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-9',
          name: 'Ava',
          capabilities: viewOnly,
          code: server.pairingCode,
        );
        final first = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: identityView,
          character: crown,
          code: server.pairingCode,
        );
        await first.drain();
        // Player 1 is the phone one build older: it is a player all the same.
        expect(playersTo(first).single.players.map((r) => r.id), ['phone-9', 'phone-1']);

        // A second phone joins: both identity phones hear the new list.
        final second = newClient(t, id: 'phone-2', capabilities: viewOnly);
        second.connect(addressOf(server, t), code: server.pairingCode);
        await clientUntil(second, (s) => s.status == ClientStatus.connected && s.players.isNotEmpty);
        await first.drain();
        expect(playersTo(first).last.players.map((r) => r.id), ['phone-9', 'phone-1', 'phone-2']);

        // It leaves: its row goes with it.
        second.disconnect();
        await hostUntil(server, (s) => s.connected.every((c) => c.controllerId != 'phone-2'));
        await first.drain();
        expect(playersTo(first).last.players.map((r) => r.id), ['phone-9', 'phone-1']);

        // A change: the list says what it changed to.
        await first.ask<PlayerMessage>(const SetCharacterMessage(character: bow));
        await first.drain();
        final row = playersTo(first).last.players.firstWhere((r) => r.id == 'phone-1');
        expect(row.character, bow);

        // The phone one build older has heard none of it.
        expect(playersTo(older), isEmpty);
        await older.drain();
        expect(playersTo(older), isEmpty);
      });

      test('frames carry chars only to a phone that listed identity, live and mid-round', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = startGame(server);
        final identity = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: identityView,
          character: crown,
          code: server.pairingCode,
        );
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-2',
          name: 'Dad',
          capabilities: viewOnly,
          character: bow,
          code: server.pairingCode,
        );
        await identity.drain();
        await older.drain();

        game.startView(start);
        game.publishFrame(frameOf(0));
        await identity.drain();
        await older.drain();

        final shown = identity.fromHost.whereType<FrameMessage>().single;
        expect(shown.characters, {'phone-1': crown, 'phone-2': bow});
        final plain = older.fromHost.whereType<FrameMessage>().single;
        expect(plain.characters, isEmpty);
        expect(plain.toPayload(), frameOf(0).toPayload(), reason: 'a phone one build older gets today\'s frame');

        // A phone that pairs mid-round gets the latest frame, with the
        // characters of the phones it takes them from.
        final late = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-3',
          name: 'Ava',
          capabilities: identityView,
          code: server.pairingCode,
        );
        await late.drain();
        final latest = late.fromHost.whereType<FrameMessage>().single;
        expect(latest.n, 0);
        expect(latest.characters, {'phone-1': crown, 'phone-2': bow});
      });

      test('a phone without the identity capability is told nothing new', () async {
        final server = await startHost(t, capabilities: identityView);
        final game = startGame(server);
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-2',
          name: 'Dad',
          capabilities: viewOnly,
          character: bow,
          code: server.pairingCode,
        );
        await older.drain();

        game.startView(start);
        game.publishFrame(frameOf(0));
        await older.drain();

        // The pairing and the frame it has always had, and nothing else: no
        // players message, no chars.
        expect(older.fromHost.whereType<PlayerMessage>().single.character, bow);
        expect(playersTo(older), isEmpty);
        expect(older.fromHost.whereType<FrameMessage>().single.characters, isEmpty);
        expect(server.send('phone-2', HapticEventMessage(event: HapticEvent.hit)), isTrue);
      });
    });
  }
}
