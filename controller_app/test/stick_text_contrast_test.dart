import 'dart:math' as math;

import 'package:controller/src/sticks.dart' show StickSettings;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show PhoneText, SettingsText;

import 'support/pump_app.dart';

/// What a line of body text needs against the paper behind it (WCAG AA).
const _minContrast = 4.5;

/// Midday, so Auto picks the Sunny palette, whose ink is dark.
DateTime _day() => DateTime(2026, 11, 8, 12);

/// The evening, so Auto picks the Night palette, whose `onBackground` is white.
DateTime _night() => DateTime(2026, 11, 8, 20);

/// The settings the test app starts from: nothing is saved, so the dialog
/// shows the defaults (sticks.dart).
const _sticks = StickSettings();

/// The dialog's three slider lines, found by the same [SettingsText] calls the
/// dialog makes (stick_dialog.dart): the button size, the dead zone and the
/// sensitivity.
final sliderLines = [
  SettingsText.stickButtonSizeLine((_sticks.buttonSize * 100).round()),
  SettingsText.stickDeadZoneLine((_sticks.deadZone * 100).round()),
  SettingsText.stickSensitivityLine(_sticks.sensitivity, (100 / _sticks.sensitivity).round()),
];

void main() {
  group('stick text contrast', () {
    // The owner's B-017: "you cannot read the text. The text is white on a
    // light background." The app's palette comes from the Look setting and the
    // clock, not from the system brightness, so both palettes are checked.
    //
    // The two dialog tests are B-017's evidence: the dialog's switch title drew
    // white on cream paper at night, 1.07:1, and they failed on that code. The
    // two Settings tests guard what `ToyCard` already did — it puts its tiles
    // back to ink (toy_card.dart) — so they passed before the fix and after.
    Future<void> openStickDialog(WidgetTester tester, DateTime Function() clock) async {
      final app = await pumpApp(tester, paired: true, clock: clock);
      app.client.emit(connected);
      await tester.pump();
      // The stick settings' own way into the dialog, in Sticks mode.
      await tester.tap(find.text('Sticks'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Stick settings'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> openSticksSection(WidgetTester tester, DateTime Function() clock) async {
      await pumpApp(tester, paired: true, clock: clock);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('settingsStickFloating')));
    }

    for (final (moment, clock) in [('at midday', _day), ('at night', _night)]) {
      testWidgets('the Sticks dialog reads the floating-sticks lines $moment', (tester) async {
        await openStickDialog(tester, clock);
        expectReads(tester, find.text(SettingsText.floatingSticks), 'the Floating sticks title');
        expectReads(tester, find.text(SettingsText.floatingLine), 'its subtitle');
        // The dialog's own words, which the dialog's text theme colours. Its
        // title is found under the dialog because 'Sticks' also names the mode
        // tab behind it.
        final dialog = find.byType(AlertDialog);
        expectReads(tester, find.descendant(of: dialog, matching: find.text(PhoneText.sticks)), "the dialog's title");
        expectReads(tester, find.text(SettingsText.stickLine), "the dialog's line about the sticks");
        for (final line in sliderLines) {
          expectReads(tester, find.text(line), 'the line "$line"');
        }
        expectReads(tester, find.descendant(of: dialog, matching: find.text(SettingsText.defaults)), 'Defaults');
        expectReads(tester, find.descendant(of: dialog, matching: find.text(SettingsText.done)), 'Done');
      });

      testWidgets('the Sticks section of Settings reads the floating-sticks lines $moment', (tester) async {
        await openSticksSection(tester, clock);
        final tile = find.byKey(const Key('settingsStickFloating'));
        expectReads(
          tester,
          find.descendant(of: tile, matching: find.text(SettingsText.floatingSticks)),
          'the Floating sticks title',
        );
        expectReads(tester, find.descendant(of: tile, matching: find.text(SettingsText.floatingLine)), 'its subtitle');
      });
    }
  });
}

/// Expects [finder]'s text to keep [_minContrast] against the surface behind
/// it, and says what it measured when it doesn't: the colour it is drawn in
/// (its own style over the DefaultTextStyle above it, blended onto the
/// surface) and the surface's own colour.
void expectReads(WidgetTester tester, Finder finder, String what) {
  final element = tester.element(finder);
  final style = DefaultTextStyle.of(element).style.merge(tester.widget<Text>(finder).style);
  expect(style.color, isNotNull, reason: '$what has no colour to read');
  final surface = surfaceBehind(element);
  final drawn = Color.alphaBlend(style.color!, surface);
  final ratio = contrastRatio(drawn, surface);
  expect(
    ratio,
    greaterThanOrEqualTo(_minContrast),
    reason: '$what: ${hex(drawn)} on ${hex(surface)} is ${ratio.toStringAsFixed(2)}:1',
  );
}

/// The colour of the nearest thing [element]'s text is painted on: the
/// dialog's Material, or the card's own ColoredBox of paper.
Color surfaceBehind(Element element) {
  Color? surface;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is ColoredBox) {
      surface = widget.color;
      return false;
    }
    if (widget is Material && widget.color != null) {
      surface = widget.color;
      return false;
    }
    return true;
  });
  expect(surface, isNotNull, reason: 'nothing paints under ${element.widget.runtimeType}');
  return surface!;
}

/// The WCAG 2 contrast ratio of [a] against [b], from 1 to 21.
double contrastRatio(Color a, Color b) {
  final first = luminance(a);
  final second = luminance(b);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

/// [colour]'s relative luminance (WCAG 2): its channels weighted for the eye.
double luminance(Color colour) => 0.2126 * _linear(colour.r) + 0.7152 * _linear(colour.g) + 0.0722 * _linear(colour.b);

/// One channel of [luminance]: the sRGB transfer curve, undone.
double _linear(double channel) =>
    channel <= 0.03928 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// [colour] as `#AARRGGBB`, for a failure's message.
String hex(Color colour) => '#${colour.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
