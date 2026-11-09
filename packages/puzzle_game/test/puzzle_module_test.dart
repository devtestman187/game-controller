import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/look.dart';

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
Widget draw(
  GameViewer viewer,
  MatchSnapshot snapshot, {
  String? playerId,
  bool wholeMatch = false,
  List<Rect> padRects = const [],
  double pxPerMm = phonePxPerMm,
}) => withLook(
  Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 960,
      height: 540,
      child: Builder(
        builder: (context) => viewer.build(context, snapshot, (
          roster: const {},
          playerId: playerId,
          wholeMatch: wholeMatch,
          padRects: padRects,
          pxPerMm: pxPerMm,
        )),
      ),
    ),
  ),
);

/// The camera the drawn [MatchView] paints with.
PuzzleCamera cameraOf(WidgetTester tester) => tester.widget<MatchView>(find.byType(MatchView)).camera;

/// The app's controls the drawn [MatchView] keeps clear of, as it was given them.
List<Rect> padRectsOf(WidgetTester tester) => tester.widget<MatchView>(find.byType(MatchView)).padRects;

/// The drawn [MatchView]'s px per millimetre, as it was given it.
double pxPerMmOf(WidgetTester tester) => tester.widget<MatchView>(find.byType(MatchView)).pxPerMm;

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

  test('the setup names the phones layout only for a phones match; a viewer reads it, a missing key means the '
      'screen, and another value names the key', () {
    final screen = PuzzleMatch(house(), teams: const {'p1': PuzzleSide.left}, random: Random(1));
    expect(shapeRaceSetup(screen).containsKey('layout'), isFalse, reason: 'the screen layout is the absent key');
    final phones = PuzzleMatch(
      house(),
      teams: const {'p1': PuzzleSide.left},
      random: Random(1),
      target: LayoutTarget.phones,
    );
    final phonesSetup = shapeRaceSetup(phones);
    expect(phonesSetup['layout'], phonesLayoutName);
    expect(
      shapeRaceModule.createViewer(phonesSetup),
      isA<ShapeRaceViewer>().having((v) => v.target, 'target', LayoutTarget.phones),
    );
    expect(
      shapeRaceModule.createViewer(Map.of(phonesSetup)..remove('layout')),
      isA<ShapeRaceViewer>().having((v) => v.target, 'target', LayoutTarget.screen),
    );
    expect(
      () => shapeRaceModule.createViewer({...phonesSetup, 'layout': 'diagonal'}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"layout"'))),
    );
  });

  // One test for all these viewers: the files load once per process, and a
  // future made in one test's fake clock never resolves in the next test's
  // (Q1), so every viewer that draws shares this one test.
  testWidgets('a known puzzle draws the match once the files load, with this phone\'s side of a phones match or the '
      'whole match; an unknown one says to update the app', (tester) async {
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

    // A phones match, and the camera each phone draws it with (m12-phone-
    // layout §2): its own side, or the whole match.
    const teams = <String, Object?>{'p1': 'left', 'p2': 'right'};
    final phones = shapeRaceModule.createViewer({...setup, 'teams': teams, 'layout': phonesLayoutName});
    final screen = shapeRaceModule.createViewer({...setup, 'teams': teams});
    final phonesSnapshot = PuzzleMatch(
      house(),
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      random: Random(1),
      target: LayoutTarget.phones,
    ).snapshot();

    await tester.pumpWidget(draw(phones, phonesSnapshot, playerId: 'p1'));
    await tester.pump();
    expect(cameraOf(tester), const PuzzleCamera.side(PuzzleSide.left));

    await tester.pumpWidget(draw(phones, phonesSnapshot, playerId: 'p2'));
    await tester.pump();
    expect(cameraOf(tester), const PuzzleCamera.side(PuzzleSide.right));

    await tester.pumpWidget(draw(phones, phonesSnapshot));
    await tester.pump();
    expect(cameraOf(tester), const PuzzleCamera.whole(), reason: 'this phone plays no side');

    await tester.pumpWidget(draw(phones, phonesSnapshot, playerId: 'p2', wholeMatch: true));
    await tester.pump();
    expect(cameraOf(tester), const PuzzleCamera.whole(), reason: 'a tablet draws both sides');

    await tester.pumpWidget(draw(screen, snapshot, playerId: 'p2'));
    await tester.pump();
    expect(cameraOf(tester), const PuzzleCamera.whole(), reason: 'the screen keeps today\'s picture');

    // The controls the app draws under the game reach the view as it passed
    // them, for the mirror to keep clear of (m12-opponent-mirror rule 3), and
    // so does its px per millimetre, which sizes the mirror's marks (rule 7).
    const pad = [Rect.fromLTWH(24, 250, 120, 120)];
    await tester.pumpWidget(draw(phones, phonesSnapshot, playerId: 'p1', padRects: pad));
    await tester.pump();
    expect(padRectsOf(tester), pad);
    await tester.pumpWidget(draw(phones, phonesSnapshot, playerId: 'p1', padRects: pad, pxPerMm: 8.5));
    await tester.pump();
    expect(pxPerMmOf(tester), 8.5);
  });
}
