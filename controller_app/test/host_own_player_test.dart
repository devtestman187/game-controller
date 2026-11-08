import 'package:connection/connection.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// m12 bug 1108a: "Show on this device" makes this phone the game's screen,
/// like the TV, so it has no player of its own and everyone joins from another
/// phone. "Play on this phone" keeps the player it always had.
void main() {
  // The puzzle files are read once, before any test runs (s9g), and the look's
  // fonts are loaded: the join screen is laid out to fit a phone's height
  // (m13 §3a).
  setUpAll(loadPuzzles);
  setUpAll(loadHostFonts);

  testWidgets('"Show on this device" pairs no player of its own, and the first phone to join is P1', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);

    // Nothing pairs on the in-process link: the host's only players are the
    // phones that join from now on (rule A). The bar keeps what it shows
    // without a player: the chip with the code, and Diagnostics (rule B).
    expect(host.client, isNull, reason: 'no own player, so no client to pair one with');
    expect(host.listener, isNull);
    expect(host.service.state.host.controllers, isEmpty);
    expect(host.service.gameHost.players, isEmpty);
    expect(find.byKey(const Key('playerBadge')), findsNothing);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);

    // The join screen lists no player of its own (no "Not joined: P1 …"), and
    // asks for a phone to join instead of a tap on a side.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await settle(tester);
    expect(find.byKey(const Key('notJoined')), findsNothing);
    expect(find.textContaining('(you)'), findsNothing);
    expect(
      find.textContaining('Tap a side to play'),
      findsNothing,
      reason: 'that hint is for the phone that plays here',
    );

    // The first phone to join takes P1: the lowest free number a pairing phone
    // is given (HostServer), which a local player takes the same way.
    final joiner = host.service.gameHost.addLocalPlayer(nickname: 'Ada');
    expect(joiner.number, 1);
    await until(
      tester,
      () => find.text('Not joined: P1 Ada').evaluate().isNotEmpty,
      () => 'The phone that joined is not listed as P1: ${host.service.gameHost.players}',
    );

    // It joins a side with A, and Start on the screen begins the match: the
    // host phone needs no pad of its own.
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
    final puzzle = tester.widget<party.PuzzleScreen>(find.byType(party.PuzzleScreen));
    expect(puzzle.teams.keys, [joiner.id], reason: 'the first phone to join plays as P1');
    expect(puzzle.teams.values.map((s) => s.name), ['left']);
    await tester.runAsync(host.dispose);
  });

  testWidgets('"Play on this phone" pairs its own player, and it joins P1 by itself', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);

    // The own player paired on the link alone, and it is player 1 (rule C).
    final own = ownClientOf(host);
    expect(own.snapshot.isConnected, isTrue);
    expect(host.service.state.host.controllers, hasLength(1));
    expect(host.service.state.host.controllers.single.isLocal, isTrue);
    expect(host.service.gameHost.players.single.number, 1);
    expect(find.byKey(const Key('playerBadge')), findsOneWidget);

    // It joins a side by itself, and says so, as it always has (rule C).
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
    await tester.runAsync(host.dispose);
  });

  testWidgets('stopping a "Show on this device" host and playing here pairs a player again', (tester) async {
    await pumpHostApp(tester);
    final shown = await enterHostMode(tester, choice: HostChoice.onDevice);
    expect(shown.client, isNull);
    await stopHosting(tester, shown);

    final played = await enterHostMode(tester);
    expect(played, isNot(same(shown)));
    expect(ownClientOf(played).snapshot.isConnected, isTrue);
    expect(played.service.gameHost.players.single.number, 1);
    expect(find.byKey(const Key('playerBadge')), findsOneWidget);
    await tester.runAsync(played.dispose);
  });

  testWidgets('stopping a host that played here and showing on this device pairs no player', (tester) async {
    await pumpHostApp(tester);
    final played = await enterHostMode(tester);
    expect(ownClientOf(played).snapshot.isConnected, isTrue);
    await stopHosting(tester, played);

    final shown = await enterHostMode(tester, choice: HostChoice.onDevice);
    expect(shown, isNot(same(played)));
    expect(shown.client, isNull);
    expect(shown.listener, isNull);
    // Nothing is connected: the player this phone paired as is only a pairing
    // the host remembers, as any phone that dropped is, and it is no player
    // here.
    expect(shown.service.state.host.controllers.where((c) => c.state != ControllerState.disconnected), isEmpty);
    expect(shown.service.gameHost.players, isEmpty);
    // Nor does its number stay taken: the first phone to join is P1 (rule A).
    expect(shown.service.gameHost.addLocalPlayer(nickname: 'Bo').number, 1);
    expect(find.byKey(const Key('playerBadge')), findsNothing);
    await tester.runAsync(shown.dispose);
  });
}
