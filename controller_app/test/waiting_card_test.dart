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

  group('a player away (m12 bug 1107d)', () {
    testWidgets('it says which player is away and counts down, and the card goes when they are back', (tester) async {
      final app = await joined(tester);
      app.client.playerAway('p2', 2, 12);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);
      expect(find.text('Player 2 is away'), findsOneWidget);
      expect(find.text('The game goes on if they\'re back in 12 s'), findsOneWidget);
      expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'the last frame stays under the card');
      expect(find.widgetWithText(TextButton, 'Leave game'), findsOneWidget, reason: 'Leave game as it was');

      // 5 s pass on the phone's clock, and the card ticks once.
      app.client.nowMs += 5000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The game goes on if they\'re back in 7 s'), findsOneWidget);

      app.client.playerBack('p2');
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.byKey(const Key('arena')), findsOneWidget);
    });

    testWidgets('a countdown that runs out says the game goes on without them, until the next frame', (tester) async {
      final app = await joined(tester);
      app.client.playerAway('p2', 2, 2);
      await settle(tester);
      expect(find.text('The game goes on if they\'re back in 2 s'), findsOneWidget);

      // 3 s on: the countdown is out, and no frame has come.
      app.client.nowMs += 3000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The game goes on without them…'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Leave game'), findsOneWidget, reason: 'the host has not left');
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);

      // The game went on: the next frame takes the line away.
      app.client.viewFrame(arenaFrame(1));
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });

    testWidgets('two away at once get a line each, and one that is back leaves one', (tester) async {
      final app = await joined(tester);
      app.client.playerAway('p2', 2, 12);
      app.client.playerAway('p3', 3, 20);
      await settle(tester);
      expect(find.text('Player 2 is away'), findsOneWidget);
      expect(find.text('Player 3 is away'), findsOneWidget);
      expect(find.text('The game goes on if they\'re back in 12 s'), findsOneWidget);
      expect(find.text('The game goes on if they\'re back in 20 s'), findsOneWidget);

      app.client.playerBack('p2');
      await settle(tester);
      expect(find.text('Player 2 is away'), findsNothing);
      expect(find.text('The game goes on if they\'re back in 12 s'), findsNothing);
      expect(find.text('Player 3 is away'), findsOneWidget);
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);
    });

    testWidgets('the host\'s own wait wins over a player\'s, and the player comes back after it', (tester) async {
      final app = await joined(tester);
      app.client.playerAway('p2', 2, 12);
      await settle(tester);
      expect(find.text('Player 2 is away'), findsOneWidget);

      app.client.hostAway(30);
      await settle(tester);
      expect(find.text('Waiting for the host to come back'), findsOneWidget);
      expect(find.text('Player 2 is away'), findsNothing, reason: 'the host wins');

      app.client.hostBack();
      await settle(tester);
      expect(find.text('Player 2 is away'), findsOneWidget, reason: 'the player still has to come back');
    });

    testWidgets('the phone that was away itself shows no card for its own player', (tester) async {
      final app = await joined(tester);
      app.client.playerAway(app.client.identity.controllerId, 1, 12);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });

    testWidgets('a drop hides the line, and the view coming back with player_away puts it up again', (tester) async {
      final app = await joined(tester);
      app.client.playerAway('p2', 2, 12);
      await settle(tester);
      expect(find.text('Player 2 is away'), findsOneWidget);

      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      expect(find.text('Reconnecting to the game…'), findsOneWidget);
      expect(find.text('Player 2 is away'), findsNothing);

      // The host sends the start and the away players again to the phone that
      // pairs back into the round (server_game_host.dart).
      app.client.emit(connected);
      await settle(tester);
      app.client.viewStart(arenaStart());
      await settle(tester);
      app.client.playerAway('p2', 2, 12);
      await settle(tester);
      expect(find.text('Player 2 is away'), findsOneWidget);
    });
  });
}
