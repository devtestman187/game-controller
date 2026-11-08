import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// The Night look: its screen text is white, so ink on the card stands out.
final _night = ToyLook.build(palette: ToyPalette.night, tv: false);

/// The Sunny look, and the same one with effects off.
final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);
final _noEffects = ToyLook.build(palette: ToyPalette.sunny, tv: false, effects: false);

Widget _screen(ToyLook look, Widget child) => ToyLookScope(
  look: look,
  child: MaterialApp(
    theme: toyTheme(look),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(ToySizes.space16), child: child),
    ),
  ),
);

/// A card with a header, a line of body text and a ListTile.
Widget _card({String? header = 'Player 2', Color? headerColor, bool popIn = true}) => ToyCard(
  header: header,
  headerColor: headerColor,
  popIn: popIn,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('They can join again.'),
      ListTile(
        leading: const Icon(Icons.cloud_off),
        title: const Text('Away'),
        subtitle: const Text('Since a minute ago'),
      ),
    ],
  ),
);

/// The scale the card is drawn at: its outer transform, the pop-in's.
///
/// The x entry, not `getMaxScaleOnAxis`: that one reads the z axis too, and
/// the z axis is always 1, so it never reports a scale below 1.
double _scaleOf(WidgetTester tester) => tester
    .widget<Transform>(find.descendant(of: find.byType(ToyCard), matching: find.byType(Transform)).first)
    .transform
    .entry(0, 0);

/// The colour the text [text] is drawn in.
Color? _textColour(WidgetTester tester, String text) =>
    (tester.renderObject<RenderParagraph>(find.text(text)).text as TextSpan).style?.color;

/// The header band's decoration: the only box on the card with a border.
BoxDecoration _bandOf(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.descendant(of: find.byType(ToyCard), matching: find.byType(DecoratedBox)))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.border != null);

void main() {
  testWidgets('the header band is focus-coloured, in ink, over an ink line', (tester) async {
    await tester.pumpWidget(_screen(_night, _card()));
    await tester.pumpAndSettle();
    expect(find.text('Player 2'), findsOneWidget);
    expect(_textColour(tester, 'Player 2'), _night.colors.ink);
    final band = _bandOf(tester);
    expect(band.color, _night.colors.focus);
    expect(
      band.border,
      Border(
        bottom: BorderSide(color: _night.colors.ink, width: ToySizes.menu.outlineWidth),
      ),
    );
  });

  testWidgets('the header band runs across the whole top of the card, its title centred', (tester) async {
    // A card sized by what it holds (loose constraints): the band is as wide
    // as the card, not just its title (design section 4, the results card).
    await tester.pumpWidget(_screen(_night, Center(child: _card())));
    await tester.pumpAndSettle();
    final band = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == _night.colors.focus,
    );
    final card = tester.getRect(find.byType(ToyCard));
    expect(tester.getSize(band).width, card.width);
    expect(tester.getCenter(find.text('Player 2')).dx, closeTo(card.center.dx, 0.5));
  });

  testWidgets('a header colour of the caller\'s is the band\'s', (tester) async {
    await tester.pumpWidget(_screen(_night, _card(headerColor: _night.colors.caution)));
    await tester.pumpAndSettle();
    expect(_bandOf(tester).color, _night.colors.caution);
  });

  testWidgets('what a card holds is ink, while the screen\'s text is onBackground', (tester) async {
    await tester.pumpWidget(_screen(_night, Column(children: [const Text('On the screen'), _card()])));
    await tester.pumpAndSettle();
    expect(_textColour(tester, 'On the screen'), _night.colors.onBackground);
    expect(_textColour(tester, 'They can join again.'), _night.colors.ink);
    expect(_textColour(tester, 'Away'), _night.colors.ink);
    expect(_textColour(tester, 'Since a minute ago'), _night.colors.ink);
  });

  testWidgets('a card pops in from 0.9 to 1.0 in 180 ms', (tester) async {
    await tester.pumpWidget(_screen(_sunny, _card()));
    expect(_scaleOf(tester), closeTo(0.9, 1e-9));
    await tester.pump(const Duration(milliseconds: 180));
    expect(_scaleOf(tester), closeTo(1, 1e-9));
  });

  testWidgets('with effects off or popIn false it appears at 1.0 at once', (tester) async {
    await tester.pumpWidget(_screen(_noEffects, _card()));
    expect(_scaleOf(tester), 1);
    await tester.pumpWidget(_screen(_sunny, _card(popIn: false)));
    expect(_scaleOf(tester), 1);
  });
}
