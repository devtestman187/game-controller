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

/// The tuft on the pink body (colour slot 5): the nearest free character a
/// host gives a second teal crown (packages/connection/test/m14_test.dart).
const pinkTuft = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.tuft);

final takenNotice = find.byKey(const Key('takenNotice'));

void main() {
  // B-028 review finding 1: every heartbeat brings a new snapshot
  // (client_messages.dart:123, no `==`) with the same answer, and the hide
  // cleared the state the guard compared with, so the band came back a second
  // after it hid, and again after every round start or end.
  group('the band stays gone after it hides (B-028)', () {
    testWidgets('the same answer after the five seconds does not show the band again', (tester) async {
      final app = await pumpApp(tester, paired: true);
      // The last hello asked for blue; the host answered teal.
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsOneWidget);

      // The band's own five seconds (B-028).
      await tester.pump(const Duration(seconds: 5));
      expect(takenNotice, findsNothing);

      // The next heartbeat: the same answer in a new snapshot.
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsNothing, reason: 'the same answer was already said');
    });

    testWidgets('the same answer after the round starts does not show the band again', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsOneWidget);

      // The round moves on, which ends the band.
      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(takenNotice, findsNothing);

      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsNothing, reason: 'the same answer was already said');
    });

    testWidgets('a new answer after the band hides shows it again', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(takenNotice, findsNothing);

      // The player picks teal and joins again; the host gave pink instead.
      app.client.emit(connected.copyWith(player: 2, askedCharacter: tealCrown, character: pinkTuft));
      await settle(tester);
      expect(takenNotice, findsOneWidget);
    });

    testWidgets('an answer that is no longer taken lets the same one be said again', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsOneWidget);

      // A hello that got the colour it asked for clears what was said before.
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: blueEars));
      await settle(tester);
      expect(takenNotice, findsNothing);

      // The pair is new again, so it is said again.
      app.client.emit(connected.copyWith(player: 2, askedCharacter: blueEars, character: tealCrown));
      await settle(tester);
      expect(takenNotice, findsOneWidget);
    });
  });
}
