import 'package:controller/src/profile.dart';
import 'package:controller/src/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show RoboBadge, ToyBadge;
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The crown on the teal body: a character no default gives.
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

void main() {
  group('the phone\'s profile (M14 N13, design section 9)', () {
    test('a saved nickname and character ride in the hello; without them the hello says "Phone 1A2B"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fresh = loadIdentity(prefs).toHello();
      expect(fresh.name, matches(RegExp(r'^Phone [0-9A-F]{4}$')), reason: 'ten characters, as the host keeps');
      expect(fresh.name.length, 10);
      expect(fresh.character, ControllerProfile.initial);

      ControllerProfile(nickname: 'Mia', character: tealCrown).save(prefs);
      final saved = loadIdentity(prefs).toHello();
      expect(saved.name, 'Mia');
      expect(saved.character, tealCrown);
    });

    test('the nickname keeps letters, numbers and spaces only, and ten characters', () {
      expect(nicknameOfText('Mia'), 'Mia');
      expect(nicknameOfText('Mia Maria Mia Mia'), 'Mia Maria');
      expect(nicknameOfText('  Mia  '), 'Mia');
      expect(nicknameOfText('M1a!?'), 'M1a');
      expect(nicknameOfText('  '), isNull);
    });

    testWidgets('the settings save the nickname and the character, and the next hello says them', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openSettings(tester);

      await tester.enterText(find.byKey(const Key('settingsNickname')), 'Mia');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('nicknameCount'))).data, '3 / 10');
      expect(app.prefs.getString('profileNickname'), 'Mia');
      expect(app.client.identity.name, 'Mia', reason: 'the next hello carries it, without a reconnect');

      await tapVisible(tester, find.byKey(const Key('settingsColour-4')));
      await tapVisible(tester, find.byKey(const Key('settingsAccessory-crown')));
      await settle(tester);
      expect(app.prefs.getString('profileCharacter'), contains('"c":4'));
      expect(app.client.identity.character, tealCrown);
      expect(app.client.identity.toHello().character, tealCrown);
    });

    testWidgets('a phone whose colour was taken says so in a line, and the line goes when it is given its own', (
      tester,
    ) async {
      // No saved character, so the phone asked for player 1's blue.
      final app = await pumpApp(tester, paired: true);
      app.client.emit(
        connected.copyWith(
          player: 2,
          character: const PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('takenNotice')), findsOneWidget);
      expect(find.text('Blue is taken tonight, you\'re Teal'), findsOneWidget);

      app.client.emit(
        connected.copyWith(player: 2, character: const PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears)),
      );
      await settle(tester);
      expect(find.byKey(const Key('takenNotice')), findsNothing);
    });
  });

  group('the results card (M14 design section 9, mock-up 12)', () {
    const result = ViewResult(
      outcome: ViewOutcome.win,
      timeS: 58,
      points: 12,
      round: 1,
      of: 3,
      place: 1,
      standings: [
        ViewStanding(
          number: 1,
          name: 'Mia',
          points: 12,
          character: PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown),
        ),
        ViewStanding(
          number: 2,
          name: 'Dad',
          points: 9,
          character: PlayerCharacter(colourSlot: 2, accessory: PlayerAccessory.antenna),
        ),
      ],
    );

    testWidgets('a result end keeps the last frame drawn and shows the card over it', (tester) async {
      final app = await joined(tester);
      app.client.emit(connected.copyWith(player: 1, character: tealCrown));
      await settle(tester);
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished, result: result));
      await settle(tester);

      expect(find.text('You win!'), findsOneWidget);
      expect(find.byKey(const Key('resultDetail')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('resultDetail'))).data, '0:58');
      expect(tester.widget<Text>(find.byKey(const Key('resultPoints'))).data, '+12 points');
      expect(tester.widget<Text>(find.byKey(const Key('resultName'))).data, 'Mia');
      expect(find.byKey(const Key('standing-1')), findsOneWidget);
      expect(find.byKey(const Key('standing-2')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('standingPoints-2'))).data, '9');
      expect(find.text('Waiting for the host to pick what\'s next.'), findsOneWidget);
      expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'the last frame stays under the card');

      // The host left the results: a bare end clears the frame and the card.
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
      await settle(tester);
      expect(find.byKey(const Key('resultDetail')), findsNothing);
      expect(find.byKey(const Key('arena')), findsNothing);
    });

    testWidgets('Robo\'s row in the standings is named, with the robot disc and no player badge', (tester) async {
      final app = await joined(tester);
      app.client.emit(connected.copyWith(player: 1, character: tealCrown));
      await settle(tester);
      app.client.viewEnd(
        const ViewEndMessage(
          reason: ViewEndReason.finished,
          result: ViewResult(
            outcome: ViewOutcome.loss,
            standings: [
              ViewStanding(number: 3, name: 'Robo', points: 11, character: tealCrown, isRobo: true),
              ViewStanding(number: 1, name: 'Mia', points: 2, character: tealCrown),
            ],
          ),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('standing-3')), findsOneWidget);
      expect(find.text('Robo'), findsOneWidget, reason: 'Robo is shown by its name');
      expect(tester.widget<Text>(find.byKey(const Key('standingPoints-3'))).data, '11');
      expect(find.byType(RoboBadge), findsOneWidget, reason: 'the robot disc, as the TV draws it');

      expect(
        find.descendant(of: find.byKey(const Key('standing-3')), matching: find.byType(ToyBadge)),
        findsNothing,
        reason: 'Robo wears no player number badge',
      );
      expect(find.byKey(const Key('standing-1')), findsOneWidget, reason: 'a player\'s row keeps its badge');
    });

    testWidgets('a new view clears the card, and a phone sent no result keeps its pad', (tester) async {
      final app = await joined(tester);
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished, result: result));
      await settle(tester);
      expect(find.text('You win!'), findsOneWidget);

      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(find.byKey(const Key('resultDetail')), findsNothing);
      expect(find.byKey(const Key('arena')), findsNothing, reason: 'nothing is drawn before the first frame');

      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
      await settle(tester);
      expect(find.byKey(const Key('resultDetail')), findsNothing);
      expect(find.byKey(const Key('faceButtons')), findsOneWidget, reason: 'back to the pad, as in M12');
    });
  });
}
