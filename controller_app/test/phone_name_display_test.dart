import 'package:controller/src/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

/// The name the phone sends when its player left the nickname blank: built
/// the way the real hello path builds it, so the test follows that code.
final phoneOwn = phoneName(controllerId: 'ab12cd34');

/// A player whose name is the phone's own name, as a host one build older
/// still sends it (its `players` rows, and its result standings).
const phoneNamed = (
  id: 'phone-2',
  number: 2,
  name: 'Phone AB12',
  character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
);

/// Mia, who typed her own nickname.
const mia = (
  id: 'phone-1',
  number: 1,
  name: 'Mia',
  character: PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
);

final lobbyList = find.byKey(const Key('lobbyPlayers'));

/// The app paired to a TV, in the menu look or (with [tv]) the TV look, which
/// needs a tablet's room (as identity_phone_test does).
Future<TestApp> pumpFor(WidgetTester tester, {required bool tv}) => pumpApp(
  tester,
  paired: true,
  screen: tv ? const Size(1180, 820) : const Size(852, 393),
  extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
);

void main() {
  test('the hello name for a blank nickname is the phone-style name', () {
    expect(phoneOwn, 'Phone AB12');
  });

  for (final tv in [false, true]) {
    final look = tv ? 'the TV look' : 'the menu look';
    group(look, () {
      testWidgets('the lobby list shows "Player N" for a phone-style name, never the phone name', (tester) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 1, players: [mia, phoneNamed]));
        await settle(tester);

        expect(lobbyList, findsOneWidget);
        expect(find.text('Player 2'), findsOneWidget, reason: 'the phone-style name reads as a blank one');
        expect(find.text('Phone AB12'), findsNothing);
        expect(find.text('Mia'), findsOneWidget, reason: 'a real nickname still shows as typed');
        expect(tester.takeException(), isNull);
      });

      testWidgets('the result card shows "Player N" for a phone-style standing name, and a real nickname as typed', (
        tester,
      ) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 1));
        await settle(tester);
        app.client.viewEnd(
          const ViewEndMessage(
            reason: ViewEndReason.finished,
            result: ViewResult(
              outcome: ViewOutcome.win,
              timeS: 58,
              points: 12,
              standings: [
                ViewStanding(
                  number: 2,
                  name: 'Phone AB12',
                  points: 12,
                  character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
                ),
                ViewStanding(
                  number: 3,
                  name: 'Mia',
                  points: 9,
                  character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna),
                ),
              ],
            ),
          ),
        );
        await settle(tester);

        expect(find.text('Player 2'), findsOneWidget, reason: 'an older host sends the phone name');
        expect(find.text('Phone AB12'), findsNothing);
        expect(find.text('Mia'), findsOneWidget);
        final badge = tester.widgetList<party.ToyBadge>(
          find.descendant(of: find.byKey(const Key('standing-2')), matching: find.byType(party.ToyBadge)),
        );
        expect(badge.single.number, 2);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
