import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The Arena's waiting card for a night's one player (M14 bugs B-020): it shows
/// as it does for two, with its map choice, and the round waits for the only
/// player's Start (B-002 started it at once, without the card). A phone host
/// could not pick a map at all, so the owner asked for the choice back.
void main() {
  /// Home → Play → Party night → its Bumper Round, stopping at the card.
  /// [phones] adds a second phone to the sample roster first.
  Future<FakeHostService> openNightBumperCard(WidgetTester tester, {List<String> phones = const []}) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    for (final id in phones) {
      fake.state = withController(fake.state, phoneInfo(id, 2));
    }
    if (phones.isNotEmpty) fake.emit();
    await neutral(tester, fake, ['p1', ...phones]);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return fake;
  }

  testWidgets('a night\'s one player gets the Arena\'s card, on Surprise me, and the round waits for Start', (
    tester,
  ) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    // A map saved before the night: the night's card still opens on Surprise me,
    // so the night plays a map it hasn't used (design section 7b).
    appContainer(tester).read(arenaSettingsProvider.notifier).setMap('pinball');
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('arenaWaitingCard')),
      findsOneWidget,
      reason: 'the map choice shows for one player too',
    );
    expect(find.byKey(const Key('arenaMode-bumper')), findsOneWidget);
    expect(
      find.byKey(const Key('arenaMode-race')),
      findsOneWidget,
      reason: 'a solo night offers both modes (M14 bugs B-020 follow-up); it still opens on Bumper',
    );
    expect(find.byKey(const Key('arenaMap-pinball')), findsOneWidget, reason: 'the card\'s map choice is there');
    expect(find.byKey(const Key('chosenMap-pinball')), findsNothing, reason: 'a night opens on Surprise me');
    expect(find.byKey(const Key('notReady-p1')), findsOneWidget, reason: 'the only player has not pressed Start');

    // A second of frames: the round starts on a press, never on its own.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'nobody has pressed Start');
    expect(find.byKey(const Key('arena')), findsNothing, reason: 'no round runs before Start');

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(find.byKey(const Key('arenaWaitingCard')), findsNothing, reason: 'all ready: the round starts');
    expect(arenaSnapshot(tester).mode, ArenaMode.bumper);
  });

  testWidgets('a night\'s card is the same for two players as before', (tester) async {
    final fake = await openNightBumperCard(tester, phones: ['p2']);

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'two players ready up');
    expect(find.text('P2 Phone 2'), findsOneWidget, reason: 'each joined phone has its row');
    expect(find.byKey(const Key('arena')), findsNothing);

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget);
  });

  testWidgets('outside a night one player keeps the card with both modes', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget, reason: 'the map choice matters here');
    expect(find.byKey(const Key('arenaMode-race')), findsOneWidget, reason: 'outside a night both modes show');
    expect(find.byKey(const Key('arena')), findsNothing, reason: 'the round waits for Start');
  });
}
