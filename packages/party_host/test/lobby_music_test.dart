import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// Puts the app back to resumed once the test ends, however it left it: the
/// music of a later test then starts where it should. The binding checks the
/// system's moves in debug, so the walk is the one Android makes.
void restoreLifecycle(WidgetTester tester) {
  addTearDown(() {
    final binding = tester.binding;
    if (binding.lifecycleState == AppLifecycleState.paused) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    if (binding.lifecycleState == AppLifecycleState.hidden) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    if (binding.lifecycleState != AppLifecycleState.resumed) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });
}

/// The lobby music (M13 design section 8): the host plays it while the game
/// picker is open and no round is, so it carries on unbroken to the join screen,
/// a round stops it, and it comes back when the round's screens close. Music
/// off and a hidden app stop it; joined phones never play it, which their own
/// app's tests pin.
void main() {
  /// Home → Play: the picker, and with it a lobby.
  Future<void> openPicker(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const Key('openPlay')));
    await tester.pumpAndSettle();
  }

  testWidgets('the picker starts the loop once, and the join screen keeps it', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    expect(sounds.loop, isNull, reason: 'the TV home is no lobby (M13 section 8)');
    expect(sounds.loopStarts, isEmpty);

    await openPicker(tester);
    expect(sounds.loop, 'lobby');
    expect(sounds.loopStarts, ['lobby']);

    // The Shape Race list and the join screen are pushed over the picker: the
    // music carries on without a restart.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('puzzle-house')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(sounds.loop, 'lobby');
    expect(sounds.loopStarts, ['lobby'], reason: 'the music carries on unbroken');
  });

  testWidgets('a round stops it, Play again keeps it off, and Change teams starts it again', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openJoin(tester);
    expect(sounds.loop, 'lobby');

    await startRound(tester, fake);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(sounds.loop, isNull, reason: 'the round stops the music');
    expect(sounds.loopStarts, ['lobby']);

    // Play again replaces the round's screen with another in one frame: the
    // music was off and stays off, with no stop and start in between.
    lockEveryPiece(tester);
    await endRound(tester);
    await tester.tap(find.byKey(const Key('playAgain')));
    await navigated(tester);
    expect(find.byType(PuzzleScreen), findsOneWidget);
    expect(sounds.loop, isNull, reason: 'Play again keeps it off');
    expect(sounds.loopStarts, ['lobby']);

    // Back on the join screen, with the picker still under it, it comes back.
    lockEveryPiece(tester);
    await endRound(tester);
    await tester.tap(find.byKey(const Key('changeTeams')));
    await navigated(tester);
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(sounds.loop, 'lobby', reason: 'the join screen is a lobby again');
    expect(sounds.loopStarts, ['lobby', 'lobby']);
  });

  testWidgets(
    'Music at 0% stops the loop on the picker, turned up starts it again, and Mute leaves it running silent',
    (tester) async {
      await pumpHost(tester, screen: const StubHome());
      await openPicker(tester);
      expect(sounds.loop, 'lobby');
      final container = ProviderScope.containerOf(tester.element(find.byType(GamesScreen)));

      container.read(soundSettingsProvider.notifier).setMusicVolume(0);
      await tester.pump();
      expect(sounds.loop, isNull, reason: 'Music at 0% stops it');

      container.read(soundSettingsProvider.notifier).setMusicVolume(50);
      await tester.pump();
      expect(sounds.loop, 'lobby', reason: 'and turned up starts it again');
      expect(sounds.loopStarts, ['lobby', 'lobby']);

      // Mute silences it through the volume and leaves it running, so unmuting
      // carries on where the music is rather than from its start.
      container.read(soundSettingsProvider.notifier).setMuted(true);
      await tester.pump();
      expect(sounds.loop, 'lobby');
      expect(sounds.loopStarts, ['lobby', 'lobby']);
    },
  );

  testWidgets('a hidden app stops the music, and it starts again when shown', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    restoreLifecycle(tester);
    await openPicker(tester);
    expect(sounds.loop, 'lobby');

    // Android reports a backgrounded app as inactive first.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(sounds.loop, isNull, reason: 'a hidden app plays no music');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sounds.loop, 'lobby', reason: 'and showing it starts the music again');
  });

  testWidgets('two changes in one frame make no start', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await openPicker(tester);
    expect(sounds.loopStarts, ['lobby']);
    final music = ProviderScope.containerOf(tester.element(find.byType(GamesScreen))).read(lobbyMusicProvider);

    // A change that ends where it began: the music must not stop and start.
    music.closeLobby();
    music.openLobby();
    await tester.pump();
    expect(sounds.loop, 'lobby');
    expect(sounds.loopStarts, ['lobby'], reason: 'the frame settled on what was already playing');
  });
}
