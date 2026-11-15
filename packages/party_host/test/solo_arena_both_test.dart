import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// A solo night's Arena card offers both modes (M14 bugs B-020 follow-up, owner,
/// Nov 15, 2026: "Solo party should offer race and bumper"): it opens on the
/// Bumper Round, as a night's card did before, and its Race button starts a race
/// round. A night of two or more keeps the Bumper button alone (design section
/// 8).
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

  testWidgets('a solo night\'s card offers both modes, opening on the Bumper Round and Surprise me', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    // A race and a map saved before the night: the night's card still opens on
    // the Bumper Round, and on Surprise me, so the night plays a map it hasn't
    // used (design sections 7b and 8).
    appContainer(tester).read(arenaSettingsProvider.notifier)
      ..setMode(ArenaMode.race)
      ..setMap('pinball');
    await tester.pump();
    await neutral(tester, fake, ['p1']);
    await openNight(tester);
    await tapVisible(tester, find.byKey(const Key('nightBumper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(find.byKey(const Key('arenaMode-bumper')), findsOneWidget);
    expect(
      find.byKey(const Key('arenaMode-race')),
      findsOneWidget,
      reason: 'owner, Nov 15, 2026: a solo party offers the race and the bumper',
    );
    expect(
      focused(tester, 'arenaMode-bumper'),
      isTrue,
      reason: 'a solo night opens on the Bumper Round, whatever mode was saved before it',
    );
    expect(find.byKey(const Key('chosenMap-pinball')), findsNothing, reason: 'a night opens on Surprise me');

    // The Bumper Round is as it was: Start plays it, with its clock.
    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget);
    expect(arenaSnapshot(tester).mode, ArenaMode.bumper);
    expect(arenaSnapshot(tester).timeLeftMs, isNotNull, reason: 'the Bumper Round\'s clock runs');
  });

  testWidgets('the solo card\'s Race button starts a race round, and the night goes on after it', (tester) async {
    final fake = await openNightBumperCard(tester);
    await tester.ensureVisible(find.byKey(const Key('arenaMode-race')));
    await tester.tap(find.byKey(const Key('arenaMode-race')));
    await tester.pump();
    expect(
      appContainer(tester).read(arenaSettingsProvider).mode,
      ArenaMode.race,
      reason: 'the race button chooses the race',
    );

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget, reason: 'a round runs');
    expect(arenaSnapshot(tester).mode, ArenaMode.race, reason: 'Start plays the mode the card shows');
    expect(arenaSnapshot(tester).timeLeftMs, isNull, reason: 'a race has no clock');
    final night = appContainer(tester).read(partyNightProvider)!;
    expect(night.round, 0, reason: 'a race records no round: it has no end and no points (N7)');
    expect(night.maps, isEmpty, reason: 'a race books no map, so the Bumper Rounds after it get a fresh one');
  });

  testWidgets('a night of two players keeps the Bumper button alone', (tester) async {
    final fake = await openNightBumperCard(tester, phones: ['p2']);

    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(find.byKey(const Key('arenaMode-bumper')), findsOneWidget);
    expect(
      find.byKey(const Key('arenaMode-race')),
      findsNothing,
      reason: 'a night of two or more plays the Bumper Round alone (design section 8)',
    );

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(arenaSnapshot(tester).mode, ArenaMode.bumper);
  });
}
