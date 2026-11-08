import 'package:connection/connection.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// m12 bug 1108a fix2 (Q1): the compact bar over a round. A phone that only
/// shows the game has no link of its own, so its bar shows the code to join
/// and no link dot; a phone that plays here keeps the dot, with the Connect
/// screen behind it.
void main() {
  // The puzzle files are read once, before any test runs (s9g).
  setUpAll(loadPuzzles);

  testWidgets('the compact bar over a "Show on this device" round has the code and no link dot', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);

    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    // A phone joins and takes the left side; Start on the screen begins the
    // round (this phone has no player and no pad of its own).
    final joiner = host.service.gameHost.addLocalPlayer(nickname: 'Ada');
    await until(
      tester,
      () => find.text('Not joined: P1 Ada').evaluate().isNotEmpty,
      () => 'The phone that joined is not listed as P1: ${host.service.gameHost.players}',
    );
    joiner.set(const GamepadState(buttons: {GamepadButton.a}, mode: InputMode.keyboard));
    await until(
      tester,
      () =>
          find.descendant(of: find.byKey(const Key('side-left')), matching: find.text('P1 Ada')).evaluate().isNotEmpty,
      () => 'The phone that joined did not take a side',
    );
    joiner.set(GamepadState.neutral);
    await settle(tester);
    await tester.tap(find.byKey(const Key('joinStart')));
    await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
    await settle(tester);

    // The compact bar: no dot, because the dot is the way into Connect and
    // this phone has no link of its own; the code to join stays (Q1).
    expect(find.byKey(const Key('connectionDot')), findsNothing);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);
    await tester.runAsync(host.dispose);
  });

  testWidgets('the compact bar over a "Play on this phone" round keeps the link dot', (tester) async {
    await pumpHostApp(tester);
    final host = await soloRound(tester);

    // This phone's own player is on the link, so the dot and its way into
    // Connect stay, as they were (Q1).
    expect(find.byKey(const Key('connectionDot')), findsOneWidget);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    await tester.runAsync(host.dispose);
  });
}
