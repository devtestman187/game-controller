import 'package:connection/connection.dart';
import 'package:controller/src/controls_settings.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The card over a game while the phone waits for its host (m12-joined-view
/// §0.3): the host is away, or the link to it dropped. The game behind it and
/// the bar are `joined_view_test.dart`'s.
void main() {
  group('waiting for the host (m12-joined-view §0.3)', () {
    testWidgets('an away host counts its round down once a second, and coming back hides the card', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      expect(find.text('Waiting for the host to come back'), findsOneWidget);
      expect(find.text('The game goes on if they\'re back in 30 s'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Leave game'), findsOneWidget, reason: 'the countdown still runs');

      // 5 s pass on the phone's clock, and the card ticks once.
      app.client.nowMs += 5000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The game goes on if they\'re back in 25 s'), findsOneWidget);

      app.client.hostBack();
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });

    testWidgets('a countdown that runs out says the host has left, with a filled Leave game', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(2);
      await settle(tester);
      // 3 s on: the 2 s countdown is out.
      app.client.nowMs += 3000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The host has left'), findsOneWidget);
      expect(find.text('You can keep waiting, or leave.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Leave game'), findsOneWidget);
    });

    testWidgets('a dropped link says it is reconnecting over the last frame, then the host has left', (tester) async {
      final app = await joined(tester);
      // The drop is noticed at 1000 ms on this phone's clock.
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      expect(find.text('Reconnecting to the game…'), findsOneWidget);
      expect(find.text('Waiting for the host to come back'), findsNothing, reason: 'this phone was the one away');
      expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'the last frame stays under the card');

      // 5 s in: no countdown to show, the card says the same.
      app.client.nowMs += 5000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Reconnecting to the game…'), findsOneWidget);
      expect(find.textContaining('The game goes on'), findsNothing);

      // The grace is 30 s from the drop: 29 s in it still reconnects…
      app.client.nowMs += 24000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Reconnecting to the game…'), findsOneWidget);

      // …and at 30 s the host has left.
      app.client.nowMs += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The host has left'), findsOneWidget);
      expect(find.text('You can keep waiting, or leave.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Leave game'), findsOneWidget);
    });

    testWidgets('a link that comes back without a view_start leaves the finished round off the screen', (tester) async {
      final app = await joined(tester);
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'the last frame, under the card');

      // The host is back and no round runs, so it starts no view: the round
      // ended while the phone was away (1107d Q3). The pairing's answer comes
      // before anything the host sends after it, so the phone hears the link
      // first and the start, if any, second.
      app.client.emit(connected);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.byKey(const Key('arena')), findsNothing, reason: 'a round that ended must not stay on screen');
      expect(find.byKey(const Key('connectionChip')), findsOneWidget, reason: 'the full bar is back');
    });

    testWidgets('a link that comes back with a view_start keeps the round on screen', (tester) async {
      final app = await joined(tester);
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      app.client.emit(connected);
      await settle(tester);

      // A round that still runs: the host sends the start and its latest frame
      // again (server_game_host.dart:288-307). The view comes back on screen
      // with its ticker, and the first tick draws that frame.
      app.client.viewStart(arenaStart());
      await settle(tester);
      app.client.viewFrame(arenaFrame(1));
      await settle(tester);
      expect(find.byKey(const Key('arena')), findsOneWidget);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.byKey(const Key('connectionChip')), findsNothing, reason: 'the compact bar is back');
      expect(find.byKey(const Key('connectionButton')), findsOneWidget);
    });

    testWidgets('a host that comes back after the grace takes the card away', (tester) async {
      final app = await joined(tester);
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      app.client.nowMs += 30000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The host has left'), findsOneWidget);

      app.client.emit(connected);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });

    testWidgets('an idle client ends the view and the wait: Stop and Leave game both work over a game', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);

      app.client.emit(const ClientSnapshot(status: ClientStatus.idle));
      await settle(tester);

      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.byKey(const Key('arena')), findsNothing);
      expect(find.byKey(const Key('connectionChip')), findsOneWidget, reason: 'the full bar is back');
      expect(layerOpacity(tester), ControlsSettings.maxOpacity);
    });

    testWidgets('Leave game disconnects, forgets the last host and opens the Connect screen', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      await tester.tap(find.byKey(const Key('leaveGame')));
      await settle(tester);

      expect(app.client.calls, contains('disconnect'));
      expect(
        app.prefs.getString('lastHost'),
        isNull,
        reason: 'a phone that left is not reconnected to at the next start',
      );
      expect(find.byType(ConnectScreen), findsOneWidget);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.byKey(const Key('arena')), findsNothing);
    });

    testWidgets('a phone with no game shown says nothing when its link drops', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.text('Waiting for the host to come back'), findsNothing);
    });

    testWidgets('a new view clears the wait', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);

      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });
  });
}
