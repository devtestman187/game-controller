import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// The WCAG 2 relative luminance of one sRGB channel, 0 to 1 (design section 3:
/// "relative luminance with the 0.03928 threshold").
double _channel(double value) => value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

/// The WCAG 2 relative luminance of [color], 0 (black) to 1 (white).
double _luminance(Color color) => 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b);

/// The WCAG 2 contrast ratio of [foreground] on [background], 1 to 21.
double contrastRatio(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

/// Every text-on-fill pair the design has to keep readable (design section 3),
/// by the name the test's failure prints.
Map<String, (Color, Color)> _pairs(ToyColors colors) {
  final pairs = <String, (Color, Color)>{
    'ink on paper': (colors.ink, colors.paper),
    'onBackground on background': (colors.onBackground, colors.background),
    'onBackground on backgroundGlow': (colors.onBackground, colors.backgroundGlow),
    'onBackground on board': (colors.onBackground, colors.board),
    'onBackground on tray': (colors.onBackground, colors.tray),
    'onBackground on field': (colors.onBackground, colors.field),
    'ink on good': (colors.ink, colors.good),
    'ink on caution': (colors.ink, colors.caution),
    'ink on bad': (colors.ink, colors.bad),
    'ink on focus': (colors.ink, colors.focus),
    'ink on faceA': (colors.ink, colors.faceA),
    'ink on faceB': (colors.ink, colors.faceB),
    'ink on faceX': (colors.ink, colors.faceX),
    'ink on faceY': (colors.ink, colors.faceY),
  };
  for (var number = 1; number <= 6; number++) {
    pairs['ink on player $number'] = (colors.ink, colors.player(number));
  }
  return pairs;
}

/// The smallest ratio the design allows text on a fill to have.
const _minimumRatio = 4.5;

void main() {
  for (final palette in ToyPalette.values) {
    test('${palette.name} keeps every text-on-fill pair at 4.5:1 or better', () {
      final colors = ToyColors.of(palette);
      for (final entry in _pairs(colors).entries) {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(_minimumRatio),
          reason: '${palette.name}: ${entry.key} is ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });
  }

  test('the contrast formula gives the ratios the design was measured with', () {
    // Black on white is the formula's largest ratio, 21:1.
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.005));
    // The three pairs Claude measured when the palette was chosen (design D12,
    // brief rule 9), to 2 decimals.
    expect(contrastRatio(ToyColors.sunny.ink, ToyColors.sunny.paper), closeTo(15.53, 0.005), reason: 'ink on paper');
    expect(
      contrastRatio(ToyColors.sunny.ink, ToyColors.sunny.player(3)),
      closeTo(4.94, 0.005),
      reason: 'ink on player 3',
    );
    expect(
      contrastRatio(ToyColors.night.onBackground, ToyColors.night.background),
      closeTo(14.97, 0.005),
      reason: 'Night white on background',
    );
  });
}
