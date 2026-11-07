import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:puzzle_game/puzzle_game.dart';

Puzzle house() => Puzzle.parse(File('puzzles/house.json').readAsStringSync());

const setup = <String, Object?>{
  'puzzle': 'house',
  'level': 'easy',
  'timeLimitS': 120,
  'teams': <String, Object?>{'p1': 'left'},
};

/// Serves this package's puzzle files as the app's assets, so the viewer's one
/// cached load resolves inside the test clock instead of waiting on the disk.
void servePuzzles() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
    final file = File('puzzles/${key.split('/').last}');
    return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
  });
  addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
}

/// The viewer's game in a 960 x 540 box, as a phone would draw it.
Widget draw(GameViewer viewer, MatchSnapshot snapshot) => Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(
    width: 960,
    height: 540,
    child: Builder(builder: (context) => viewer.build(context, snapshot, (roster: const {}, playerId: null))),
  ),
);

void main() {
  final snapshot = PuzzleMatch(house(), teams: const {'p1': PuzzleSide.left}, random: Random(1)).snapshot();

  test('the module is shape_race with the match snapshot version', () {
    expect(shapeRaceModule.id, 'shape_race');
    expect(shapeRaceModule.snapshotVersion, MatchSnapshot.version);
    final viewer = shapeRaceModule.createViewer(setup);
    expect(viewer.decode(snapshot.toJson()), isA<MatchSnapshot>());
  });

  test('a setup with a missing key or a wrong type throws FormatException naming it', () {
    expect(() => shapeRaceModule.createViewer(Map.of(setup)..remove('teams')), throwsFormatException);
    expect(() => shapeRaceModule.createViewer(Map.of(setup)..remove('puzzle')), throwsFormatException);
    expect(
      () => shapeRaceModule.createViewer({...setup, 'puzzle': 7}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"puzzle"'))),
    );
    expect(
      () => shapeRaceModule.createViewer({...setup, 'timeLimitS': '120'}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"timeLimitS"'))),
    );
    expect(
      () => shapeRaceModule.createViewer({
        ...setup,
        'teams': {'p1': 3},
      }),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"teams"'))),
    );
  });

  // One test for both viewers: the files load once per process, and a future
  // made in one test's fake clock never resolves in the next test's (Q1).
  testWidgets('a known puzzle draws the match once the files load; an unknown one says to update the app', (
    tester,
  ) async {
    servePuzzles();
    await tester.pumpWidget(draw(shapeRaceModule.createViewer(setup), snapshot));
    expect(find.byType(MatchView), findsNothing, reason: 'nothing is drawn before the files load');
    await tester.pump();
    expect(find.byType(MatchView), findsOneWidget);
    expect(find.text('Update the app to see this game'), findsNothing);

    final unknown = shapeRaceModule.createViewer({...setup, 'puzzle': 'no_such_puzzle'});
    await tester.pumpWidget(draw(unknown, snapshot));
    await tester.pump();
    expect(find.text('Update the app to see this game'), findsOneWidget);
    expect(find.byType(MatchView), findsNothing);
  });
}
