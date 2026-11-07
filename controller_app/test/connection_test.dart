import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

void main() {
  group('connection (M6)', () {
    testWidgets('coming back to the app reconnects at once', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(app.client.calls, isNot(contains('resume')));
      // The platform walks back through the states it left by; a jump from
      // paused straight to resumed is one it never sends, and the app's
      // lifecycle listeners reject it.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(app.client.calls, contains('resume'));
    });

    testWidgets('shows the player number the TV gave this phone', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 2));
      await settle(tester);
      expect(find.text('P2'), findsOneWidget);
      final badge = tester.widget<Container>(find.byKey(const Key('playerBadge')));
      expect((badge.decoration! as BoxDecoration).color, Color(playerColors[1]));
      app.client.emit(connected.copyWith(status: ClientStatus.reconnecting, player: null));
      await settle(tester);
      expect(find.byKey(const Key('playerBadge')), findsNothing);
    });

    testWidgets('while reconnecting for long, the TV is looked for again', (tester) async {
      final app = await pumpApp(tester, paired: true);
      final before = app.discovery.restarts;
      for (var attempt = 1; attempt <= 8; attempt++) {
        app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv, attempt: attempt));
        await tester.pump();
      }
      expect(app.discovery.restarts - before, 2, reason: 'at attempts 4 and 8');
    });

    testWidgets('Diagnostics lists each drop and how long it took to come back', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      app.client.emit(
        ClientSnapshot(status: ClientStatus.reconnecting, target: tv, attempt: 1, detail: 'No heartbeat'),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      app.client.emit(connected);
      await tester.pump();
      await tester.tap(find.byTooltip('Diagnostics'));
      await settle(tester);
      final drop = find.textContaining('Dropped (No heartbeat), back after');
      await scrollTo(tester, drop);
      expect(drop, findsOneWidget);
    });
  });
}
