import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:tvtest/src/debug_start.dart';
import 'package:tvtest/src/ui/home/home_screen.dart';

import 'support/pump_app.dart';

/// A host like a TV that has just started: running, nobody connected yet.
HostViewState noControllers() => const HostViewState(
  hostName: 'Android TV',
  host: HostSnapshot(running: true, port: 45780, pairingCode: '0427', controllers: []),
);

void main() {
  test('only the two games a define names start without the menus', () {
    // A test run has no --dart-define, and is a debug build.
    expect(startGame, '');
    expect(debugStartScreen(''), isNull);
    expect(debugStartScreen('puzzle'), isNull);
    expect(debugStartScreen('arena'), isNotNull);
    expect(debugStartScreen('shape_race'), isNotNull);
  });

  test('SHARE_VIEW shares the game only in a debug build that passes it', () {
    expect(shareViewDefine, isFalse, reason: 'a test run has no --dart-define');
    expect(shareViewEnabled(), isFalse);
    expect(shareViewEnabled(defined: true), isTrue, reason: 'SHARE_VIEW=true in a debug build');
    expect(shareViewEnabled(defined: false), isFalse, reason: 'SHARE_VIEW=false shares nothing, as absent does');
    expect(shareViewEnabled(debug: false, defined: true), isFalse, reason: 'a release build ignores it');
  });

  testWidgets('without START_GAME the app opens on the home screen', (tester) async {
    await pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('START_GAME=arena starts in the arena, with no menus in between', (tester) async {
    // The arena runs a game from the first frame: it never settles.
    await pumpApp(tester, game: 'arena', state: noControllers(), settle: false);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('No controller connected. Pair a phone on the main screen.'), findsOneWidget);
  });

  testWidgets('START_GAME=shape_race waits for a controller, then plays the first Easy puzzle', (tester) async {
    final fake = await pumpApp(tester, game: 'shape_race', state: noControllers());
    expect(find.text('Waiting for a controller…'), findsOneWidget);
    expect(find.byType(PuzzleScreen), findsNothing);

    fake.state = withController(noControllers(), phoneInfo('p9', 1));
    fake.emit();
    // The puzzle runs from the first frame: the screen never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final screen = tester.widget<PuzzleScreen>(find.byType(PuzzleScreen));
    expect(screen.choice.level, Level.easy);
    expect(screen.choice.puzzleId, testPuzzles().ofLevel(Level.easy).first.id);
    expect(screen.teams, {'p9': PuzzleSide.left});
  });
}
