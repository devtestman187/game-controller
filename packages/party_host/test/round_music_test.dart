import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_harness.dart';

/// The round's music (M13 design section 8): the host plays it from the round's
/// "go" to its results, it speeds up as Shape Race's clock runs out, a pause
/// keeps it where it was, and Music at 0% or Mute silence it like the lobby's.
/// A joined phone never plays it, which the phone app's own tests pin.
void main() {
  /// Home → Play → Shape Race → the house puzzle with P1 on the left: the round
  /// is playing when this returns, and its music has started.
  Future<FakeHostService> openRound(WidgetTester tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    await startRound(tester, fake);
    return fake;
  }

  /// The round's rules, to move its clock by hand.
  PuzzleMatch match(WidgetTester tester) => tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;

  /// Moves the round's clock to [seconds] left, and lets a frame pass.
  Future<void> setClock(WidgetTester tester, double seconds) async {
    match(tester).gameOf(PuzzleSide.left).timeLeftS = seconds;
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('the lobby\'s music gives way to the round\'s at go', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    expect(sounds.loop, 'lobby', reason: 'the join screen is a lobby');
    expect(sounds.loopStarts, ['lobby'], reason: 'and no round music plays before a round');

    await startRound(tester, fake);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(sounds.loop, 'round', reason: 'the round\'s music starts at its go');
    expect(sounds.loopStarts, ['lobby', 'round']);
    expect(sounds.loopStops.last, Duration.zero, reason: 'the lobby stops at once, so the two never play together');
  });

  testWidgets('the music hurries at the warning and runs at the last third, keeping its place', (tester) async {
    await openRound(tester);
    expect(sounds.loop, 'round');
    expect(sounds.loopSwitches.last, (name: 'round', at: 0.0, fade: Duration.zero), reason: 'it starts from the top');

    // warningS is 15 s: more than that left is the first tempo, 15 s or less
    // the hurry, and a third of it (5 s) or less the final one.
    sounds.share = 0.4;
    await setClock(tester, 14.9);
    expect(sounds.loop, 'round_hurry');
    expect(sounds.loopSwitches.last, (
      name: 'round_hurry',
      at: 0.4,
      fade: HostMusic.switchFade,
    ), reason: 'the new loop starts at the same share, cross-faded');

    sounds.share = 0.4;
    await setClock(tester, 4.9);
    expect(sounds.loop, 'round_final');
    expect(sounds.loopSwitches.last, (name: 'round_final', at: 0.4, fade: HostMusic.switchFade));

    sounds.share = 0.2;
    await setClock(tester, 20);
    expect(sounds.loop, 'round', reason: 'more than the warning left: back to the first tempo');
    expect(sounds.loopSwitches.last, (name: 'round', at: 0.2, fade: HostMusic.switchFade));
  });

  testWidgets('the Arena has no clock, so its music stays at the first tempo', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await openArena(tester);
    expect(sounds.loop, 'round', reason: 'the Arena\'s round plays the music too');
    final switches = sounds.loopSwitches.length;

    // Half a minute of the Arena: its fans, its dashing marbles, no clock.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(sounds.loop, 'round');
    expect(sounds.loopSwitches, hasLength(switches), reason: 'one start, and no tempo change');
  });

  testWidgets('the results end the round\'s music with a short fade', (tester) async {
    await openRound(tester);
    expect(sounds.loop, 'round');

    lockEveryPiece(tester);
    await endRound(tester);
    expect(find.byKey(const Key('playAgain')), findsOneWidget);
    expect(sounds.loop, isNull, reason: 'the results end it, so success is heard clearly');
    expect(sounds.loopStops.last, HostMusic.resultsFade);
  });

  testWidgets('a paused round pauses its music, and resuming carries on where it was', (tester) async {
    final fake = await openRound(tester);
    // Past the grace the round allows Start (Pausable.startGrace).
    await tester.pump(const Duration(milliseconds: 600));
    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsOneWidget);
    expect(sounds.loop, 'round', reason: 'the music stays, silent where it was');
    expect(sounds.loopPaused, isTrue);

    await press(tester, fake, 'p1', GamepadButton.start);
    await navigated(tester);
    expect(find.byKey(const Key('pauseMenu')), findsNothing);
    expect(sounds.loopPaused, isFalse);
    expect(sounds.loop, 'round');
    expect(sounds.loopStarts, ['lobby', 'round'], reason: 'the same loop carried on, never restarted');
  });

  testWidgets('Music at 0% stops the round\'s music, and turning it up starts it again', (tester) async {
    await openRound(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(PuzzleScreen)));

    container.read(soundSettingsProvider.notifier).setMusicVolume(0);
    await tester.pump();
    expect(sounds.loop, isNull, reason: 'Music at 0% is no music in a round either');

    container.read(soundSettingsProvider.notifier).setMusicVolume(60);
    await tester.pump();
    expect(sounds.loop, 'round', reason: 'and turned up starts it again');

    // Mute silences it through the volume and leaves it running (design
    // section 8), as it does the lobby's.
    container.read(soundSettingsProvider.notifier).setMuted(true);
    await tester.pump();
    expect(sounds.loop, 'round');
  });

  // m13.3's fix (df2eec9) made Play again's own 3-2-1 sound: the new round's
  // music must start at its "go" too, after that beat, and the old round must
  // not stop it on its way out.
  testWidgets('Play again starts the new round\'s music at its own go, after its 3-2-1', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [readyCountdownProvider.overrideWithValue(Pausable.ready)],
    );
    fake.state = withController(fake.state, phoneInfo('p2', 2));
    fake.emit();
    await neutral(tester, fake, ['p1', 'p2']);
    await openJoin(tester);
    await startRace(tester, fake);
    expect(find.byKey(const Key('getReady')), findsOneWidget);
    expect(sounds.loop, isNull, reason: 'the 3-2-1 is no music yet');
    expect(sounds.loopStops, [Duration.zero], reason: 'the lobby stopped when the round opened');

    for (var i = 0; i < 400 && find.byKey(const Key('getReady')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 32));
    expect(sounds.loop, 'round', reason: 'the round\'s music starts at its go');

    lockEveryPiece(tester);
    await endRound(tester);
    await navigated(tester);
    expect(sounds.loop, isNull, reason: 'the results stop it');

    await tester.tap(find.byKey(const Key('rematch')));
    await navigated(tester);
    expect(find.byKey(const Key('getReady')), findsOneWidget, reason: 'the new round has its own beat');
    expect(sounds.loop, isNull, reason: 'the new round\'s music waits for its own go');
    expect(
      sounds.played.where((name) => name == SoundKey.countdown.eventName).length,
      2,
      reason: 'the 3-2-1 still plays with the new round',
    );

    for (var i = 0; i < 400 && find.byKey(const Key('getReady')).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 32));
    expect(sounds.loop, 'round', reason: 'the new round\'s music starts at its go');
    expect(sounds.loopStops, [Duration.zero, HostMusic.resultsFade], reason: 'the old round stopped nothing of it');
  });
}
