import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// Two players' choices: both want the same teal crown (M14 L7).
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// The view a round shows (m12).
final start = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: const {}, hz: 60);

FrameMessage frame(int n) => FrameMessage(n: n, atMs: n * 16, snapshot: const {});

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a phone keeps its choice, and one asking for a taken character gets the nearest free one', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final first = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          character: tealCrown,
          code: server.pairingCode,
        );
        final second = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-2',
          name: 'Dad',
          character: tealCrown,
          code: server.pairingCode,
        );
        await first.drain();
        await second.drain();

        // The player messages say what the host gave each phone.
        final firstMessage = first.fromHost.whereType<PlayerMessage>().single;
        final secondMessage = second.fromHost.whereType<PlayerMessage>().single;
        expect(firstMessage.character, tealCrown);
        expect(secondMessage.character, isNot(tealCrown));
        expect(secondMessage.character!.colourSlot, 5);
        expect(secondMessage.character!.accessory, PlayerAccessory.tuft);

        // And the roster the game reads carries the same characters.
        final players = host.players;
        expect(players.map((p) => p.nickname), containsAll(['Mia', 'Dad']));
        expect(players.firstWhere((p) => p.id == 'phone-2').character, secondMessage.character);
      });

      test('the host cuts a nickname to 10 characters, and a blank one falls back to P1', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final long = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: '  Mia Maria Mia  ',
          code: server.pairingCode,
        );
        final blank = await WirePhone.open(server, t, controllerId: 'phone-2', name: '   ', code: server.pairingCode);
        await long.drain();
        await blank.drain();

        final players = host.players;
        expect(players.firstWhere((p) => p.id == 'phone-1').nickname, 'Mia Maria');
        final fallback = players.firstWhere((p) => p.id == 'phone-2');
        expect(fallback.nickname, isNull);
        expect(fallback.label, 'P2');
      });

      test('a round\'s end shows each viewer its own result, and the view stays open', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final viewer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: const [Capability.view],
          code: server.pairingCode,
        );
        final other = await WirePhone.open(server, t, controllerId: 'phone-2', code: server.pairingCode);
        host.startView(start);
        host.publishFrame(frame(0));

        const result = ViewResult(outcome: ViewOutcome.done, timeS: 58.4, points: 12);
        host.showResults({'phone-1': result});
        await viewer.drain();
        await other.drain();

        final end = viewer.fromHost.whereType<ViewEndMessage>().single;
        expect(end.result, isNotNull);
        expect(end.result!.outcome, ViewOutcome.done);
        expect(end.result!.timeS, 58.4);
        expect(other.fromHost.whereType<ViewEndMessage>(), isEmpty);

        // The round's view is still on: a frame after the card is drawn too.
        host.publishFrame(frame(1));
        await viewer.drain();
        expect(viewer.fromHost.whereType<FrameMessage>().map((f) => f.n), [0, 1]);
      });
    });
  }
}
