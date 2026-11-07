import 'package:connection/connection.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import 'support/pump_app.dart';

/// A host with [ip] and a kind, as the TXT record gave it.
DiscoveredHost hostFrom(String name, String ip, String? kind) => DiscoveredHost(
  address: HostAddress(addresses: [ip], port: defaultPort, name: name),
  kind: kind,
);

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

  group('the host list labels (m12 §0.6)', () {
    test('the kind in the TXT record, and null for one the app does not know', () {
      expect(hostKindFrom(party.HostKind.phone), party.HostKind.phone);
      expect(hostKindFrom(party.HostKind.tablet), party.HostKind.tablet);
      expect(hostKindFrom(party.HostKind.tv), party.HostKind.tv);
      expect(hostKindFrom(party.HostKind.pc), party.HostKind.pc);
      expect(hostKindFrom('fridge'), isNull, reason: 'a kind from a newer host than this app');
      expect(hostKindFrom(''), isNull);
      expect(hostKindFrom(null), isNull, reason: 'a host that did not say');
    });

    testWidgets('each host shows its kind\'s icon and word, under Games on this Wi-Fi', (tester) async {
      // Tall enough for all five hosts at once.
      final app = await pumpApp(tester, screen: const Size(852, 720));
      app.discovery.emit(
        DiscoveryState(
          running: true,
          everFound: true,
          hosts: [
            hostFrom('A phone', '192.168.1.51', party.HostKind.phone),
            hostFrom('A tablet', '192.168.1.52', party.HostKind.tablet),
            hostFrom('A TV', '192.168.1.53', party.HostKind.tv),
            hostFrom('A PC', '192.168.1.54', party.HostKind.pc),
            hostFrom('An old host', '192.168.1.55', null),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Games on this Wi-Fi'), findsOneWidget);
      expect(find.text('TVs on this Wi-Fi'), findsNothing);
      expect(find.byIcon(Icons.smartphone), findsOneWidget);
      expect(find.byIcon(Icons.tablet), findsOneWidget);
      expect(find.byIcon(Icons.computer), findsOneWidget);
      // The TV host's icon, and the same one for a host that said no kind.
      expect(find.byIcon(Icons.tv), findsNWidgets(2));
      expect(find.text('Phone · 192.168.1.51:$defaultPort'), findsOneWidget);
      expect(find.text('Tablet · 192.168.1.52:$defaultPort'), findsOneWidget);
      expect(find.text('TV · 192.168.1.53:$defaultPort'), findsOneWidget);
      expect(find.text('PC · 192.168.1.54:$defaultPort'), findsOneWidget);
      expect(find.text('192.168.1.55:$defaultPort'), findsOneWidget, reason: 'a host that said no kind gets no word');
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
