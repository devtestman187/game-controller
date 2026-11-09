import 'package:flutter/material.dart';

import 'look_choice.dart';
import 'page_transitions.dart';
import 'toy_look.dart';
import 'toy_shape.dart';
import 'toy_sizes.dart';

/// The Material theme both apps run on (M13, docs/design/look-and-sound.md
/// section 4): the colour scheme and text from the tokens, and the shapes of
/// the stock Material widgets the settings, stats and dialog screens use, so
/// those screens look right without being rewritten.
///
/// The scaffold is transparent because `ToyBackground` paints the sky behind
/// it (step 2b), and cards, dialogs, buttons and the snack bar get an ink edge
/// with no Material elevation: the hard shadow is `ToyCard`'s and
/// `ToyButton`'s job.
ThemeData toyTheme(ToyLook look) {
  final colors = look.colors;
  final scheme = _scheme(look);
  final paperShape = _paperShape(look);
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: colors.background,
    textTheme: _textTheme(look),
    // Every page carries its own sky, so a page sliding over another never
    // shows the one below through it (section 5).
    pageTransitionsTheme: _pageTransitions(),
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(look)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle(look)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle(look)),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle(look)),
    cardTheme: CardThemeData(color: colors.paper, elevation: 0, shape: paperShape),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.paper,
      elevation: 0,
      shape: paperShape,
      titleTextStyle: look.type.button.copyWith(color: colors.ink),
      contentTextStyle: look.type.body.copyWith(color: colors.ink),
    ),
    inputDecorationTheme: _fieldTheme(look),
    textSelectionTheme: TextSelectionThemeData(cursorColor: colors.ink),
    listTileTheme: ListTileThemeData(textColor: colors.onBackground, iconColor: colors.onBackground),
    switchTheme: _switchTheme(look),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.good,
      thumbColor: colors.good,
      // Ink at the shadow's strength: a dark track without competing with the
      // thumb's good.
      inactiveTrackColor: colors.ink.withValues(alpha: toyShadowAlpha),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colors.onBackground,
      elevation: 0,
      titleTextStyle: look.type.title.copyWith(color: colors.onBackground),
    ),
    // A tab sits on the background: both labels are readable there, and the
    // underline marks the chosen one.
    tabBarTheme: TabBarThemeData(
      labelColor: colors.onBackground,
      unselectedLabelColor: colors.onBackground,
      indicatorColor: colors.onBackground,
      labelStyle: look.type.button,
      unselectedLabelStyle: look.type.button,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.paper,
      contentTextStyle: look.type.body.copyWith(color: colors.ink),
      behavior: SnackBarBehavior.floating,
      shape: paperShape,
    ),
  );
}

/// Every page carries its own sky, on every platform, so a page sliding over
/// another never shows the one below through it (section 5).
PageTransitionsTheme _pageTransitions() => PageTransitionsTheme(
  builders: {for (final platform in TargetPlatform.values) platform: const ToyPageTransitionsBuilder()},
);

/// The palette as a colour scheme, with ink on every fill (design D12).
ColorScheme _scheme(ToyLook look) {
  final colors = look.colors;
  return ColorScheme(
    brightness: look.palette == ToyPalette.night ? Brightness.dark : Brightness.light,
    primary: colors.player(1),
    onPrimary: colors.ink,
    secondary: colors.caution,
    onSecondary: colors.ink,
    error: colors.bad,
    onError: colors.ink,
    surface: colors.paper,
    onSurface: colors.ink,
  );
}

/// The one shape a card, a dialog and the snack bar have: paper with 16 px
/// corners and this screen's ink edge.
RoundedRectangleBorder _paperShape(ToyLook look) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(ToySizes.cardCorner),
  side: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
);

/// A toy switch, easy to see on the sky, the grape and on paper (owner, Nov
/// 8, 2026: the switch was hard to see): an ink outline round the track, an
/// ink thumb, and a paper track when off, a good one when on.
SwitchThemeData _switchTheme(ToyLook look) {
  final colors = look.colors;
  return SwitchThemeData(
    thumbColor: WidgetStatePropertyAll(colors.ink),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? colors.good : colors.paper,
    ),
    trackOutlineColor: WidgetStatePropertyAll(colors.ink),
    trackOutlineWidth: WidgetStatePropertyAll(look.sizes.outlineWidth),
  );
}

/// A text field: paper with the ink edge and a card's corners, a thicker edge
/// when focused, and its label kept inside, so no label floats onto the sky
/// (Claude's 3c review). The field's own text is ink, set where it is built:
/// the theme's body text is onBackground, which is white at night.
InputDecorationTheme _fieldTheme(ToyLook look) {
  final colors = look.colors;
  OutlineInputBorder edge(double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(ToySizes.cardCorner),
    borderSide: BorderSide(color: colors.ink, width: width),
  );
  final soft = look.type.body.copyWith(color: colors.inkSoft);
  return InputDecorationTheme(
    filled: true,
    fillColor: colors.paper,
    border: edge(look.sizes.outlineWidth),
    enabledBorder: edge(look.sizes.outlineWidth),
    focusedBorder: edge(look.sizes.outlineWidth + 1),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    hintStyle: soft,
    labelStyle: soft,
  );
}

/// A button: a pill with the ink edge and ink text, flat (design section 4;
/// D12: text on a coloured fill is always ink).
ButtonStyle _buttonStyle(ToyLook look) {
  final colors = look.colors;
  return ButtonStyle(
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    side: WidgetStatePropertyAll(BorderSide(color: colors.ink, width: look.sizes.outlineWidth)),
    foregroundColor: WidgetStatePropertyAll(colors.ink),
    backgroundColor: WidgetStatePropertyAll(colors.player(1)),
    elevation: const WidgetStatePropertyAll(0),
    textStyle: WidgetStatePropertyAll(look.type.button),
  );
}

/// The theme's text: titles come from the look's title and button styles and
/// body text from its body style (design section 4).
///
/// Display and headline text sits on the background, so it is onBackground;
/// titles, body and labels sit on paper, so they are ink.
TextTheme _textTheme(ToyLook look) {
  final type = look.type;
  // A screen's text sits on the background (the scaffold is transparent), so
  // every style is onBackground; paper surfaces (dialogs, snack bars and
  // ToyCard) switch their own text to ink.
  final onBackground = type.title.copyWith(color: look.colors.onBackground);
  final title = type.button.copyWith(color: look.colors.onBackground);
  final body = type.body.copyWith(color: look.colors.onBackground);
  return TextTheme(
    displayLarge: onBackground,
    displayMedium: onBackground,
    displaySmall: onBackground,
    headlineLarge: onBackground,
    headlineMedium: onBackground,
    headlineSmall: onBackground,
    titleLarge: title,
    titleMedium: title,
    titleSmall: title,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: body,
    labelLarge: body,
    labelMedium: body,
    labelSmall: body,
  );
}
