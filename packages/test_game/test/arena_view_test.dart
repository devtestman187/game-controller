import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

/// A host with phones [ids] (numbered in order), each holding [input].
MemoryGameHost hostWith(Map<String, InputStateMessage?> players) {
  final host = MemoryGameHost();
  for (final (i, MapEntry(key: id, value: input)) in players.entries.indexed) {
    host
      ..setPlayer(GamePlayer(id: id, number: i + 1, nickname: 'Phone $id', mode: InputMode.of(input)))
      ..setGamepad(id, GamepadState.fromInput(input));
  }
  return host;
}

void main() {
  Future<(ArenaGame, List<GameEvent>)> pump(WidgetTester tester, GameHost host, Size size, {ArenaGame? arena}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = arena ?? ArenaGame();
    final events = <GameEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: ArenaView(game: game, host: host, onEvent: events.add),
        ),
      ),
    );
    return (game, events);
  }

  testWidgets('runs every frame, follows the input and reports events', (tester) async {
    final host = hostWith({'a': InputStateMessage(seq: 1, dx: -1)});
    final (game, events) = await pump(tester, host, const Size(960, 540));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(events.where((e) => e.cause == GameEventCause.wall), hasLength(1), reason: 'walked into the left edge');
    expect(events.single.playerId, 'a');
    expect(find.text('Hits 1'), findsOneWidget);
    expect(find.text('P1 Phone a'), findsOneWidget);

    host.setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 2, buttons: {ControllerButton.a})));
    await tester.pump(const Duration(milliseconds: 16));
    expect(events.last.event, HapticEvent.rumble);
    expect(find.text('Dashes 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two controllers get a sprite and a counter row each', (tester) async {
    final host = hostWith({
      'a': InputStateMessage(seq: 1, dx: -1),
      'b': InputStateMessage(seq: 1, buttons: {ControllerButton.a}),
    });
    final (game, events) = await pump(
      tester,
      host,
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

  testWidgets('a keyboard player on the host plays like any other', (tester) async {
    final host = hostWith({'a': InputStateMessage(seq: 1)});
    final keyboard = host.addLocalPlayer(nickname: 'Keyboard')
      ..set(const GamepadState(buttons: {GamepadButton.dpadLeft}, mode: InputMode.keyboard));
    final (game, events) = await pump(tester, host, const Size(960, 540));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.players.map((p) => p.id), ['a', keyboard.id]);
    expect(events.where((e) => e.playerId == keyboard.id && e.cause == GameEventCause.wall), hasLength(1));
    expect(find.text('P2 Keyboard'), findsOneWidget);
  });

  testWidgets('fills a small or tall window and follows a resize', (tester) async {
    final (game, _) = await pump(tester, MemoryGameHost(), const Size(500, 700));
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
    // a starts in the middle row, level with the goal; b stands still.
    final host = hostWith({'a': InputStateMessage(seq: 1, dx: 1), 'b': InputStateMessage(seq: 1)});
    final (game, events) = await pump(tester, host, const Size(960, 540), arena: open);
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase, ArenaPhase.won);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('P1 wins!'), findsOneWidget);
    expect(find.byKey(const Key('wins-a')), findsOneWidget);
    expect(find.text('Wins 1'), findsOneWidget);
    expect(events.last.event, HapticEvent.success);
    expect(events.last.playerId, 'a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('one player sees "Goal!" rather than a winner', (tester) async {
    final open = ArenaGame(walls: const [], hazards: const []);
    final host = hostWith({'a': InputStateMessage(seq: 1, dx: 1)});
    final (game, _) = await pump(tester, host, const Size(960, 540), arena: open);
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('Goal!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports rounds, game events, frames and the drawn delay stage to the host', (tester) async {
    final open = ArenaGame(walls: const [], hazards: const []);
    final host = hostWith({'a': InputStateMessage(seq: 1, dx: 1, ax: null)});
    final (game, _) = await pump(tester, host, const Size(960, 540), arena: open);
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 16));
    final names = host.records.map((r) => r.name).toList();
    expect(names.first, 'round_start');
    expect(names, containsAllInOrder(['round_start', 'goal', 'round_end', 'frames']));
    final end = host.records.firstWhere((r) => r.name == 'round_end');
    expect(end.game, arenaGame);
    expect(end.data['winner'], 'a');
    expect(end.data['modes'], {'a': 'dpad'});
    expect(end.data['timeS'], isA<double>());
    final frames = host.records.firstWhere((r) => r.name == 'frames');
    expect(frames.data['drawn'], greaterThan(10));
    // The input arrived once, so one "received to drawn" sample.
    expect(host.stages.where((s) => s.stage == LatencyStage.receivedToDrawn && s.playerId == 'a'), hasLength(1));
  });
}
