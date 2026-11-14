import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The Arena's waiting card worked from a phone (M14 bugs B-013): the pads move
/// the focus over the card's rows and A presses the focused one, as on every
/// other menu, so a phone picks the mode and the map and starts the round
/// without the TV remote.
void main() {
  /// Home → Play → Arena's waiting card, with [phones] more phones on the
  /// roster first and every pad quiet so the card stays up.
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

  /// Presses [direction] until the focus is on [key]'s button, as a player
  /// walking the card does.
  Future<void> walkTo(WidgetTester tester, FakeHostService fake, String key, GamepadButton direction) async {
    for (var i = 0; i < 8 && !focused(tester, key); i++) {
      await press(tester, fake, 'p1', direction);
    }
    expect(focused(tester, key), isTrue, reason: '${direction.name} reaches $key');
  }

  testWidgets('a phone picks a mode, a map and starts the round, press after press', (tester) async {
    final fake = await openCard(tester, phones: ['p2']);

    // The card opens on the chosen mode, Bumper: right reaches Race, and A
    // presses it — twice, since a phone's second press used to be swallowed.
    await walkTo(tester, fake, 'arenaMode-race', GamepadButton.dpadRight);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(appContainer(tester).read(arenaSettingsProvider).mode, ArenaMode.race, reason: 'A presses the mode row');
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(appContainer(tester).read(arenaSettingsProvider).mode, ArenaMode.race, reason: 'the next press works too');

    // Down the card to the maps: the race plays the Playroom alone.
    await walkTo(tester, fake, 'arenaMap-playroom', GamepadButton.dpadDown);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.byKey(const Key('chosenMap-playroom')), findsOneWidget, reason: 'A presses the map row');

    // The player's own row is the card's Start: A readies P1, a second press
    // takes it back, and the round starts once P2 has readied too.
    await walkTo(tester, fake, 'arenaPlayer-p1', GamepadButton.dpadUp);
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.byKey(const Key('ready-p1')), findsOneWidget, reason: 'A on the row readies P1');
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget, reason: 'a second press takes it back, as a tap does');
    await press(tester, fake, 'p1', GamepadButton.a);
    expect(find.byKey(const Key('ready-p1')), findsOneWidget);

    await walkTo(tester, fake, 'arenaPlayer-p2', GamepadButton.dpadDown);
    await press(tester, fake, 'p2', GamepadButton.a);
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'every joined player is ready: the round runs');
    expect(arenaSnapshot(tester).mode, ArenaMode.race, reason: 'the round plays the mode the phone picked');
    expect(arenaSnapshot(tester).mapId, 'playroom', reason: 'and the map it picked');
  });

  testWidgets('a phone also readies another player\'s row, and the round waits for everyone', (tester) async {
    final fake = await openCard(tester, phones: ['p2']);
    await walkTo(tester, fake, 'arenaPlayer-p2', GamepadButton.dpadDown);
    await press(tester, fake, 'p2', GamepadButton.a);
    expect(find.byKey(const Key('ready-p2')), findsOneWidget, reason: 'P2 presses its own row');
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget, reason: 'P1 has not readied');

    await walkTo(tester, fake, 'arenaPlayer-p1', GamepadButton.dpadUp);
    await press(tester, fake, 'p1', GamepadButton.a);
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'both ready: the round runs');
  });
}
