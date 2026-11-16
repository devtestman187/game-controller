import 'package:controller/src/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The character a first-time phone asks for in its hello (design section 9):
/// player 1's blue.
const blueEars = ControllerProfile.initial;

/// The crown on the teal body: a character no default gives.
const tealCrown = PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown);

void main() {
  // B-028: the band names the colour the host answered against the one the
  // last hello asked for, not against the saved profile, and it goes on its
  // own after a few seconds or when the round moves on.
  group('the colour the host gave against the one the hello asked for (B-028)', () {
    testWidgets('changing the colour in Settings while joined shows no band', (tester) async {
      final app = await pumpApp(tester, paired: true);
      // The host gave the blue this phone asked for.
      app.client.emit(connected.copyWith(player: 1, askedCharacter: blueEars, character: blueEars));
      await settle(tester);
      expect(find.byKey(const Key('takenNotice')), findsNothing);

      await openSettings(tester);
      await tapVisible(tester, find.byKey(const Key('settingsColour-4')));
      await tapVisible(tester, find.byKey(const Key('settingsAccessory-crown')));
      await settle(tester);
      await closeSettings(tester);

      // The profile moved to teal; the host still answered the blue hello.
      expect(app.prefs.getString('profileCharacter'), contains('"c":4'));
      expect(app.client.identity.character, tealCrown);
      expect(find.byKey(const Key('takenNotice')), findsNothing);
    });

    testWidgets('a hello that asked blue and was given teal says so, and still says blue after a change', (
      tester,
    ) async {
      final app = await pumpApp(tester, paired: true);
      // The last hello asked for blue; the host answered teal.
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);

      expect(find.byKey(const Key('takenNotice')), findsOneWidget);
      expect(find.text('Blue is taken tonight, you\'re Teal'), findsOneWidget);

      // The player picks teal for the next join: the answer to the blue hello
      // stands, so the line still names blue (B-028).
      await openSettings(tester);
      await tapVisible(tester, find.byKey(const Key('settingsColour-4')));
      await tapVisible(tester, find.byKey(const Key('settingsAccessory-crown')));
      await settle(tester);
      await closeSettings(tester);

      expect(find.byKey(const Key('takenNotice')), findsOneWidget);
      expect(find.text('Blue is taken tonight, you\'re Teal'), findsOneWidget);

      // The band's own seconds end it.
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('takenNotice')), findsNothing);
    });

    testWidgets('the band goes after five seconds on its own', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(find.byKey(const Key('takenNotice')), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('takenNotice')), findsOneWidget, reason: 'the five seconds are not over yet');

      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('takenNotice')), findsNothing);
    });

    testWidgets('the band goes as the round starts', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(find.byKey(const Key('takenNotice')), findsOneWidget);

      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(find.byKey(const Key('takenNotice')), findsNothing);
    });
  });
}
