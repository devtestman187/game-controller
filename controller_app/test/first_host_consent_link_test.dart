import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/host_screen.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// A phone that joins [host] over a socket on this machine, as one on the LAN
/// would: the host sees it as a phone, not as its own player
/// (host_focus_pad_test's helper).
Future<ControllerClient> joinPhone(WidgetTester tester, PhoneHost host, String id) async {
  final state = host.service.state;
  final port = state.host.port;
  if (port == null) fail('The host is not listening');
  final client = ControllerClient(
    identity: ControllerIdentity(controllerId: id, name: id, platform: 'android', appVersion: 't'),
    connector: WebSocketConnector(),
    heartbeatInterval: const Duration(milliseconds: 100),
    heartbeatTimeout: const Duration(seconds: 2),
    retryDelays: const [Duration(milliseconds: 50)],
  );
  client.connect(
    HostAddress(addresses: ['127.0.0.1'], port: port),
    code: state.host.pairingCode,
  );
  await until(
    tester,
    () => client.snapshot.isConnected && host.service.gameHost.players.any((p) => p.id == id),
    () => 'The phone did not join: ${client.snapshot} / ${host.service.gameHost.players}',
  );
  return client;
}

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);
  // The joined phone connects over a socket on this machine, as a real phone
  // does: the test binding blocks real HTTP and WebSockets by default.
  setUp(() => HttpOverrides.global = null);

  testWidgets('the host route stays up when the own client links and a phone joins under the prompt', (tester) async {
    final app = await pumpHostApp(tester);
    // "Host a game", on this phone. The start points this phone's client at
    // its own player, and the Connect panel is rebuilt away (B-023 review
    // finding 1): the route has to open first and ask the prompt itself.
    await tester.tap(find.byKey(const Key('hostGame')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('hostOnPhone')));
    await settle(tester);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);
    expect(find.byType(HostScreen), findsOneWidget, reason: 'the route opens under the prompt, not after it');

    // The own player's link comes up while the adult reads the prompt: on a
    // phone the panel that started the host is gone by now.
    final host = hostOf(tester);
    await hostReady(tester, host);
    // A phone joins during the same window; the prompt waits for the adult.
    final phone = await joinPhone(tester, host, 'phone-b');
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'the prompt waits for the adult');

    await tester.tap(find.byKey(const Key('consentYes')));
    await settle(tester);

    // The answer saves the consent, closes the prompt and leaves the route up,
    // with the phone that joined while it was open still in the host's list.
    expect(find.byKey(const Key('consentDialog')), findsNothing);
    expect(find.byType(HostScreen), findsOneWidget, reason: 'the own client`s link does not take the route away');
    expect(hostContainer(tester).read(party.statsStateProvider).consent, isTrue);
    expect(app.prefs.getBool('statsConsent'), isTrue);
    expect(
      host.service.gameHost.players.map((p) => p.id),
      contains('phone-b'),
      reason: 'the phone that joined under the prompt is one of the host`s players',
    );

    // Everything that outlives a frame is stopped in the real clock.
    await tester.runAsync(phone.dispose);
    await tester.runAsync(host.dispose);
  });
}
