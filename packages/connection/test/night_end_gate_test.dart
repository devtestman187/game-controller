import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'wire_phone.dart';

/// What a phone one build newer lists: it shows the game and the night's end.
const nightView = [Capability.view, Capability.night];

/// A phone one build older: it shows the game and knows no night.
const viewOnly = [Capability.view];

/// The view a round shows, sent to every phone that lists the view.
const start = ViewStartMessage(game: 'shape_race', snapshotVersion: 1, setup: {}, hz: 60);

/// The night's end: one award and one standing.
const nightEnd = NightEndMessage(
  awards: [
    NightAwardRow(id: 'c1', name: 'Mia', points: 3, winners: ['c1']),
  ],
  standings: [
    ViewStanding(
      id: 'c1',
      number: 1,
      name: 'Mia',
      points: 3,
      character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
    ),
  ],
);

void main() {
  for (final t in TestTransport.values) {
    group(t.name, () {
      test('a night_end reaches a phone that lists night and never reaches one that does not', () async {
        final server = await startHost(t, capabilities: nightView);
        final newer = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-1',
          name: 'Mia',
          capabilities: nightView,
          code: server.pairingCode,
        );
        final older = await WirePhone.open(
          server,
          t,
          controllerId: 'phone-9',
          name: 'Ava',
          capabilities: viewOnly,
          code: server.pairingCode,
        );
        await newer.drain();
        await older.drain();

        expect(server.sendToAll(start), 2, reason: 'both phones list the view');
        expect(server.sendToAll(nightEnd), 1, reason: 'only the phone that lists night is sent it');
        await newer.drain();
        await older.drain();

        expect(newer.fromHost.whereType<NightEndMessage>().single, nightEnd);
        expect(older.fromHost.whereType<NightEndMessage>(), isEmpty);
        expect(older.fromHost.whereType<ViewStartMessage>().single, start);
        expect(newer.fromHost.whereType<ViewStartMessage>().single, start);
      });
    });
  }
}
