import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The look the badge is drawn in.
final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// The badge the pixel tests paint: [_diameter] across, centred here.
const _centre = Offset(100, 100);
const _diameter = 80.0;

/// The square round the middle the digit is drawn in: 20 to either side of
/// the centre, where the digit's ink sits (its font is 55% of the diameter) and
/// well inside the disc, whose edge is 34 from the centre.
const _middleHalf = 20;

/// A point inside the disc above the digit, to read the player's colour from.
const _discSample = (100, 70);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unnumbered badge paints no digit: its middle is the player\'s colour all through', () async {
    final pixels = await paintedPixels(
      const Size(200, 200),
      (canvas) => paintToyBadge(canvas, _centre, _diameter, 2, _sunny, numbered: false),
    );
    // Player 2's orange, as the numbered badge in toy_badge_test.dart reads it.
    expect(pixels.at(_discSample.$1, _discSample.$2), (255, 138, 31));
    final mismatched = _middleMismatches(pixels, (255, 138, 31));
    expect(mismatched, 0, reason: 'no digit ink in the middle of an unnumbered badge');
  });

  test('a numbered badge paints its digit in the middle, so the middle is not one colour', () async {
    final pixels = await paintedPixels(
      const Size(200, 200),
      (canvas) => paintToyBadge(canvas, _centre, _diameter, 2, _sunny),
    );
    expect(pixels.at(_discSample.$1, _discSample.$2), (255, 138, 31));
    expect(_middleMismatches(pixels, (255, 138, 31)), greaterThan(0), reason: 'the digit is ink in the middle');
  });

  testWidgets('an unnumbered badge has no "Player N" label for a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ToyLookScope(
        look: _sunny,
        child: const Directionality(textDirection: TextDirection.ltr, child: ToyBadge(number: 3, numbered: false)),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Player')), findsNothing);
    semantics.dispose();
  });

  testWidgets('a numbered badge keeps its "Player N" label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ToyLookScope(
        look: _sunny,
        child: const Directionality(textDirection: TextDirection.ltr, child: ToyBadge(number: 3)),
      ),
    );
    expect(find.bySemanticsLabel('Player 3'), findsOneWidget);
    semantics.dispose();
  });
}

/// How many pixels in the middle square are not [disc]: zero when nothing but
/// the disc's colour is drawn there.
int _middleMismatches(Pixels pixels, (int, int, int) disc) {
  var mismatched = 0;
  final cx = _centre.dx.round(), cy = _centre.dy.round();
  for (var y = cy - _middleHalf; y <= cy + _middleHalf; y++) {
    for (var x = cx - _middleHalf; x <= cx + _middleHalf; x++) {
      if (pixels.at(x, y) != disc) mismatched++;
    }
  }
  return mismatched;
}
