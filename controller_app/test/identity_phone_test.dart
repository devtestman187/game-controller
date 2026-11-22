import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The character the host gives this phone's player (M16 identity): the teal
/// crown, which no player number's default gives.
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

/// Mia, in the teal crown, as the host's players message names her.
const mia = (id: 'phone-1', number: 1, name: 'Mia', character: tealCrown);

/// Dad, who joined without a nickname, in the blue ears: the list says
/// "Player 2" for him (owner decision, Nov 21).
const dad = (
  id: 'phone-2',
  number: 2,
  name: '',
  character: PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
);

final lobbyList = find.byKey(const Key('lobbyPlayers'));

void main() {
  for (final tv in [false, true]) {
    final look = tv ? 'the TV look' : 'the menu look';
    group(look, () {
      testWidgets('the controls\' badge wears the character the host gave this player', (tester) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 2, character: tealCrown));
        await settle(tester);

        final badge = tester.widget<party.ToyBadge>(
          find.descendant(of: find.byKey(const Key('playerBadge')), matching: find.byType(party.ToyBadge)),
        );
        expect(badge.number, 2);
        expect(badge.character, const party.ToyCharacter(colourSlot: 4, accessory: party.ToyAccessory.crown));
      });

      testWidgets('the lobby list shows every player with their character, and "Player N" for a blank name', (
        tester,
      ) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 2, character: tealCrown, players: const [mia, dad]));
        await settle(tester);

        expect(lobbyList, findsOneWidget);
        expect(find.text('Mia'), findsOneWidget);
        expect(find.text('Player 2'), findsOneWidget, reason: 'Dad has no nickname');
        final badges = tester
            .widgetList<party.PlayerBadge>(find.descendant(of: lobbyList, matching: find.byType(party.PlayerBadge)))
            .toList();
        expect(badges.map((b) => (b.number, b.character)), [(1, tealCrown), (2, dad.character)]);
        // Nothing overflows at either look's type size.
        expect(tester.takeException(), isNull);
      });

      testWidgets('the lobby list is gone while a game shows', (tester) async {
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 2, character: tealCrown, players: const [mia, dad]));
        await settle(tester);
        expect(lobbyList, findsOneWidget);

        app.client.nowMs = 1000;
        app.client.viewStart(arenaStart());
        app.client.viewFrame(arenaFrame(0));
        await settle(tester);

        expect(lobbyList, findsNothing, reason: 'the game takes the screen');
      });

      testWidgets('the result card shows everyone\'s character, and "Player N" for a blank name', (tester) async {
        // This phone's player is 1, which the host left out of the standings,
        // so each name below is a row's own.
        final app = await pumpFor(tester, tv: tv);
        app.client.emit(connected.copyWith(player: 1, character: tealCrown));
        await settle(tester);
        app.client.viewEnd(
          const ViewEndMessage(
            reason: ViewEndReason.finished,
            result: ViewResult(
              outcome: ViewOutcome.win,
              timeS: 58,
              points: 12,
              standings: [
                ViewStanding(number: 2, name: '', points: 12, character: tealCrown),
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

        expect(find.text('Mia'), findsOneWidget);
        expect(find.text('Player 2'), findsOneWidget, reason: 'the host left this player\'s name blank');
        final rows = tester
            .widgetList<party.ToyBadge>(
              find.descendant(of: find.byKey(const Key('standing-2')), matching: find.byType(party.ToyBadge)),
            )
            .single;
        expect(rows.character, const party.ToyCharacter(colourSlot: 4, accessory: party.ToyAccessory.crown));
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('a host one build older (no players message, no characters)', () {
    testWidgets('shows the number defaults and nothing breaks', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2));
      await settle(tester);

      final badge = tester.widget<party.ToyBadge>(
        find.descendant(of: find.byKey(const Key('playerBadge')), matching: find.byType(party.ToyBadge)),
      );
      expect(badge.character, party.ToyCharacter.forPlayer(2), reason: 'the default for player 2');
      expect(lobbyList, findsNothing, reason: 'it never says who is here');

      // Its standings still name players the old way, which the card shows as
      // it came.
      app.client.viewEnd(
        const ViewEndMessage(
          reason: ViewEndReason.finished,
          result: ViewResult(
            outcome: ViewOutcome.win,
            standings: [
              ViewStanding(
                number: 3,
                name: 'P3',
                points: 9,
                character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna),
              ),
            ],
          ),
        ),
      );
      await settle(tester);
      expect(find.text('P3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The app paired to a TV, in the menu look or (with [tv]) the TV look, which
/// needs a tablet's room.
Future<TestApp> pumpFor(WidgetTester tester, {required bool tv}) => pumpApp(
  tester,
  paired: true,
  screen: tv ? const Size(1180, 820) : const Size(852, 393),
  extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
);
