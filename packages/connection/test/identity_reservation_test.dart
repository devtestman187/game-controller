import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// The pick the contested tests ask for (M14 L7): slot 4's teal crown.
const contested = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('the first-joined keeps a contested colour and accessory, the later player the nearest free', () async {
        final host = await startHost(t);
        final first = await join(host, t, 'phone-1', wanted: contested);
        final second = await join(host, t, 'phone-2', wanted: contested);

        expect(first, contested);
        // Slot 4 and the crown are taken: the next slot and accessory up are free.
        expect(second, const PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.tuft));
      });

      test('a later player gets the nearest free, and a tie goes to the later slot', () async {
        final host = await startHost(t);
        await join(host, t, 'phone-1', wanted: const PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.bow));
        await join(host, t, 'phone-2', wanted: const PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.tuft));
        await join(host, t, 'phone-3', wanted: const PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.cap));
        final later = await join(
          host,
          t,
          'phone-4',
          wanted: const PlayerCharacter(colourSlot: 3, accessory: PlayerAccessory.cap),
        );

        // Slot 3 and the cap are taken, and so are both neighbours (2, 4, and
        // the bow, tuft), so the tie goes up: slot 5 and the crown.
        expect(later, const PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown));
      });

      test('a seventh player still gets a character, as none is free', () async {
        final host = await startHost(t);
        final characters = <PlayerCharacter>[];
        for (var number = 1; number <= 7; number++) {
          characters.add(await join(host, t, 'phone-$number'));
        }

        final firstSix = characters.take(6).toSet();
        expect(firstSix, hasLength(6), reason: 'the six defaults are all different');
        // Every colour and accessory is taken, so player 7 keeps its own
        // default: player 1's.
        expect(characters.last, const PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears));
      });

      test('a phone that sends no character gets its number\'s default', () async {
        final host = await startHost(t);
        final first = await join(host, t, 'phone-1');
        final second = await join(host, t, 'phone-2');

        expect(first, const PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears));
        expect(second, const PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna));
      });

      test('a dropped player\'s pick and number wait the same reserve minute', () async {
        final host = await startHost(t);
        final dropped = controller(t, id: 'phone-1', character: contested);
        dropped.connect(addressOf(host, t), code: host.pairingCode);
        final first = await paired(dropped);
        expect(first.player, 1);
        expect(first.character, contested);

        // While the first player is here, the contested pick goes to nobody else.
        final here = controller(t, id: 'phone-2', character: contested);
        here.connect(addressOf(host, t), code: host.pairingCode);
        final second = await paired(here);
        expect(second.player, 2);
        expect(second.character, isNot(contested));

        dropped.disconnect();
        await hostUntil(host, (s) => s.connected.every((c) => c.controllerId != 'phone-1'));

        // The number 1 is held for the reserve minute, so the next phone gets
        // 3; its pick is held too, so it gets a free one (identity_reserve_minute_test.dart
        // frees it once the minute is up).
        final next = controller(t, id: 'phone-3', character: contested);
        next.connect(addressOf(host, t), code: host.pairingCode);
        final third = await paired(next);
        expect(third.player, 3);
        expect(third.character, isNot(contested));
      });

      test('a returning player keeps its number and its pick within the reserve minute', () async {
        final host = await startHost(t);
        final returning = controller(t, id: 'phone-1', character: contested);
        returning.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(returning)).player, 1);

        returning.disconnect();
        await hostUntil(host, (s) => s.connected.every((c) => c.controllerId != 'phone-1'));

        // Number 1 stays reserved for a minute, so two new phones take 2 and 3.
        final next = controller(t, id: 'phone-2');
        next.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(next)).player, 2);
        final later = controller(t, id: 'phone-3');
        later.connect(addressOf(host, t), code: host.pairingCode);
        expect((await paired(later)).player, 3);

        // Back with its saved token: its own number, and the pick it asked for.
        returning.connect(addressOf(host, t));
        final back = await clientUntil(returning, (s) => s.status == ClientStatus.connected && s.player != null);
        expect(back.player, 1);
        expect(back.character, contested);
      });
    });
  }
}

/// Pairs a hand-made phone as [controllerId], asking for [wanted] (null sends
/// none, as a phone one build older does), and answers the character the host
/// gave it.
Future<PlayerCharacter> join(
  HostServer host,
  TestTransport transport,
  String controllerId, {
  PlayerCharacter? wanted,
}) async {
  final phone = await WirePhone.open(
    host,
    transport,
    controllerId: controllerId,
    character: wanted,
    code: host.pairingCode,
  );
  await phone.drain();
  final character = phone.fromHost.whereType<PlayerMessage>().single.character;
  if (character == null) throw StateError('the host sent $controllerId no character');
  return character;
}

/// A phone whose identity carries [character] (none when null), as a player
/// picks it in Settings (M14 L7).
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
