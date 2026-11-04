import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// The demo director's hook (docs/demo-video-runbook.md 2.2): the view tells it
/// which arena game is running, once, and when that game is gone.
void main() {
  late List<ArenaGame> created;
  late List<ArenaGame> disposed;

  setUp(() {
    created = [];
    disposed = [];
    onArenaGameCreated = created.add;
    onArenaGameDisposed = disposed.add;
  });

  tearDown(() {
    onArenaGameCreated = null;
    onArenaGameDisposed = null;
  });

  Future<void> pumpView(WidgetTester tester, {ArenaGame? game}) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArenaView(host: MemoryGameHost(), onEvent: (_) {}, game: game),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('the hook gets the game the view made, once, and loses it on dispose', (tester) async {
    await pumpView(tester);

    expect(created, hasLength(1));

    // Another frame rebuilds the view but doesn't make a second game.
    await tester.pump(const Duration(milliseconds: 16));
    expect(created, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    expect(disposed, hasLength(1));
    expect(identical(disposed.single, created.single), isTrue);
  });

  testWidgets('a game passed in is the one the hook gets', (tester) async {
    final game = ArenaGame(walls: const [], hazards: const []);
    await pumpView(tester, game: game);

    expect(created, hasLength(1));
    expect(identical(created.single, game), isTrue);
  });
}
