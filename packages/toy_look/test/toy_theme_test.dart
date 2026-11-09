import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// The one card and dialog shape: paper, an ink edge [outlineWidth] wide and
/// 16 px corners (design section 3 and rule 8).
RoundedRectangleBorder _paperShape(ToyColors colors, double outlineWidth) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(ToySizes.cardCorner),
  side: BorderSide(color: colors.ink, width: outlineWidth),
);

void main() {
  // A phone's look: the 3 px menu edge (rule 8); the TV's 4 px edge has its
  // own test below.
  final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);
  final night = ToyLook.build(palette: ToyPalette.night, tv: false);

  test('Sunny is light and Night is dark', () {
    expect(toyTheme(sunny).brightness, Brightness.light);
    expect(toyTheme(night).brightness, Brightness.dark);
    expect(toyTheme(sunny).useMaterial3, isTrue);
  });

  test('the colour scheme is the palette\'s tokens, with ink on its fills', () {
    final scheme = toyTheme(sunny).colorScheme;
    expect(scheme.primary, ToyColors.sunny.player(1));
    expect(scheme.surface, ToyColors.sunny.paper);
    expect(scheme.onSurface, ToyColors.sunny.ink);
    expect(scheme.error, ToyColors.sunny.bad);
    expect(scheme.onPrimary, ToyColors.sunny.ink);
    expect(scheme.onSecondary, ToyColors.sunny.ink);
    expect(scheme.onError, ToyColors.sunny.ink);
  });

  test('the scaffold is transparent, so the background paints behind it', () {
    final theme = toyTheme(sunny);
    expect(theme.scaffoldBackgroundColor, const Color(0x00000000));
    expect(theme.canvasColor, ToyColors.sunny.background);
  });

  test('cards are paper with 16 px corners and a 3 px ink side, with no elevation', () {
    final theme = toyTheme(sunny);
    expect(theme.cardTheme.color, ToyColors.sunny.paper);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.cardTheme.shape, _paperShape(ToyColors.sunny, ToySizes.menu.outlineWidth));
  });

  test('dialogs are paper with 16 px corners and a 3 px ink side, with no elevation', () {
    final theme = toyTheme(night);
    expect(theme.dialogTheme.backgroundColor, ToyColors.night.paper);
    expect(theme.dialogTheme.elevation, 0);
    expect(theme.dialogTheme.shape, _paperShape(ToyColors.night, ToySizes.menu.outlineWidth));
  });

  test('a text field is paper with an ink edge and 16 px corners, ink text, in both palettes', () {
    // The Connect screen's address field was a stock Material box on the sky
    // (Claude's 3c review).
    for (final look in [sunny, night]) {
      final fields = toyTheme(look).inputDecorationTheme;
      final colors = look.colors;
      expect(fields.filled, isTrue);
      expect(fields.fillColor, colors.paper);
      final edge = OutlineInputBorder(
        borderRadius: BorderRadius.circular(ToySizes.cardCorner),
        borderSide: BorderSide(color: colors.ink, width: look.sizes.outlineWidth),
      );
      expect(fields.enabledBorder, edge);
      expect(fields.border, edge);
      expect(
        fields.focusedBorder,
        edge.copyWith(
          borderSide: BorderSide(color: colors.ink, width: look.sizes.outlineWidth + 1),
        ),
      );
      expect(fields.hintStyle?.color, colors.inkSoft);
      expect(fields.labelStyle?.color, colors.inkSoft);
      expect(toyTheme(look).textSelectionTheme.cursorColor, colors.ink);
    }
  });

  test('a TV theme draws the 4 px edge instead of the menu\'s 3 px', () {
    final tv = toyTheme(ToyLook.build(palette: ToyPalette.sunny, tv: true));
    expect(tv.cardTheme.shape, _paperShape(ToyColors.sunny, ToySizes.tv.outlineWidth));
  });

  test('a filled button is a pill with a 3 px ink side and ink text', () {
    final style = toyTheme(sunny).filledButtonTheme.style;
    expect(style, isNotNull);
    expect(style!.shape!.resolve(<WidgetState>{}), isA<StadiumBorder>());
    expect(
      style.side!.resolve(<WidgetState>{}),
      BorderSide(color: ToyColors.sunny.ink, width: ToySizes.menu.outlineWidth),
    );
    expect(style.foregroundColor!.resolve(<WidgetState>{}), ToyColors.sunny.ink);
  });

  test('an app bar is transparent with onBackground text', () {
    final theme = toyTheme(night);
    expect(theme.appBarTheme.backgroundColor, const Color(0x00000000));
    expect(theme.appBarTheme.foregroundColor, ToyColors.night.onBackground);
  });

  // Claude's step 6 review: the TV's Look test showed its unselected tab in
  // Material's dark default on the Night sky, unreadable. A tab sits on the
  // background, so both its labels are onBackground and the underline marks
  // the one chosen.
  test("a tab bar's labels are onBackground, chosen or not, in both palettes", () {
    for (final look in [sunny, night]) {
      final tabs = toyTheme(look).tabBarTheme;
      expect(tabs.labelColor, look.colors.onBackground);
      expect(tabs.unselectedLabelColor, look.colors.onBackground);
      expect(tabs.indicatorColor, look.colors.onBackground);
    }
  });

  test('body text is Nunito, the titles Fredoka', () {
    final theme = toyTheme(sunny);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'packages/toy_look/Nunito');
    expect(theme.textTheme.labelLarge!.fontFamily, 'packages/toy_look/Nunito');
    expect(theme.textTheme.titleLarge!.fontFamily, 'packages/toy_look/Fredoka');
    expect(theme.textTheme.displayLarge!.fontFamily, 'packages/toy_look/Fredoka');
    expect(theme.textTheme.headlineMedium!.fontFamily, 'packages/toy_look/Fredoka');
  });

  test('text on the screen is onBackground, so Night\'s settings list is white on grape', () {
    // A screen's text sits on the background (the scaffold is transparent);
    // only paper surfaces (dialogs, snack bars, ToyCard) switch to ink.
    final theme = toyTheme(night);
    for (final style in [
      theme.textTheme.displayLarge,
      theme.textTheme.headlineMedium,
      theme.textTheme.titleLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.labelLarge,
    ]) {
      expect(style!.color, ToyColors.night.onBackground);
    }
    expect(theme.listTileTheme.textColor, ToyColors.night.onBackground);
    expect(theme.listTileTheme.iconColor, ToyColors.night.onBackground);
  });

  test('a dialog\'s title and text are ink on its paper', () {
    final theme = toyTheme(night);
    expect(theme.dialogTheme.titleTextStyle!.color, ToyColors.night.ink);
    expect(theme.dialogTheme.titleTextStyle!.fontFamily, 'packages/toy_look/Fredoka');
    expect(theme.dialogTheme.contentTextStyle!.color, ToyColors.night.ink);
    expect(theme.dialogTheme.contentTextStyle!.fontFamily, 'packages/toy_look/Nunito');
  });
}
