import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The look the phone draws, and the TV's.
final _phone = ToyLook.build(palette: ToyPalette.sunny, tv: false);
final _tv = ToyLook.build(palette: ToyPalette.sunny, tv: true);

Widget _screen(ToyLook look, Widget child) => ToyLookScope(
  look: look,
  child: MaterialApp(
    theme: toyTheme(look),
    home: Scaffold(body: Center(child: child)),
  ),
);

/// The pill's painter, as it last built.
ToyPillPainter _painterOf(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.descendant(of: find.byType(ToyPill), matching: find.byType(CustomPaint))).painter
        as ToyPillPainter;

/// The pill's label, as it last built.
TextStyle _labelStyleOf(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(ToyPill), matching: find.byType(Text))).style!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a pill is as tall as its label line and the room round it, on the phone and on the TV', (tester) async {
    for (final (look, expected) in [(_phone, 29.75), (_tv, 39.5)]) {
      await tester.pumpWidget(_screen(look, ToyPill(label: 'Good link', fill: look.colors.good)));
      expect(tester.getSize(find.byType(ToyPill)).height, expected);
    }
    // 15 × 1.25 + 8 + 3 = 29.75 on the phone's type and outline, and
    // 22 × 1.25 + 8 + 4 = 39.5 on the TV's.
  });

  testWidgets('the label is ink, at the body\'s size in the button\'s family and weight', (tester) async {
    await tester.pumpWidget(_screen(_phone, ToyPill(label: 'Good link', fill: _phone.colors.good)));
    final style = _labelStyleOf(tester);
    expect(style.color, _phone.colors.ink);
    expect(style.fontSize, _phone.type.body.fontSize);
    expect(style.fontFamily, _phone.type.button.fontFamily);
    expect(style.fontWeight, _phone.type.button.fontWeight);
  });

  testWidgets('the pill takes the fill it is given, with an ink edge and no shadow', (tester) async {
    await tester.pumpWidget(_screen(_phone, ToyPill(label: 'Slow link', fill: _phone.colors.caution)));
    final painter = _painterOf(tester);
    expect(painter.fill, _phone.colors.caution);
    expect(painter.look, _phone);
  });

  test('a pill is its fill inside an ink edge', () async {
    final pixels = await paintedPixels(
      const Size(120, 30),
      (canvas) => ToyPillPainter(look: _phone, fill: _phone.colors.good).paint(canvas, const Size(120, 30)),
    );
    // The middle of the stadium is good green (47, 203, 116)…
    expect(pixels.at(60, 15), (47, 203, 116));
    // …and its rim is ink (30, 22, 70), the outline's 3 px inside the box.
    expect(pixels.at(1, 15), (30, 22, 70));
    expect(pixels.at(118, 15), (30, 22, 70));
  });

  testWidgets('an icon sits before the label, in ink', (tester) async {
    await tester.pumpWidget(_screen(_phone, ToyPill(label: 'Good link', fill: _phone.colors.good, icon: Icons.check)));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, _phone.colors.ink);
  });
}
