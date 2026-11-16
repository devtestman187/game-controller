import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The Arena's music (M14 design section 7): its waiting card plays the lobby's
/// loop, as the picker and the join screen do (M14 bugs B-030), and every round
/// plays the Arena's piece again at its own "go" — Play again and Change mode
/// then Start too (M14 bugs B-029).
void main() {
  /// Runs the Bumper Round's clock down to [toMs] left, a frame at a time: the
  /// rules own the clock, so a test plays it out rather than setting it.
  Future<void> runClockDown(WidgetTester tester, {required int toMs}) async {
    while (arenaSnapshot(tester).timeLeftMs! > toMs) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The frames the results card takes to come up once the clock ran out.
  Future<void> resultsUp(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('arenaResults')), findsOneWidget);
  }

  testWidgets('the waiting card plays the lobby\'s loop, and the round\'s own at its go', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(sounds.loop, 'lobby', reason: 'the card is the lobby\'s stage, as the picker is (M14 bugs B-030)');
    expect(sounds.loopStarts, ['lobby'], reason: 'the picker\'s loop carried on to the card, unbroken');

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(sounds.loop, 'arena', reason: 'the round plays the Arena\'s piece at its go');
    expect(sounds.loopStarts, ['lobby', 'arena'], reason: 'the lobby stopped when the round started');
    expect(sounds.loopStops, [Duration.zero], reason: 'the lobby stops at once, so the two never play together');
  });

  testWidgets('Play again brings the Arena\'s piece back at the new round\'s go', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);
    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(sounds.loop, 'arena');
    await runClockDown(tester, toMs: 0);
    await resultsUp(tester);
    expect(sounds.loop, isNull, reason: 'the results end the round\'s music');

    await tester.tap(find.byKey(const Key('arenaAgain')));
    await roundStarted(tester);
    expect(sounds.loop, 'arena', reason: 'the new round\'s music, after Play again too (M14 bugs B-029)');
    expect(
      sounds.loopStarts.where((name) => name == 'arena'),
      hasLength(2),
      reason: 'the new round started its piece afresh (the first round\'s tempo changes included)',
    );
    expect(
      sounds.loopStarts.where((name) => name == 'lobby'),
      hasLength(1),
      reason: 'Play again never starts the lobby\'s',
    );
  });

  testWidgets('Change mode brings the lobby\'s loop back, and Start the round\'s', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);
    await readyUp(tester, fake);
    await roundStarted(tester);
    await runClockDown(tester, toMs: 0);
    await resultsUp(tester);

    await tester.tap(find.byKey(const Key('arenaChangeMode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(sounds.loop, 'lobby', reason: 'the card is the lobby\'s stage again (M14 bugs B-030)');
    expect(sounds.loopStarts.last, 'lobby', reason: 'and its loop started again there');
    expect(sounds.loopStarts.where((name) => name == 'lobby'), hasLength(2));

    await readyUp(tester, fake);
    await roundStarted(tester);
    expect(sounds.loop, 'arena', reason: 'and the next round\'s piece at its go (M14 bugs B-029)');
    expect(sounds.loopStarts.last, 'arena', reason: 'the card\'s lobby gave way to it');
    expect(sounds.loopStarts.where((name) => name == 'arena'), hasLength(2));
  });

  testWidgets('Music at 0% keeps the card silent, and turning it up plays the lobby\'s loop', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    final container = ProviderScope.containerOf(tester.element(find.byType(StubHome)));
    container.read(soundSettingsProvider.notifier).setMusicVolume(0);
    await tester.pump();
    await neutral(tester, fake, ['p1']);
    await openArenaCard(tester);
    expect(find.byKey(const Key('arenaWaitingCard')), findsOneWidget);
    expect(sounds.loop, isNull, reason: 'Music at 0% is no music on the card either');
    expect(sounds.loopStarts, isEmpty);

    container.read(soundSettingsProvider.notifier).setMusicVolume(60);
    await tester.pump();
    expect(sounds.loop, 'lobby', reason: 'turned up, the card plays the lobby\'s loop');
  });
}
