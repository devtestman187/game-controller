import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// The awards reveal's one award, won by the first phone (M16 bugs4 nh1).
const nightAward = NightAwardRow(id: 'fast', name: 'Fastest', points: 3, winners: ['phone-1']);

/// The first phone's final standing, with its award points in the total (M16 bugs4 nh1).
const nightStanding = ViewStanding(
  id: 'phone-1',
  number: 1,
  name: 'Mia',
  points: 15,
  character: PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
);

/// The view a round shows (m12); the night's end comes after it.
const nightStart = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: {}, hz: 60);

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a night end reaches only the phones that list the night capability, with the same awards', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final listing = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: const [Capability.night, Capability.view],
          code: server.pairingCode,
        );
        final older = await WirePhone.open(server, t, controllerId: 'phone-2', code: server.pairingCode);
        host.startView(nightStart);
        host.endView(const ViewEndMessage(reason: ViewEndReason.finished));

        const message = NightEndMessage(awards: [nightAward], standings: [nightStanding]);
        host.showNightEnd(message);
        await listing.drain();
        await older.drain();

        final received = listing.fromHost.whereType<NightEndMessage>().toList();
        expect(received, hasLength(1));
        expect(received.single.awards.single.winners, ['phone-1']);
        expect(received.single.awards.single.points, 3);
        expect(received.single.standings.single.points, 15);
        expect(received.single, equals(message));
        expect(older.fromHost.whereType<NightEndMessage>(), isEmpty);
      });

      test('a night end is sent with no view running, once per call', () async {
        final server = await startHost(t);
        final host = ServerGameHost(server);
        addTearDown(host.dispose);
        final listing = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          capabilities: const [Capability.night],
          code: server.pairingCode,
        );

        host.showNightEnd(const NightEndMessage(awards: [], standings: [nightStanding]));
        await listing.drain();

        expect(host.hasViewers, isFalse);
        expect(listing.fromHost.whereType<NightEndMessage>(), hasLength(1));
      });
    });
  }
}
