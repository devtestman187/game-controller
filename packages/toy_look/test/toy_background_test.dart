import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The box the pixel tests paint: its centre, its far corner and a dot on the
/// grid are all clear of each other.
const _size = Size(300, 300);

final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);
final _night = ToyLook.build(palette: ToyPalette.night, tv: true);

Future<Pixels> _painted(ToyLook look) =>
    paintedPixels(_size, (canvas) => ToyBackgroundPainter(look).paint(canvas, _size));

/// The background's painter, as the widget last built it.
CustomPainter _painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(of: find.byType(ToyBackground), matching: find.byType(CustomPaint)))
    .painter!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the centre is the glow and the corner is the sky', () async {
    final pixels = await _painted(_sunny);
    // The glow's centre is backgroundGlow (196, 234, 255), give or take the
    // gradient's rounding; (150, 150) is clear of every dot (the nearest is
    // 11.7 away, the dots are 3 across).
    final centre = pixels.at(150, 150);
    expect(centre.$1, closeTo(196, 1));
    expect(centre.$2, closeTo(234, 1));
    expect(centre.$3, closeTo(255, 1));
    // The glow's radius is 0.6 of the longer side (Claude's review: a soft,
    // wide glow), so it stops 180 from the centre: the far corner (208.6
    // away) is the background (124, 200, 248).
    expect(pixels.at(299, 299), (124, 200, 248));
    // (214, 214) is 90.5 from the centre, half-way out: its red is half-way
    // from the glow's 196 to the background's 124, about 160 (a 112.5 radius
    // would have it 80% of the way, about 138).
    expect(pixels.at(214, 214).$1, closeTo(160, 3));
  });

  test('a grid point is a dot: white at the palette\'s dotAlpha', () async {
    final pixels = await _painted(_sunny);
    // (272, 288) is on a dot: the odd rows sit half a step along. It is 184.2
    // from the centre, past the glow's 180, so the sky under it is the plain
    // background. White (255, 255, 255) at 22 % over it:
    // 0.22 * 255 + 0.78 * (124, 200, 248) = (152.8, 212.1, 249.5).
    final dot = pixels.at(272, 288);
    expect(dot.$1, closeTo(153, 2));
    expect(dot.$2, closeTo(212, 2));
    expect(dot.$3, closeTo(250, 2));
    // The Night palette's dots are weaker: 0.07 * 255 + 0.93 * (36, 28, 94) =
    // (51.3, 43.9, 105.3), so the dot is barely lighter than the sky.
    final nightDot = (await _painted(_night)).at(272, 288);
    expect(nightDot.$1, closeTo(51, 2));
    expect(nightDot.$2, closeTo(44, 2));
    expect(nightDot.$3, closeTo(105, 2));
  });

  testWidgets('the background repaints only when the look changes', (tester) async {
    await tester.pumpWidget(
      ToyLookScope(
        look: _sunny,
        child: const SizedBox.expand(child: ToyBackground()),
      ),
    );
    final sunny = _painterOf(tester);
    await tester.pumpWidget(
      ToyLookScope(
        look: ToyLook.build(palette: ToyPalette.sunny, tv: true),
        child: const SizedBox.expand(child: ToyBackground()),
      ),
    );
    final same = _painterOf(tester);
    expect(same.shouldRepaint(sunny), isFalse, reason: 'an equal look paints the same picture');
    await tester.pumpWidget(
      ToyLookScope(
        look: _night,
        child: const SizedBox.expand(child: ToyBackground()),
      ),
    );
    expect(_painterOf(tester).shouldRepaint(same), isTrue, reason: 'the other palette changes every colour');
  });
}
