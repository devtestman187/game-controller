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
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);

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

    // The picker fills the safe area, behind the bar (m12 §5), with no pad
    // over it: outside a round the host's screens are touch screens
    // (m12-host-touch rule 1).
    expect(find.byType(party.GamesScreen), findsOneWidget);
    expect(tester.getRect(find.byType(party.GamesScreen)), const Rect.fromLTWH(0, 0, 852, 393));
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(find.byType(ControlsLayer), findsNothing);
    expect(find.byKey(const Key('faceButtons')), findsNothing);
    expect(hostPhase(tester), party.RoundPhase.none);
    // The bar over the menus is the full one (rule 1): the host's chip and
    // its code on the left, the mode's three labels, Settings and Diagnostics
    // on the right. The compact one waits for the round.
    expect(find.byType(BarModes), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    expect(find.byKey(const Key('modeMenu')), findsNothing);
    expect(find.byKey(const Key('connectionDot')), findsNothing);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);

    // The own player paired on the link alone, and it is player 1.
    final controllers = host.service.state.host.controllers;
    expect(controllers, hasLength(1));
    expect(controllers.single.isLocal, isTrue);
    expect(host.service.gameHost.players.single.number, 1);
    expect(find.byKey(const Key('playerBadge')), findsOneWidget);
    // The look's badge, wearing player 1's character (M13 step 8, rule 7).
    expect(tester.widget<party.ToyBadge>(find.byType(party.ToyBadge)).number, 1);

    // 5. A tap presses Shape Race's card, then its levels. The screens come up
    // after the host's menus read the tap and the puzzle library loads, which
    // a busy PC delays past a fixed number of pumps (s9c).
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    expect(find.byType(party.ShapeRaceScreen), findsOneWidget);
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    expect(find.byKey(const Key('random-easy')), findsOneWidget);
    expect(hostPhase(tester), party.RoundPhase.none);

    // 6. A level opens the join screen: outside a round there is no pad here
    // either (rule 1), and the own player is in by itself with a tap to pick
    // its side (rule 5), so Start on the screen begins the round. The puzzle
    // runs inside the body box, and the pad gets its buttons.
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await settle(tester);
    expect(find.byType(party.JoinScreen), findsOneWidget);
    expect(tester.getRect(find.byType(party.JoinScreen)), const Rect.fromLTWH(0, 0, 852, 393));
    expect(find.byType(ControlsLayer), findsNothing);
    expect(find.byKey(const Key('faceButtons')), findsNothing);
    expect(find.byType(BarModes), findsOneWidget, reason: 'the join screen is outside the round too');
    expect(hostPhase(tester), party.RoundPhase.none);
    expect(find.text('Tap a side to play; press A on a phone to join.'), findsOneWidget);
    await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
    await tester.tap(find.byKey(const Key('joinStart')));
    await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
    final puzzle = tester.widget<party.PuzzleScreen>(find.byType(party.PuzzleScreen));
    expect(puzzle.teams.keys, [ownClientOf(host).identity.controllerId]);
    expect(puzzle.teams.values.map((s) => s.name), ['left']);
    await settle(tester);
    expect(tester.getRect(find.byType(party.PuzzleScreen)), const Rect.fromLTWH(0, 0, 852, 393));

    // The round starts with the "Get ready" beat (rule 3): the pad is already
    // up under the card, so thumbs find it before the clock runs.
    expect(hostPhase(tester), party.RoundPhase.ready);
    expect(find.byKey(const Key('getReady')), findsOneWidget);
    expect(find.byKey(const Key('faceButtons')), findsOneWidget);
    await untilPlaying(tester);

    // The round: the pad is up and the bar goes compact (rule 2), the mode,
    // Settings and Diagnostics as icons, and the host's code in a compact chip
    // right after the dot, so players can still join and the host can stop
    // from here (s7d2 Q1). The compact chip is as easy to hit as the bar's
    // Settings button (C14).
    expect(hostPhase(tester), party.RoundPhase.playing);
    expect(find.byKey(const Key('getReady')), findsNothing);
    expect(find.byKey(const Key('faceButtons')), findsOneWidget);
    expect(find.byType(BarModes), findsNothing);
    expect(find.byKey(const Key('modeMenu')), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    expect(find.byKey(const Key('connectionDot')), findsOneWidget);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('hostChip'))).left,
      greaterThan(tester.getRect(find.byKey(const Key('connectionDot'))).right),
    );
    final settings = tester.getSize(find.byTooltip('Settings'));
    expect(tester.getSize(find.byKey(const Key('hostChip'))).height, greaterThanOrEqualTo(settings.height));
    await until(
      tester,
      () => faceLabels(tester).contains('A Pick up'),
      () => 'The puzzle did not reach the pad: ${faceLabels(tester)}',
    );

    // The back goes up from the round to the game's levels, which the join
    // screen replaced: the round ends here, so no status its session sends
    // last is left half-sent when the tree goes.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(party.PuzzleScreen), findsNothing);
    expect(find.byType(party.ShapeRaceScreen), findsOneWidget);
    expect(hostPhase(tester), party.RoundPhase.none);

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
    // It takes the whole safe area, behind the bar (m12 §5): unlike "Play on
    // this phone", nothing sits beside the game (C34).
    expect(tester.getRect(find.byType(party.GamesScreen)), const Rect.fromLTWH(0, 0, 852, 393));

    // The bar over the picker is the full one on this route too
    // (m12-host-touch rule 1, both host routes): the host's chip with its code
    // and Diagnostics. With no pad there is nothing to configure, so no mode
    // and no Settings (C34), and no player badge: this phone is the screen,
    // not a player (m12 bug 1108a rule B).
    expect(find.byKey(const Key('playerBadge')), findsNothing);
    expect(find.text('P1'), findsNothing);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    expect(find.byKey(const Key('modeMenu')), findsNothing);
    expect(find.byKey(const Key('connectionDot')), findsNothing);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.textContaining('Hosting · '), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);

    await tester.runAsync(host.dispose);
  });

  testWidgets('the host route gets the full bar over its menus (m12-host-touch rule 1)', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);

    // "Play on this phone": the own player's badge and the host's code on the
    // left, the mode's three labels, Settings and Diagnostics on the right.
    expect(find.byKey(const Key('playerBadge')), findsOneWidget);
    expect(find.byType(BarModes), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    expect(find.byKey(const Key('hostChip')), findsOneWidget);
    expect(find.textContaining('Hosting · '), findsOneWidget);
    expect(find.textContaining(host.service.state.host.pairingCode), findsOneWidget);
    // The compact bar's own widgets are not here: they come with the round.
    expect(find.byKey(const Key('modeMenu')), findsNothing);
    expect(find.byKey(const Key('connectionDot')), findsNothing);

    await tester.runAsync(host.dispose);
  });

  group('shareView from the start sheet (m12-joined-view §0.1)', () {
    testWidgets('"Play on this phone" lets the phones that join see the game', (tester) async {
      await pumpHostApp(tester);
      final host = await enterHostMode(tester, choice: HostChoice.onPhone);
      expect(host.service.shareView, isTrue, reason: 'the phones that join show the game too');
      await tester.runAsync(host.dispose);
    });

    testWidgets('"Show on this device" keeps the game on this screen', (tester) async {
      await pumpHostApp(tester);
      final host = await enterHostMode(tester, choice: HostChoice.onDevice);
      expect(host.service.shareView, isFalse, reason: 'this phone is the screen everyone watches');
      await tester.runAsync(host.dispose);
    });
  });

  testWidgets('Stop hosting in the chip stops the host, and a second "Host a game" works', (tester) async {
    final app = await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    final restarts = app.discovery.restarts;

    // The chip in the bar over the picker opens the same menu as the compact
    // one over a round, so the host can still stop from its own screens
    // (s7d2 Q1).
    await tester.tap(find.byKey(const Key('hostChip')));
    await settle(tester);
    expect(find.byKey(const Key('newCode')), findsOneWidget);
    expect(find.byKey(const Key('stopHosting')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stopHosting')));
    await until(tester, () => !host.live, () => 'The host did not stop');
    await settle(tester);

    // Back on the Connect screen: the own player let go, the search again.
    expect(find.byType(HostScreen), findsNothing);
    expect(find.byType(ConnectScreen), findsOneWidget);
    expect(ownClientOf(host).snapshot.status, ClientStatus.idle);
    expect(app.discovery.restarts, restarts + 1);

    // Hosting again starts a new host, on the same providers.
    final second = await enterHostMode(tester);
    expect(second, isNot(same(host)));
    expect(find.byType(party.GamesScreen), findsOneWidget);
    expect(second.service.gameHost.players.single.number, 1);
    await tester.runAsync(second.dispose);
  });

  testWidgets('a stopped host lets a second "Host a game" start on the same providers', (tester) async {
    final app = await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    final restarts = app.discovery.restarts;

    // The back press is the host route's other way out than the chip's "Stop
    // hosting", and it stops the server the same way (m12 §3).
    await tester.binding.handlePopRoute();
    await until(tester, () => !host.live, () => 'The host did not stop');
    await settle(tester);

    // Back on the Connect screen: the own player let go, the search again.
    expect(find.byType(HostScreen), findsNothing);
    expect(find.byType(ConnectScreen), findsOneWidget);
    expect(ownClientOf(host).snapshot.status, ClientStatus.idle);
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

    final asked = host.service.gameHost.askRating(ownClientOf(host).identity.controllerId, id: 'r1', game: 'arena');
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

  // m12 bug 1107e: the picker is the games' root, so the back from a game
  // goes up to it first, and the host only stops there.
  testWidgets('the system back on the results goes to the picker and the host stays on', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    // The own player joined by itself (m12-host-touch rule 5): Start on the
    // screen begins the round, with no pad there.
    await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
    await tester.tap(find.byKey(const Key('joinStart')));
    await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
    // The round starts with the "Get ready" beat (rule 3): it has to end before
    // a step can end the round.
    await untilPlaying(tester);

    // The own player's board goes in at once: the round ends on the results,
    // which are outside the round: the pad goes away and the bar goes full
    // (m12-host-touch rules 1, 2).
    final match = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
    final board = match.gameOf(PuzzleSide.left);
    for (var i = 0; i < board.pieces.length; i++) {
      board.pieces[i]
        ..state = PieceState.locked
        ..pos = board.targetAt(i);
    }
    await untilShown(tester, find.text('Done!'), 'The results');
    await until(tester, () => hostPhase(tester) == party.RoundPhase.none, () => 'The phase did not stop');
    await settle(tester);
    expect(find.byKey(const Key('faceButtons')), findsNothing);
    expect(find.byType(BarModes), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);
    expect(find.byType(party.PuzzleScreen), findsNothing);
    expect(find.byType(HostScreen), findsOneWidget);
    expect(host.live, isTrue, reason: 'the back went up to the picker, not out of the host');
    await tester.runAsync(host.dispose);
  });

  // m12-host-touch rule 4: Start on the pad opens the pause menu, which is a
  // touch screen with the pad hidden, and Resume brings the pad back.
  testWidgets('Start on the pad pauses the round: the menu is touch, Resume brings the pad back', (tester) async {
    await pumpHostApp(tester);
    final host = await soloRound(tester);
    expect(hostPhase(tester), party.RoundPhase.playing);

    await pressStart(tester);
    await untilShown(tester, find.byKey(const Key('pauseMenu')), 'The pause menu');
    await until(tester, () => hostPhase(tester) == party.RoundPhase.none, () => 'The phase did not stop');
    await settle(tester);
    // Paused: nothing is playing, so the pad is gone and the bar is full
    // again (rules 1, 2, 4).
    expect(find.byKey(const Key('faceButtons')), findsNothing);
    expect(find.byType(BarModes), findsOneWidget);
    expect(find.byKey(const Key('modeMenu')), findsNothing);

    // Resume is a touch button, and the pad comes back with the round.
    await tester.tap(find.byKey(const Key('pauseResume')));
    await until(tester, () => hostPhase(tester) == party.RoundPhase.playing, () => 'The phase did not go on');
    await settle(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(find.byKey(const Key('faceButtons')), findsOneWidget);
    expect(find.byType(BarModes), findsNothing);

    await tester.runAsync(host.dispose);
  });

  // m12-host-touch rule 3: the phone app asks its host for a 3 s "Get ready"
  // beat, so thumbs find the pad before the clock runs.
  testWidgets('a round starts with a 3 s Get ready beat: the pad is up and the clock is held', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
    await tester.tap(find.byKey(const Key('joinStart')));
    await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
    await settle(tester);

    // The beat: the card counts, and the pad is up under it (rule 2).
    String count() => tester.widget<Text>(find.byKey(const Key('getReadyCount'))).data!;
    int timeLeft() => tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).snapshot.boards.first.timeLeftMs;
    final held = timeLeft();
    expect(hostPhase(tester), party.RoundPhase.ready);
    expect(count(), '3');
    expect(find.byKey(const Key('faceButtons')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(count(), '2');
    expect(timeLeft(), held, reason: 'the beat holds the round: no step runs');
    await tester.pump(const Duration(seconds: 1));
    expect(count(), '1');
    await tester.pump(const Duration(seconds: 1));

    // Three seconds on, the round plays.
    await settle(tester);
    expect(hostPhase(tester), party.RoundPhase.playing);
    expect(find.byKey(const Key('getReady')), findsNothing);
    expect(timeLeft(), lessThan(held), reason: 'the round goes on when the beat ends');
    await tester.runAsync(host.dispose);
  });

  // The plan's "one neutral input on hide" (§2): a pad that goes away under a
  // held finger leaves nothing pressed, and the app lets go of every button
  // with one neutral input.
  testWidgets('a pad hidden under a held finger lets go of it with one neutral input', (tester) async {
    final app = await pumpHostApp(tester);
    final host = await soloRound(tester);
    // Past Start's grace, so the press below counts as a new one (m12 §2.10).
    await tester.pump(const Duration(milliseconds: 640));

    // From here the pad's input goes to a fake client, so the input a hidden
    // pad sends can be counted: the own player's client is a real one.
    hostContainer(tester).read(ownClientProvider.notifier).set(app.client);
    final sent = app.client.inputs.length;
    final finger = await tester.startGesture(atFace(tester, ControllerButton.a));
    await tester.pump();
    expect(app.client.inputs.sublist(sent), ['A 0,0']);

    // Start pauses the round: the pad goes away with the finger still on it.
    // It comes from the own player's client, since the pad's own sends go to
    // the fake from here.
    ownClientOf(host).sendInput({ControllerButton.start});
    await untilShown(tester, find.byKey(const Key('pauseMenu')), 'The pause menu');
    ownClientOf(host).sendInput({});
    await until(tester, () => hostPhase(tester) == party.RoundPhase.none, () => 'The phase did not stop');
    await until(tester, () => app.client.inputs.length > sent + 1, () => 'The pad let go of nothing');
    // A frame more: the pad is told to go away by the same change, and goes on
    // the next build.
    await settle(tester);
    expect(app.client.inputs.sublist(sent), ['A 0,0', '0,0']);
    expect(hostContainer(tester).read(padProvider).isNeutral, isTrue);
    expect(find.byKey(const Key('faceButtons')), findsNothing);

    // Back in the round the pad is built again, and the finger's release
    // arrives after it went away: it presses nothing.
    await tester.tap(find.byKey(const Key('pauseResume')));
    await until(tester, () => hostPhase(tester) == party.RoundPhase.playing, () => 'The phase did not go on');
    await settle(tester);
    await finger.up();
    await settle(tester);
    expect(app.client.inputs.sublist(sent), ['A 0,0', '0,0']);

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
