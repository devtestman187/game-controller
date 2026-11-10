import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The Arena's waiting card (M14 b2, design section 8): the code, the phones
/// and their ready marks, the mode buttons, Robo's level while one player is in
/// the Bumper Round, the map picker, and the beat the card starts.
void main() {
  /// Home → Play → Arena's waiting card, with every phone's pad quiet so the
  /// card stays up until the test readies them or presses one of its buttons.
  /// [phones] adds phones to the sample roster first.
  Future<FakeHostService> openCard(WidgetTester tester, {List<String> phones = const []}) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    for (final id in phones) {
      fake.state = withController(fake.state, phoneInfo(id, 2));
    }
    if (phones.isNotEmpty) fake.emit();
    await neutral(tester, fake, ['p1', ...phones]);
    await openArenaCard(tester);
    return fake;
  }

  /// Presses a card button with the remote, scrolling it into view first (the
  /// card's map grid runs past a TV's height).
  Future<void> tapCard(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('the card shows the code, each phone with its ready mark, and the maps it can play', (tester) async {
    expect(testMaps().maps, hasLength(5), reason: 'the kit\'s five maps, read from its files');
    await openCard(tester);
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(find.byKey(const Key('arenaWaitingHeader')), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('0427'), findsOneWidget, reason: 'the pairing code, as the games screen shows it');
    expect(find.text('P1 iPhone 3F1C'), findsOneWidget, reason: 'each joined phone with its badge and name');
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget);
    expect(find.text("Press A when you're ready."), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);

    // The card opens on the Bumper Round, which every map plays (frame 8).
    for (final map in testMaps().maps) {
      expect(
        find.byKey(Key('arenaMap-${map.id}')),
        findsOneWidget,
        reason: '${map.name}: every map plays the Bumper Round',
      );
    }
    expect(find.byKey(const Key('arenaMap-surprise')), findsOneWidget);

    // The race is the Playroom's alone: the four new maps are Bumper arenas
    // with no finish, so the picker offers the other mode's maps alone (design
    // section 7b).
    await tapCard(tester, 'arenaMode-race');
    expect(find.byKey(const Key('arenaMap-playroom')), findsOneWidget);
    expect(find.byKey(const Key('arenaMap-pinball')), findsNothing, reason: 'Pinball has no race');
    expect(find.byKey(const Key('arenaMap-surprise')), findsOneWidget);
  });

  testWidgets('a phone\'s A readies it, and the round starts when every phone is ready', (tester) async {
    final fake = await openCard(tester, phones: ['p2']);
    expect(find.text('P2 Phone 2'), findsOneWidget);

    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.byKey(const Key('ready-p1')), findsOneWidget);
    expect(find.byKey(const Key('notReady-p2')), findsOneWidget, reason: 'P2 hasn\'t pressed yet');

    // A again un-readies: the card is the player's to change until the round.
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget);
    await press(tester, fake, 'p1', GamepadButton.a);
    await press(tester, fake, 'p2', GamepadButton.a);
    await tester.pump();
    expect(find.byKey(const Key('arenaWaitingCard')), findsNothing, reason: 'all ready: the round starts');
    expect(find.byKey(const Key('arena')), findsOneWidget);
  });

  testWidgets('the remote reaches the card\'s buttons, and the mode it picks is the round\'s', (tester) async {
    final fake = await openCard(tester);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'arena waiting mode',
      reason: 'the card opens on its chosen mode, as frame 8 shows',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(tester, 'arenaMode-race'), isTrue, reason: 'the arrows walk the card\'s buttons');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(appContainer(tester).read(arenaSettingsProvider).mode, ArenaMode.race);

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(arenaSnapshot(tester).mode, ArenaMode.race, reason: 'the round plays the mode the card picked');
  });

  testWidgets('the map picked on the card is the map the round plays', (tester) async {
    final fake = await openCard(tester);
    await tapCard(tester, 'arenaMap-pinball');
    expect(find.byKey(const Key('chosenMap-pinball')), findsOneWidget, reason: 'the card shows the pick');

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(arenaSnapshot(tester).mapId, 'pinball');
  });

  testWidgets('Surprise me starts on another map than the last round\'s', (tester) async {
    final fake = await openCard(tester);
    appContainer(tester).read(arenaSettingsProvider.notifier).playedMap('pinball');
    await tester.pump();
    await tapCard(tester, 'arenaMap-surprise');
    expect(find.byKey(const Key('chosenMap-pinball')), findsNothing, reason: 'Surprise me is chosen instead');

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(arenaSnapshot(tester).mapId, isNot('pinball'), reason: 'Surprise me picks a map that wasn\'t played last');
  });

  testWidgets('one player in the Bumper Round brings Robo, and his level is kept', (tester) async {
    await openCard(tester);
    expect(find.byKey(const Key('roboBadge')), findsOneWidget, reason: 'Robo joins a lone player in the Bumper Round');
    expect(find.text('Robo'), findsOneWidget);
    expect(find.text('Robo joins you'), findsOneWidget);
    expect(find.text('Robo:'), findsOneWidget);

    await tapCard(tester, 'roboLevel-hard');
    expect(appContainer(tester).read(arenaSettingsProvider).roboLevel, RoboLevel.hard, reason: 'kept on the host');

    await tapCard(tester, 'arenaMode-race');
    expect(find.byKey(const Key('roboBadge')), findsNothing, reason: 'Robo only plays the Bumper Round');
  });

  testWidgets('a phone\'s B leaves the Arena from the waiting card', (tester) async {
    final fake = await openCard(tester);
    await press(tester, fake, 'p1', GamepadButton.b);
    await navigated(tester);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
  });

  testWidgets('the TV gets the 3-2-1 beat too, before the Arena round', (tester) async {
    // The host asks for no beat of its own (as the TV does): the Arena's card
    // passes one, so the round waits for its 3-2-1 anywhere.
    final fake = await openCard(tester);
    await readyUp(tester, fake);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('getReady')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const Key('getReady')), findsNothing, reason: 'the beat is over: the round runs');
    expect(find.byKey(const Key('arena')), findsOneWidget);
  });
}
