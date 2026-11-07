import 'package:connection/connection.dart';
import 'package:controller/src/host/host_screen.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/bar_modes.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('a phone hosting plays its own game: the pad, the menus, and a solo Shape Race', (tester) async {
    // A landscape phone: the host's screens get the 341-high body under this
    // app's bar, and the join screen's sides scroll to fit it.
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

    // 4. The menus' buttons reach the pad: client, host, menus, layout, client.
    expect(faceLabels(tester), allOf(contains('A OK'), contains('B Back')));

    // 5. A on the pad presses the focused card: Shape Race.
    await pressA(tester);
    expect(find.byType(party.ShapeRaceScreen), findsOneWidget);
    expect(find.byKey(const Key('random-easy')), findsOneWidget);

    // 6. A again opens the join screen, A joins the left side, A again starts:
    // the puzzle runs inside the body box, and the pad gets its buttons.
    await pressA(tester);
    expect(find.byType(party.JoinScreen), findsOneWidget);
    await pressA(tester);
    await pressA(tester);
    final puzzle = tester.widget<party.PuzzleScreen>(find.byType(party.PuzzleScreen));
    expect(puzzle.teams.keys, [host.client.identity.controllerId]);
    expect(puzzle.teams.values.map((s) => s.name), ['left']);
    await settle(tester);
    expect(tester.getRect(find.byType(party.PuzzleScreen)), tester.getRect(find.byType(ControlsLayer)));
    await until(
      tester,
      () => faceLabels(tester).contains('A Pick up'),
      () => 'The puzzle did not reach the pad: ${faceLabels(tester)}',
    );

    // The host's timers (heartbeats, the address refresh) would outlive the
    // test, so it is stopped here, in the real clock.
    await tester.runAsync(host.dispose);
  });

  testWidgets('"Show on this device" shows the game alone: no pad, no modes, no Settings', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);

    // The game, and none of the controls that would play it here (C34).
    expect(find.byType(party.GamesScreen), findsOneWidget);
    expect(find.byType(ControlsLayer), findsNothing);
    expect(find.byKey(const Key('faceButtons')), findsNothing);
    expect(find.byKey(const Key('dpad')), findsNothing);
    expect(find.byType(BarModes), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    // It takes the whole body under the bar (the padding's 4 plus the 48-high
    // row): unlike "Play on this phone", nothing sits beside the game (C34).
    expect(tester.getRect(find.byType(party.GamesScreen)), const Rect.fromLTWH(0, 52, 852, 341));

    // How the others join is still the bar's: the chip and Diagnostics.
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);

    await tester.runAsync(host.dispose);
  });

  testWidgets('Stop hosting in the chip stops the host, and a second "Host a game" works', (tester) async {
    final app = await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    final restarts = app.discovery.restarts;

    await tester.tap(find.byKey(const Key('hostChip')));
    await settle(tester);
    expect(find.byKey(const Key('stopHosting')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stopHosting')));
    await until(tester, () => !host.live, () => 'The host did not stop');
    await settle(tester);

    // Back on the Connect screen: the own player let go, the search again.
    expect(find.byType(HostScreen), findsNothing);
    expect(find.byType(ConnectScreen), findsOneWidget);
    expect(host.client.snapshot.status, ClientStatus.idle);
    expect(app.discovery.restarts, restarts + 1);

    // Hosting again starts a new host, on the same providers.
    final second = await enterHostMode(tester);
    expect(second, isNot(same(host)));
    expect(find.byType(party.GamesScreen), findsOneWidget);
    expect(second.service.gameHost.players.single.number, 1);
    await tester.runAsync(second.dispose);
  });

  testWidgets('a rating prompt for the own player shows no dialog while this phone hosts', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    // Read first, so the prompt reaches a live provider: it has to hear the
    // own player before the host asks it.
    expect(hostContainer(tester).read(ratingPromptProvider), isNull);

    final asked = host.service.gameHost.askRating(host.client.identity.controllerId, id: 'r1', game: 'arena');
    expect(asked, isTrue, reason: 'the own player is connected');
    await until(
      tester,
      () => hostContainer(tester).read(ratingPromptProvider) != null,
      () => 'The own player got no prompt',
    );
    await settle(tester);

    // Nothing is shown over this phone's own game: the prompt goes unanswered.
    expect(find.text('How did the controls feel?'), findsNothing);
    await tester.runAsync(host.dispose);
  });

  testWidgets('the system back press stops hosting rather than leaving the server behind it', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);

    await tester.binding.handlePopRoute();
    await until(tester, () => !host.live, () => 'The back press did not stop the host');
    await settle(tester);
    expect(find.byType(HostScreen), findsNothing);
    expect(find.byType(ConnectScreen), findsOneWidget);
  });
}
