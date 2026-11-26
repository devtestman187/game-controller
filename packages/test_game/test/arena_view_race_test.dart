import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/bumper.dart';
import 'support/look.dart';
import 'support/maps.dart';

/// A host with phones [ids], each holding a controller that is joined.
MemoryGameHost hostFor(List<String> ids) {
  final host = MemoryGameHost();
  for (final (i, id) in ids.indexed) {
    host
      ..setPlayer(GamePlayer(id: id, number: i + 1, nickname: 'Phone $id', mode: InputMode.of(null)))
      ..setGamepad(id, GamepadState.fromInput(InputStateMessage(seq: 1)));
  }
  return host;
}

/// Builds an [ArenaView] of [game] on [host] and counts its [onFinished] calls in [finished].
Future<void> pumpView(WidgetTester tester, ArenaGame game, GameHost host, List<RoundResult> finished) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: withLook(
        Scaffold(
          body: ArenaView(game: game, host: host, onEvent: (_) {}, onFinished: finished.add),
        ),
      ),
    ),
  );
}

/// Pumps [frames] frames of 16 ms each, as the ticker runs them.
Future<void> pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a race goal does not finish the view: the race keeps playing', (tester) async {
    final game = ArenaGame(map: testMap(), size: const Size(1000, 500))
      ..join('a')
      ..join('b');
    while (game.phase == ArenaPhase.playing) {
      game.update(1 / 60, {'a': const GameInput(move: Offset(1, 0)), 'b': GameInput.none});
    }
    expect(game.roundResult, isNotNull, reason: 'the goal gives the race its result');

    final finished = <RoundResult>[];
    await pumpView(tester, game, hostFor(['a', 'b']), finished);
    await pumpFrames(tester, 60);
    expect(finished, isEmpty, reason: 'a race round is not the Bumper Round: the view does not finish');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Bumper Round whose clock runs out finishes the view once', (tester) async {
    final game = bumper(ids: const ['a', 'b']);
    while (game.phase == ArenaPhase.playing) {
      step(game, 1 / 60);
    }
    expect(game.phase, ArenaPhase.over, reason: 'the clock ran out');

    final finished = <RoundResult>[];
    await pumpView(tester, game, hostFor(['a', 'b']), finished);
    await pumpFrames(tester, 60);
    expect(finished, hasLength(1), reason: 'the Bumper Round ends once, with its result');
    expect(tester.takeException(), isNull);
  });
}
