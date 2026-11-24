import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/look.dart';
import 'support/mirror_helpers.dart';
import 'support/portrait_pads.dart';

/// The camera a tablet draws the boat race with: its own left side, as a phone
/// with one side draws it (m12-phone-layout §2).
const ownSide = PuzzleCamera.side(PuzzleSide.left);

final boat = load('boat');

/// A two-side race on phones, as a tablet is sent it.
final raceSnapshot = PuzzleMatch(
  boat,
  teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right},
  random: Random(1),
  target: LayoutTarget.phones,
).snapshot();

/// The [MatchView] of the race drawn in [box] by a tablet, with [pad] under it.
Widget tablet(Size box, {required bool wholeIfNoMirror, List<Rect> pad = const [], PuzzleCamera camera = ownSide}) =>
    withLook(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.fromSize(
            size: box,
            child: MatchView(
              puzzle: boat,
              snapshot: raceSnapshot,
              target: LayoutTarget.phones,
              camera: camera,
              padRects: pad,
              pxPerMm: iPadPxPerMm,
              wholeIfNoMirror: wholeIfNoMirror,
            ),
          ),
        ),
      ),
    );

/// Makes the test's window [box] px, so the view is laid out at that size.
void useBox(WidgetTester tester, Size box) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = box;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The camera the painter [tester] drew the view with.
PuzzleCamera paintedCamera(WidgetTester tester) =>
    (tester.widget<CustomPaint>(find.byKey(const Key('puzzleView'))).painter! as MatchPainter).camera;

/// The mirror [box] draws for the race's own seed and HUD text, with [pad] under it.
MirrorPlacement? mirrorIn(Size box, List<Rect> pad) {
  final text = phoneHud(raceSnapshot, PuzzleSide.left);
  return PuzzleCamera.mirrorPlace(
    boat,
    SplitLayout.of(boat, raceSnapshot.seed!, target: LayoutTarget.phones),
    ownSide,
    box,
    split: true,
    text: (score: text.score, short: text.short),
    pxPerMm: iPadPxPerMm,
    padRects: pad,
  );
}

void main() {
  // The premises: a mirror fits the landscape iPad at 1366 x 1024 with the stick
  // pad, and not at 1180 x 820 (B-041 report, the owner's tablet sizes).
  test('the stick pad leaves a mirror room at 1366 x 1024 and none at 1180 x 820', () {
    expect(mirrorIn(const Size(1366, 1024), iPadLandscapePad), isNotNull);
    expect(mirrorIn(const Size(1180, 820), iPadSmallLandscapePad), isNull, reason: 'seed ${raceSnapshot.seed}');
  });

  testWidgets('a tablet with room for the other side\'s mirror draws its own side, with the mirror (B-041)', (
    tester,
  ) async {
    useBox(tester, const Size(1366, 1024));
    await tester.pumpWidget(tablet(const Size(1366, 1024), wholeIfNoMirror: true, pad: iPadLandscapePad));
    expect(paintedCamera(tester), ownSide, reason: 'a mirror fits at 1366 x 1024');
  });

  testWidgets('a tablet with no room for the other side\'s mirror draws the whole match (B-041)', (tester) async {
    useBox(tester, const Size(1180, 820));
    await tester.pumpWidget(tablet(const Size(1180, 820), wholeIfNoMirror: true, pad: iPadSmallLandscapePad));
    expect(paintedCamera(tester), const PuzzleCamera.whole(), reason: 'no mirror fits at 1180 x 820');
  });

  testWidgets('without wholeIfNoMirror the view keeps its own side where no mirror fits', (tester) async {
    useBox(tester, const Size(1180, 820));
    await tester.pumpWidget(tablet(const Size(1180, 820), wholeIfNoMirror: false, pad: iPadSmallLandscapePad));
    expect(paintedCamera(tester), ownSide, reason: 'the rule is off, so the side stays');
  });
}
