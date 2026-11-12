import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

import 'support/host_harness.dart';

/// A Look change made in the middle of a round (M14 bug t1, Nov 12, 2026): it
/// shows at once, on the board the round already draws, and the round plays on
/// with its pieces, its clock and its points as they were.
void main() {
  final now = DateTime(2026, 11, 8, 12);
  final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);
  final night = ToyLook.build(palette: ToyPalette.night, tv: false);

  ProviderContainer containerOf(WidgetTester tester, Finder screen) =>
      ProviderScope.containerOf(tester.element(screen));

  testWidgets('a Look change in the middle of a Shape Race shows at once, and the round plays on', (tester) async {
    await openRace(tester, clock: () => now);
    final container = containerOf(tester, find.byType(PuzzleScreen));
    final play = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView));
    final match = play.match;
    final timeLeft = timeLeftMs(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    container.read(lookSettingsProvider.notifier).setChoice(LookChoice.night);
    await tester.pump();

    expect(container.read(lookPaletteProvider), ToyPalette.night, reason: 'the setting shows at once, mid-round too');
    final board = tester.widget<CustomPaint>(find.byKey(const Key('puzzleView'))).painter!;
    expect(board, isA<MatchPainter>(), reason: 'a race draws both boards through the match painter');
    expect((board as MatchPainter).look.palette, ToyPalette.night, reason: 'the boards draw the night colours');
    expect(identical(play.match, match), isTrue, reason: 'the same round: no restart');
    expect(timeLeftMs(tester), timeLeft, reason: 'its clock did not jump');
    expect(find.byType(PuzzleScreen), findsOneWidget);

    // The look alone makes a painter repaint: the new painter is the same one
    // in the Sunny look, with the round's snapshot and clock untouched.
    expect(
      MatchPainter(
        board.puzzle,
        board.s,
        look: sunny,
        moments: board.moments,
        workers: board.workers,
        nowMs: board.nowMs,
        timeLimitS: board.timeLimitS,
        target: board.target,
        camera: board.camera,
        padRects: board.padRects,
        pxPerMm: board.pxPerMm,
        fillsBackground: board.fillsBackground,
      ).shouldRepaint(board),
      isTrue,
      reason: 'only the look changed',
    );
    // The one-board painter a solo round draws with follows the look too.
    final one = play.snapshot.boards.first;
    final puzzle = play.widget.puzzle;
    expect(
      PuzzlePainter(puzzle, one, look: night).shouldRepaint(PuzzlePainter(puzzle, one, look: sunny)),
      isTrue,
      reason: 'the board painter repaints for the look alone',
    );
  });

  testWidgets('a Look change in the middle of a Bumper Round shows at once, and the round plays on', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome(), clock: () => now);
    await openArena(tester, fake);
    final container = containerOf(tester, find.byType(GameScreen));
    final field = arenaSnapshot(tester);
    expect(container.read(lookPaletteProvider), ToyPalette.sunny);

    container.read(lookSettingsProvider.notifier).setChoice(LookChoice.night);
    await tester.pump();

    expect(container.read(lookPaletteProvider), ToyPalette.night, reason: 'the setting shows at once, mid-round too');
    final board = tester.widget<CustomPaint>(find.byKey(const Key('arena'))).painter! as ArenaPainter;
    expect(board.look.palette, ToyPalette.night, reason: 'the field draws the night colours');
    // The round plays on: the same round of the same mode, with its players.
    expect(board.s.round, field.round, reason: 'the same round: no restart');
    expect(board.s.mode, field.mode);
    expect(board.s.players.length, field.players.length);
    expect(find.byType(GameScreen), findsOneWidget);

    expect(
      ArenaPainter(
        board.s,
        board.roster,
        look: sunny,
        moments: board.moments,
        fillsBackground: board.fillsBackground,
      ).shouldRepaint(board),
      isTrue,
      reason: 'only the look changed',
    );
  });
}
