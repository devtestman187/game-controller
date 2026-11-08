import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The button's box in the pixel tests: a menu button's height and a width
/// that leaves room for its label.
const _buttonSize = Size(160, 48);

/// The button's box painted with room under it, so a pixel below the pill can
/// still be read.
const _tallCanvas = Size(160, 60);

/// The look the widget tests draw, and the same look with effects off.
final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);
final _noEffects = ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: false);

Widget _screen(ToyLook look, Widget child) => ToyLookScope(
  look: look,
  child: MaterialApp(
    theme: toyTheme(look),
    home: Scaffold(body: Center(child: child)),
  ),
);

/// The button's painter, as it last built.
ToyButtonPainter _painterOf(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.descendant(of: find.byType(ToyButton), matching: find.byType(CustomPaint))).painter
        as ToyButtonPainter;

/// The scale the button is drawn at: its outer transform, the bounce's.
///
/// The x entry, not `getMaxScaleOnAxis`: that one reads the z axis too, and
/// the z axis is always 1, so it never reports a scale below 1.
double _scaleOf(WidgetTester tester) => tester
    .widget<Transform>(find.descendant(of: find.byType(ToyButton), matching: find.byType(Transform)).first)
    .transform
    .entry(0, 0);

/// A painter of the look [look], in the state named.
ToyButtonPainter _painter(ToyLook look, {bool isPressed = false, bool isFocused = false, bool isEnabled = true}) =>
    ToyButtonPainter(
      look: look,
      fill: look.colors.good,
      isEnabled: isEnabled,
      isFocused: isFocused,
      isPressed: isPressed,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tap calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () => taps++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ToyButton));
    expect(taps, 1);
  });

  testWidgets('Enter, Space, Select and the gamepad\'s A call onPressed with the focus on it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () => taps++, autofocus: true)));
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(taps, 4);
  });

  testWidgets('holding an activate key keeps the button pressed until the key is let go', (tester) async {
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () {}, autofocus: true)));
    await tester.pumpAndSettle();
    expect(_painterOf(tester).isPressed, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_painterOf(tester).isPressed, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_painterOf(tester).isPressed, isFalse);
  });

  testWidgets('a pointer down presses the pill until the pointer lifts', (tester) async {
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () {})));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ToyButton)));
    await tester.pump();
    expect(_painterOf(tester).isPressed, isTrue);
    await gesture.up();
    await tester.pump();
    expect(_painterOf(tester).isPressed, isFalse);
  });

  test('a pressed button loses its shadow and its pill sits a shadow-offset lower', () async {
    final raised = _painter(_sunny);
    final pressed = _painter(_sunny, isPressed: true);
    expect(pressed.pillRect(_buttonSize).topLeft, raised.pillRect(_buttonSize).topLeft + ToySizes.shadowOffset);

    final raisedPixels = await paintedPixels(_tallCanvas, (canvas) => raised.paint(canvas, _buttonSize));
    final pressedPixels = await paintedPixels(_tallCanvas, (canvas) => pressed.paint(canvas, _buttonSize));
    // The pill's bottom edge is at 41.75 (48 less the ring's room, 6.25): the
    // ink edge covers to 43.25 and the shadow then shows to 46.75, so (80, 44)
    // is ink at 35% over the white: (176, 173, 190).
    expect(raisedPixels.at(80, 44), (176, 173, 190));
    // Pressed, the pill has moved down 4: (80, 46) is its ink edge now, and no
    // shadow follows it below (the pill's edge ends at 47.25).
    expect(pressedPixels.at(80, 46), (30, 22, 70));
    expect(pressedPixels.at(80, 49), (255, 255, 255));
    expect(raisedPixels.at(80, 49), (255, 255, 255));
  });

  test('the focus ring is a focus-coloured band with its own thin ink edge', () async {
    final focused = _painter(_sunny, isFocused: true);
    final pixels = await paintedPixels(_buttonSize, (canvas) => focused.paint(canvas, _buttonSize));
    // The ring's outline is at 0.75 (the pill's top 6.25 less the 4 px ring
    // and its 1.5 edge): (80, 0) is the ring's ink, (80, 3) its focus fill
    // (255, 210, 63), and the pill's own 3 px ink edge then starts at 4.75.
    expect(pixels.at(80, 0), (30, 22, 70));
    expect(pixels.at(80, 3), (255, 210, 63));
    final unfocused = await paintedPixels(_buttonSize, (canvas) => _painter(_sunny).paint(canvas, _buttonSize));
    expect(unfocused.at(80, 3), (255, 255, 255));
  });

  testWidgets('the focus bounce passes 1.06 and ends at 1.04', (tester) async {
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () {}, autofocus: true)));
    await tester.pump();
    expect(_scaleOf(tester), closeTo(1, 1e-9), reason: 'the bounce starts at 1.0');
    await tester.pump(const Duration(milliseconds: 110));
    expect(_scaleOf(tester), closeTo(1.06, 1e-6), reason: 'half of the 220 ms bounce is its peak');
    await tester.pumpAndSettle();
    expect(_scaleOf(tester), closeTo(1.04, 1e-9), reason: 'it rests at 1.04');
  });

  testWidgets('with effects off the focus sits at 1.04 at once, with no bounce', (tester) async {
    await tester.pumpWidget(_screen(_noEffects, ToyButton(label: 'Play', onPressed: () {}, autofocus: true)));
    await tester.pump();
    expect(_scaleOf(tester), closeTo(1.04, 1e-9));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing animates');
  });

  testWidgets('showFocus false draws no ring and no scale', (tester) async {
    await tester.pumpWidget(
      _screen(_sunny, ToyButton(label: 'Play', onPressed: () {}, autofocus: true, showFocus: false)),
    );
    await tester.pumpAndSettle();
    expect(_painterOf(tester).isFocused, isFalse);
    expect(_scaleOf(tester), 1);
  });

  testWidgets('a disabled button ignores taps and cannot take the focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: null, focusNode: node)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ToyButton));
    expect(node.hasFocus, isFalse);
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isFalse);
  });

  test('a disabled button is paper with no shadow and a dashed ink edge', () async {
    final disabled = _painter(_sunny, isEnabled: false);
    final pixels = await paintedPixels(_tallCanvas, (canvas) => disabled.paint(canvas, _buttonSize));
    // Paper (255, 246, 227) inside, and no shadow under it.
    expect(pixels.at(80, 24), (255, 246, 227));
    expect(pixels.at(80, 44), (255, 255, 255));
    // The edge is dashed: along the pill's straight top the ink comes and goes.
    final edge = [for (var x = 60; x <= 100; x++) pixels.at(x, 6)];
    final runs = <bool>[];
    for (final (r, g, b) in edge) {
      final isInk = r < 100 && g < 100 && b < 100;
      if (runs.isEmpty || runs.last != isInk) runs.add(isInk);
    }
    expect(runs.length, greaterThan(2), reason: 'a solid edge would be one run of ink');
  });

  testWidgets('the button is 48 px on a menu and 64 on a TV', (tester) async {
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () {})));
    expect(tester.getSize(find.byType(ToyButton)).height, 48);
    final tv = ToyLook.build(palette: ToyPalette.sunny, tv: true);
    await tester.pumpWidget(_screen(tv, ToyButton(label: 'Play', onPressed: () {})));
    expect(tester.getSize(find.byType(ToyButton)).height, 64);
  });

  testWidgets('the label is the look\'s button type in ink, and the widget is a button with its label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_screen(_sunny, ToyButton(label: 'Play', onPressed: () {})));
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Play'));
    expect((paragraph.text as TextSpan).style!.color, _sunny.colors.ink);
    expect((paragraph.text as TextSpan).style!.fontFamily, _sunny.type.button.fontFamily);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    semantics.dispose();
  });
}
