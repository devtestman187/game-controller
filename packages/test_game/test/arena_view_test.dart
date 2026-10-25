import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

void main() {
  Future<(ArenaGame, List<GameEvent>)> pump(
    WidgetTester tester,
    InputStateMessage? Function() input,
    Size size, {
    ArenaGame? arena,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = arena ?? ArenaGame();
    final events = <GameEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: ArenaView(game: game, readInput: input, onEvent: events.add),
        ),
      ),
    );
    return (game, events);
  }

  testWidgets('runs every frame, follows the input and reports events', (tester) async {
    var held = InputStateMessage(seq: 1, dx: -1);
    final (game, events) = await pump(tester, () => held, const Size(960, 540));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(events.where((e) => e.cause == GameEventCause.wall), hasLength(1), reason: 'walked into the left edge');
    expect(find.text('Hits 1'), findsOneWidget);

    held = InputStateMessage(seq: 2, buttons: {ControllerButton.a});
    await tester.pump(const Duration(milliseconds: 16));
    expect(events.last.event, HapticEvent.rumble);
    expect(find.text('Dashes 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills a small or tall window and follows a resize', (tester) async {
    final (game, _) = await pump(tester, () => null, const Size(500, 700));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    expect(game.size.width, 500);
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.size.width, 1920);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the goal banner during the round break', (tester) async {
    final open = ArenaGame(walls: const [], hazards: const []);
    final (game, events) = await pump(
      tester,
      () => InputStateMessage(seq: 1, dx: 1),
      const Size(960, 540),
      arena: open,
    );
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase, ArenaPhase.won);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('Goal!'), findsOneWidget);
    expect(find.text('Wins 1'), findsOneWidget);
    expect(events.last.event, HapticEvent.success);
    expect(tester.takeException(), isNull);
  });
}
