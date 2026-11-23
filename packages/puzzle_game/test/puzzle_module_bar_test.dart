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
  'teams': <String, Object?>{'p1': 'left', 'p2': 'right'},
  'layout': phonesLayoutName,
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

/// A phones match, as the host shares it: both players' sides, so the view
/// draws the whole match with its phones layout.
final phonesSnapshot = PuzzleMatch(
  house(),
  teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
  random: Random(1),
  target: LayoutTarget.phones,
).snapshot();

/// The viewer's game in a [width] x [height] box, as a joined phone draws it.
/// The box is keyed so a test can measure the match against it.
Widget draw(
  GameViewer viewer,
  MatchSnapshot snapshot, {
  required double width,
  required double height,
  List<Rect> padRects = const [],
}) => withLook(
  Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      key: const ValueKey('box'),
      width: width,
      height: height,
      child: Builder(
        builder: (context) => viewer.build(context, snapshot, (
          roster: const {},
          characters: const {},
          playerId: 'p1',
          wholeMatch: false,
          padRects: padRects,
          pxPerMm: phonePxPerMm,
        )),
      ),
    ),
  ),
);

/// The drawn [MatchView]'s top edge, measured from the top of the box.
double matchTopOf(WidgetTester tester) =>
    tester.getTopLeft(find.byType(MatchView)).dy - tester.getTopLeft(find.byKey(const ValueKey('box'))).dy;

/// The drawn [MatchView]'s height.
double matchHeightOf(WidgetTester tester) => tester.getSize(find.byType(MatchView)).height;

/// The app's controls the drawn [MatchView] keeps clear of, as it was given them.
List<Rect> padRectsOf(WidgetTester tester) => tester.widget<MatchView>(find.byType(MatchView)).padRects;

void main() {
  // The joined phone's top bar covers the top 52 px (controller_app
  // topBarHeightPx), so the match and the controls it keeps clear of move down
  // under it. The host phone draws PuzzleScreen instead, so only this viewer
  // is checked here.
  const pad = [Rect.fromLTWH(24, 250, 120, 120)];

  // One test for every box: the puzzle files load once per process, and a
  // future made in one test's fake clock never resolves in the next (see
  // puzzle_module_test.dart). The view is sized to each box, since the default
  // test surface is 800 x 600 and would clamp a 852-high box.
  testWidgets('a joined phone draws the match below its 52 px top bar at both phone sizes, with the controls shifted '
      'up by 52; a screen match keeps the top of its box', (tester) async {
    servePuzzles();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final viewer = shapeRaceModule.createViewer(setup);
    for (final box in const [Size(852, 393), Size(393, 852)]) {
      tester.view.physicalSize = box;
      await tester.pumpWidget(draw(viewer, phonesSnapshot, width: box.width, height: box.height, padRects: pad));
      await tester.pump();
      expect(find.byType(MatchView), findsOneWidget);
      expect(matchTopOf(tester), 52, reason: 'the bar covers the top 52 px of ${box.width} x ${box.height}');
      expect(matchHeightOf(tester), box.height - 52, reason: 'the match fills the room below the bar');
      expect(padRectsOf(tester), [const Rect.fromLTWH(24, 198, 120, 120)], reason: 'the pad is in the whole box');
    }

    final screen = shapeRaceModule.createViewer({...setup}..remove('layout'));
    final screenSnapshot = PuzzleMatch(
      house(),
      teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
      random: Random(1),
    ).snapshot();
    tester.view.physicalSize = const Size(852, 393);
    await tester.pumpWidget(draw(screen, screenSnapshot, width: 852, height: 393, padRects: pad));
    await tester.pump();
    expect(matchTopOf(tester), 0);
    expect(matchHeightOf(tester), 393);
    expect(padRectsOf(tester), pad);
  });
}
