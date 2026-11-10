import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/maps.dart';

import 'support/look.dart';

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
  group('snapshots and the host', snapshots);

  Future<(ArenaGame, List<GameEvent>)> pump(WidgetTester tester, GameHost host, Size size, {ArenaGame? arena}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = arena ?? ArenaGame();
    final events = <GameEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: withLook(
          Scaffold(
            body: ArenaView(game: game, host: host, onEvent: events.add),
          ),
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
    final (game, events) = await pump(tester, host, const Size(960, 540), arena: ArenaGame(map: testMap()));
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

  testWidgets('the bar folds to one line on a phone box and leaves the field most of the height', (tester) async {
    for (final box in const [Size(667, 375), Size(852, 393)]) {
      final host = hostWith({'a': InputStateMessage(seq: 1), 'b': InputStateMessage(seq: 1)});
      await pump(tester, host, box, arena: ArenaGame(map: testMap()));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull, reason: 'no overflow at $box');
      final bar = box.height - tester.getSize(find.byKey(const Key('arena'))).height;
      // 52 px: three runs of small text and 2 px of padding above and below.
      expect(bar, lessThanOrEqualTo(box.height * 0.15), reason: 'the bar shares $box with the field');
      expect(find.byKey(const Key('hud-a')), findsOneWidget);
      expect(find.byKey(const Key('hud-b')), findsOneWidget);
      // The runs abut: no row padding between the round and the players.
      expect(tester.getRect(find.text('P2 Phone b')).top, tester.getRect(find.text('P1 Phone a')).bottom);
    }
  });

  testWidgets('the bar keeps the round above the players in a tall box', (tester) async {
    final host = hostWith({'a': InputStateMessage(seq: 1), 'b': InputStateMessage(seq: 1)});
    const box = Size(960, 540);
    await pump(tester, host, box, arena: ArenaGame(map: testMap()));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 88 px: the round, then one row per player with 4 px above it.
    final bar = box.height - tester.getSize(find.byKey(const Key('arena'))).height;
    expect(bar, greaterThan(box.height * 0.15), reason: 'the one-line form is only for a phone box');
    expect(tester.getRect(find.text('P1 Phone a')).top, greaterThan(tester.getRect(find.text('Round 1')).bottom));
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
    final open = ArenaGame(map: testMap());
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
    final open = ArenaGame(map: testMap());
    final host = hostWith({'a': InputStateMessage(seq: 1, dx: 1)});
    final (game, _) = await pump(tester, host, const Size(960, 540), arena: open);
    for (var i = 0; i < 400 && game.phase == ArenaPhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.textContaining('Goal!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('input that waited out a stall in drawing is not counted as delay', (tester) async {
    final host = hostWith({'a': InputStateMessage(seq: 1)});
    await pump(tester, host, const Size(960, 540));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final before = host.stages.length;
    // Drawing stops for 2 s (window minimised); new input arrives meanwhile.
    host.setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 2, dx: 1)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(host.stages.length, before, reason: 'the frame after the stall is not measured');
    // Normal frames are measured again.
    host.setGamepad('a', GamepadState.fromInput(InputStateMessage(seq: 3, dx: -1)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(host.stages.length, before + 1);
  });

  testWidgets('reports rounds, game events, frames and the drawn delay stage to the host', (tester) async {
    final open = ArenaGame(map: testMap());
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

void snapshots() {
  testWidgets('events buzz the right phone and play their sound through the host (S5)', (tester) async {
    final host = hostWith({'a': InputStateMessage(seq: 1, dx: -1)});
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: withLook(
          Scaffold(
            body: ArenaView(host: host, onEvent: (_) {}),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(host.haptics.map((h) => (h.$1, h.$2.event)), contains(('a', HapticEvent.hit)));
    expect(host.sounds, contains('hit'));
  });

  test('a snapshot encodes, decodes and keeps everything the view draws (S8)', () {
    final game = ArenaGame()..resize(const Size(1280, 720));
    game.join('a');
    game.join('b');
    game.update(0.5, {'a': const GameInput(move: Offset(1, 0), aim: Offset(0.8, 0)), 'b': const GameInput(dash: true)});
    final s = game.snapshot();
    final back = ArenaSnapshot.decode(s.encode());
    expect(back.encode(), s.encode());
    expect(back.walls, hasLength(game.walls.length));
    expect(back.players.map((p) => p.id), ['a', 'b']);
    expect(back.player('a')!.aimX, isNotNull);
    expect(back.player('b')!.dashing, isTrue);
    // Fractions: the same snapshot draws the same way at any size.
    expect(back.player('a')!.x, inInclusiveRange(0, 1));
    expect(s.encode().length, lessThan(2048));
  });
}
