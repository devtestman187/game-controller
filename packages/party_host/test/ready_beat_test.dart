import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// The "Get ready" beat (m12-host-touch rule 3, job s10c): a round is held for
/// [Pausable.ready] with no step and the card counts 3, 2, 1 over the game, the
/// round's first frame goes out before the hold so a phone showing the game
/// draws the board, Start opens nothing until the beat ends, a round that waits
/// holds the beat too, and a host that asks for no beat starts as it always
/// did (the TV, rule 6).
void main() {
  /// Home → Play → Shape Race → the house puzzle with P1 on the left and P2 on
  /// the right, with a [Pausable.ready] beat: the beat is running when this
  /// returns. [phoneShows] gives the round a phone that shows it, set before
  /// the round starts, as a joined phone would be; [appAway] is the host app's
  /// away state, which a test moves.
  Future<FakeHostService> startBeat(
    WidgetTester tester, {
    bool phoneShows = false,
    ValueNotifier<bool>? appAway,
  }) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [
        readyCountdownProvider.overrideWithValue(Pausable.ready),
        if (appAway != null) hostAwayProvider.overrideWithValue(appAway),
      ],
    );
    fake.gameHost.hasViewers = phoneShows;
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await startRace(tester, fake);
    return fake;
  }

  /// The seconds the card shows, or null while it is not up.
  String? countShown(WidgetTester tester) => find.byKey(const Key('getReadyCount')).evaluate().isEmpty
      ? null
      : tester.widget<Text>(find.byKey(const Key('getReadyCount'))).data;

  testWidgets('the round is held for the beat: the card counts 3, 2, 1 and no step runs', (tester) async {
    await startBeat(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleScreen)));
    RoundPhase phase() => container.read(roundPhaseProvider).value;
    expect(find.byKey(const Key('getReady')), findsOneWidget);
    expect(phase(), RoundPhase.ready, reason: 'the beat holds the round');

    // The card counts the seconds down, and the rules step not once.
    final full = timeLeftMs(tester);
    final counted = <String>[];
    for (var i = 0; i < 400 && find.byKey(const Key('getReady')).evaluate().isNotEmpty; i++) {
      final count = countShown(tester);
      if (counted.isEmpty || counted.last != count) counted.add(count!);
      expect(timeLeftMs(tester), full, reason: 'the round is held: its clock stands still');
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(counted, ['3', '2', '1'], reason: 'the card shows the seconds left');

    // The beat ends and the round plays.
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.byKey(const Key('getReady')), findsNothing);
    expect(phase(), RoundPhase.playing, reason: 'the round plays when the beat is over');
    final running = timeLeftMs(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(timeLeftMs(tester), lessThan(running), reason: 'the round steps once the beat is over');
  });

  testWidgets('the round\'s first frame goes out before the beat holds it, so a phone draws the board', (tester) async {
    final fake = await startBeat(tester, phoneShows: true);
    final frames = fake.gameHost.frames;
    expect(find.byKey(const Key('getReady')), findsOneWidget);
    expect(frames, hasLength(1), reason: 'nothing has stepped: this is the board at step 0');
    expect(frames.single.n, -1, reason: 'the round has run no step: the frame is the round before its first');
    final board = MatchSnapshot.fromJson(frames.single.snapshot);
    expect(
      board.boards.first.timeLeftMs,
      timeLeftMs(tester),
      reason: 'the phone draws the round\'s clock, which the beat holds',
    );

    // The beat goes on: no step, and no frame after that one.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(frames, hasLength(1), reason: 'a held round sends no frame');
  });

  testWidgets('Start during the beat opens nothing, and the round goes on after it', (tester) async {
    final fake = await startBeat(tester);
    expect(find.byKey(const Key('getReady')), findsOneWidget);

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing, reason: 'the beat is no menu');
    expect(find.byKey(const Key('getReady')), findsOneWidget, reason: 'the beat goes on');

    // It runs out with no menu from that press.
    for (var i = 0; i < 400 && find.byKey(const Key('getReady')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.byKey(const Key('getReady')), findsNothing);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(find.byType(PuzzleScreen), findsOneWidget);
  });

  testWidgets('a round that waits during the beat holds the beat, and it starts again from 3', (tester) async {
    final appAway = ValueNotifier(false);
    final fake = await startBeat(tester, appAway: appAway);
    expect(countShown(tester), '3');

    // A second in, a phone drops: the round waits for it, so the beat waits too.
    for (var i = 0; i < 63; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await holdSlot(tester, fake, 'p2');
    expect(find.byKey(const Key('awayCard')), findsOneWidget);
    expect(countShown(tester), isNull, reason: 'the away card stands over the beat');

    // Two seconds on, the beat is still held.
    final held = timeLeftMs(tester);
    for (var i = 0; i < 125; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(timeLeftMs(tester), held, reason: 'the beat holds the round while it waits');

    // The phone is back: the beat starts again from the top.
    fake.gameHost.setAway('p2', isAway: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('awayCard')), findsNothing);
    expect(countShown(tester), '3', reason: 'the beat starts again once nothing waits');

    // The host app going away holds it the same way (m12 §2.10).
    appAway.value = true;
    await tester.pump();
    expect(countShown(tester), isNull, reason: 'the beat waits for the host too');
    await tester.pump(const Duration(seconds: 2));
    expect(countShown(tester), isNull);
    appAway.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(countShown(tester), '3', reason: 'and starts again from the top when the host is back');
  });

  testWidgets('with no beat asked for (the TV), there is no card and the round steps at once', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    fake.gameHost.hasViewers = true;
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await startRace(tester, fake);

    expect(find.byKey(const Key('getReady')), findsNothing, reason: 'no beat was asked for');
    expect(
      fake.gameHost.frames.first.n,
      0,
      reason: 'the round steps from its first frame, with no frame before step 0',
    );
    final running = timeLeftMs(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(timeLeftMs(tester), lessThan(running), reason: 'the round runs at once');
  });
}
