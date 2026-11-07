import 'package:connection/connection.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  group('connecting', () {
    testWidgets('opens the Connect screen when there is no saved TV', (tester) async {
      final app = await pumpApp(tester);
      expect(find.text('Connect to a TV'), findsOneWidget);
      expect(find.textContaining('Searching'), findsOneWidget);

      app.discovery.emit(DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]));
      await tester.pump();
      await tester.tap(find.text('Thumb Party TV (Android TV)'));
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
    });

    testWidgets('manual entry checks the address before connecting', (tester) async {
      final app = await pumpApp(tester);
      await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.50:99999');
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.textContaining('not a valid port'), findsOneWidget);
      expect(app.client.calls, isEmpty);

      await tester.enterText(find.byKey(const Key('manualAddress')), '192.168.1.77');
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(app.client.calls, ['connect 192.168.1.77:45780']);
    });

    testWidgets('asks for the code, explains a wrong code and sends four digits', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(
        ClientSnapshot(
          status: ClientStatus.waitingForCode,
          target: tv,
          hostName: 'Android TV',
          problem: ClientProblem.wrongCode,
        ),
      );
      await tester.pump();
      expect(find.text('Enter the code shown on Android TV'), findsOneWidget);
      expect(find.textContaining('Wrong code'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('pairingCode')), '0427');
      expect(app.client.calls, ['code 0427']);
    });

    testWidgets('goes back to the controller once connected, with ping and 30 s stats', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(connected);
      await settle(tester);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.text('Android TV · 9 ms'), findsOneWidget);
      expect(find.text('30 s: min 5 · avg 22 · max 130 ms'), findsOneWidget);

      // The chip opens the Connect screen again, where Disconnect lives.
      await tester.tap(find.byKey(const Key('connectionChip')));
      await settle(tester);
      expect(find.text('Connected to Android TV'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      expect(app.client.calls, ['disconnect']);
    });

    testWidgets('shows reconnecting, and a way to retry after a failure', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(
        ClientSnapshot(status: ClientStatus.reconnecting, target: tv, hostName: 'Android TV', attempt: 3),
      );
      await tester.pump();
      expect(find.textContaining('Reconnecting to Android TV'), findsOneWidget);
      expect(find.text('Attempt 3'), findsOneWidget);

      app.client.emit(
        ClientSnapshot(
          status: ClientStatus.failed,
          target: tv,
          problem: ClientProblem.unreachable,
          detail: 'Connection refused',
        ),
      );
      await tester.pump();
      expect(find.textContaining('Couldn\'t reach'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
    });

    testWidgets('reconnects to the last TV on launch and stays on the controller', (tester) async {
      final app = await pumpApp(tester, paired: true);
      expect(app.client.calls, ['connect 192.168.1.50:45780']);
      expect(find.text('Connect to a TV'), findsNothing);
      expect(find.byKey(const Key('dpad')), findsOneWidget);
    });
  });

  group('hosting from the Connect screen (m12 §3)', () {
    testWidgets('"Host a game" is offered with no TV, and asks how to host', (tester) async {
      await pumpApp(tester);
      expect(find.text('Not connected'), findsWidgets);

      await tester.tap(find.byKey(const Key('hostGame')));
      await settle(tester);
      expect(find.byKey(const Key('hostStartSheet')), findsOneWidget);
      expect(find.text('Play on this phone'), findsOneWidget);
      expect(find.text('Show on this device'), findsOneWidget);
      // The phone one has the focus, so a remote's OK picks it.
      final focus = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(of: find.byKey(const Key('hostOnPhone')), matching: find.byWidget(focus.widget)),
        findsOneWidget,
      );
    });

    testWidgets('"Host a game" is offered when the TV cannot be reached', (tester) async {
      final app = await pumpApp(tester);
      app.client.emit(ClientSnapshot(status: ClientStatus.failed, target: tv, problem: ClientProblem.unreachable));
      await tester.pump();
      expect(find.textContaining('Couldn\'t reach'), findsOneWidget);
      expect(find.byKey(const Key('hostGame')), findsOneWidget);
    });

    testWidgets('cancelling the sheet starts nothing', (tester) async {
      final app = await pumpApp(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(ConnectScreen)));
      await tester.tap(find.byKey(const Key('hostGame')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('hostCancel')));
      await settle(tester);

      expect(find.byKey(const Key('hostStartSheet')), findsNothing);
      expect(container.read(hostingProvider), isNull);
      // Nothing stopped searching either.
      expect(app.discovery.stops, 0);
    });
  });
}
