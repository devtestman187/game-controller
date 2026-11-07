import 'package:controller/src/ui/connect_screen.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  // Only the entry is asserted: the own player's pad (its labels, and A
  // through the menus) still reads the TV client's providers, because the
  // root screen built them before this route's scope existed — see the
  // report, "The scope does not reach the pad".
  testWidgets('a phone hosting shows its own game: the picker in the body, its own player paired', (tester) async {
    await pumpHostApp(tester);
    // No TV answered, so the app is on the Connect screen.
    expect(find.byType(ConnectScreen), findsOneWidget);

    // Host a game: the sheet offers both ways, and this phone plays.
    expect(find.byKey(const Key('hostGame')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hostGame')));
    await settle(tester);
    expect(find.byKey(const Key('hostStartSheet')), findsOneWidget);
    expect(find.byKey(const Key('hostOnPhone')), findsOneWidget);
    expect(find.byKey(const Key('hostOnDevice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hostOnPhone')));
    await settle(tester);
    final host = hostOf(tester);
    await hostReady(tester, host);
    await settle(tester);

    // The picker fills the body, behind the controls that stay on top.
    expect(find.byType(party.GamesScreen), findsOneWidget);
    expect(tester.getRect(find.byType(party.GamesScreen)), tester.getRect(find.byType(ControlsLayer)));
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    // The bar says this phone hosts, and shows the pairing code.
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);

    // The own player paired on the link alone, and it is player 1.
    final controllers = host.service.state.host.controllers;
    expect(controllers, hasLength(1));
    expect(controllers.single.isLocal, isTrue);
    expect(host.service.gameHost.players.single.number, 1);
    expect(find.byKey(const Key('playerBadge')), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);

    // The host's timers (heartbeats, the address refresh) would outlive the
    // test, so it is stopped here, in the real clock.
    await tester.runAsync(host.dispose);
  });
}
