import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

/// Al, whose short name leaves the row narrow.
const al = (
  id: 'phone-1',
  number: 1,
  name: 'Al',
  character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
);

/// Mia, a middling name between the other two.
const mia = (
  id: 'phone-2',
  number: 2,
  name: 'Mia',
  character: PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
);

/// A long nickname, the widest row in the lobby.
const longName = (
  id: 'phone-3',
  number: 3,
  name: 'A very long nickname',
  character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.ears),
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

/// The left edge of the badge in lobby row [number].
double badgeLeft(WidgetTester tester, int number) => tester
    .getTopLeft(find.descendant(of: find.byKey(Key('lobby-$number')), matching: find.byType(party.PlayerBadge)))
    .dx;

/// The width of the screen the app is drawn on, in logical px.
double screenWidth(WidgetTester tester) => tester.view.physicalSize.width / tester.view.devicePixelRatio;

void main() {
  for (final tv in [false, true]) {
    final look = tv ? 'the TV look' : 'the menu look';
    group(look, () {
      testWidgets('every row\'s badge shares one left edge when the names differ in length', (tester) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 1, players: [al, mia, longName]));
        await settle(tester);

        expect(lobbyList, findsOneWidget);
        final lefts = [
          for (final number in [1, 2, 3]) badgeLeft(tester, number),
        ];
        expect(lefts, everyElement(closeTo(lefts.first, 0.5)), reason: 'left edges, row by row: $lefts');
        expect(tester.takeException(), isNull);
      });

      testWidgets('the lobby block is centred on the screen when the names differ in length', (tester) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 1, players: [al, mia, longName]));
        await settle(tester);

        final centre = tester.getCenter(lobbyList).dx;
        expect(centre, closeTo(screenWidth(tester) / 2, 1), reason: 'block centre x, screen half-width');
      });

      testWidgets('a single player\'s row is centred on the screen', (tester) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 1, players: [al]));
        await settle(tester);

        expect(lobbyList, findsOneWidget);
        final centre = tester.getCenter(lobbyList).dx;
        expect(centre, closeTo(screenWidth(tester) / 2, 1), reason: 'block centre x, screen half-width');
        expect(tester.takeException(), isNull);
      });
    });
  }
}
