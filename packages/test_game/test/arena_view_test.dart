import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

PlayerFeed feed(String id, int number, InputStateMessage? input) =>
    (id: id, number: number, name: 'Phone $id', color: Color(playerColor(number)), input: input);

void main() {
  Future<(ArenaGame, List<GameEvent>)> pump(
    WidgetTester tester,
    List<PlayerFeed> Function() players,
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
          body: ArenaView(game: game, readPlayers: players, onEvent: events.add),
        ),
      ),
    );
    return (game, events);
  }

  testWidgets('runs every frame, follows the input and reports events', (tester) async {
    var held = InputStateMessage(seq: 1, dx: -1);
    final (game, events) = await pump(tester, () => [feed('a', 1, held)], const Size(960, 540));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(events.where((e) => e.cause == GameEventCause.wall), hasLength(1), reason: 'walked into the left edge');
    expect(events.single.playerId, 'a');
    expect(find.text('Hits 1'), findsOneWidget);
    expect(find.text('P1 Phone a'), findsOneWidget);

    held = InputStateMessage(seq: 2, buttons: {ControllerButton.a});
    await tester.pump(const Duration(milliseconds: 16));
    expect(events.last.event, HapticEvent.rumble);
    expect(find.text('Dashes 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two controllers get a sprite and a counter row each', (tester) async {
    final (game, events) = await pump(
      tester,
      () => [
        feed('a', 1, InputStateMessage(seq: 1, dx: -1)),
        feed('b', 2, InputStateMessage(seq: 1, buttons: {ControllerButton.a})),
      ],
      const Size(960, 540),
      arena: ArenaGame(walls: const [], hazards: const []),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.players.map((p) => p.id), ['a', 'b']);
    expect(find.byKey(const Key('hud-a')), findsOneWidget);
    expect(find.byKey(const Key('hud-b')), findsOneWidget);
    expect(events.where((e) => e.playerId == 'a').map((e) => e.event), [HapticEvent.hit]);
    expect(events.where((e) => e.playerId == 'b').map((e) => e.event), [HapticEvent.rumble]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fills a small or tall window and follows a resize', (tester) async {
    final (game, _) = await pump(tester, () => const [], const Size(500, 700));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    expect(game.size.width, 500);
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.size.width, 1920);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows who won during the round break', (tester) async {
    final open = ArenaGame(walls: const [], hazards: const []);
    final (game, events) = await pump(
      tester,
      // b joins first, so it starts in the middle row, level with the goal.
      () => [feed('b', 2, InputStateMessage(seq: 1, dx: 1)), feed('a', 1, InputStateMessage(seq: 1))],
      const Size(960, 540),
      arena: open,
    );
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase, ArenaPhase.won);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('P2 wins!'), findsOneWidget);
    expect(find.byKey(const Key('wins-b')), findsOneWidget);
    expect(find.text('Wins 1'), findsOneWidget);
    expect(events.last.event, HapticEvent.success);
    expect(events.last.playerId, 'b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('one player sees "Goal!" rather than a winner', (tester) async {
    final open = ArenaGame(walls: const [], hazards: const []);
    final (game, _) = await pump(
      tester,
      () => [feed('a', 1, InputStateMessage(seq: 1, dx: 1))],
      const Size(960, 540),
      arena: open,
    );
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('Goal!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
