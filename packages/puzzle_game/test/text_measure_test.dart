import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart' show ToyType;

import 'support/look_fonts.dart';

/// How many ems [text] takes in the look's [style]: its width over its height,
/// which is the number of characters [PuzzleCamera.glyphEm] sizes for.
double ems(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width / style.fontSize!;
  painter.dispose();
  return width;
}

/// How many ems each character of [text] takes in the look's [style]: the
/// number [PuzzleCamera.glyphEm] has to cover.
double perChar(String text, TextStyle style) => ems(text, style) / text.length;

void main() {
  setUpAll(loadLookFonts);

  // The widest the clock gets ("88:88": a 10 minute limit), and the score lines
  // a phone's HUD can draw, in the look's families (Fredoka 600 for the clock
  // and the counts, design section 3).
  const clock = '88:88';
  const scores = [
    '0 of 4 placed',
    '0 of 12 placed',
    'You 0/4 · Right 0/4',
    'You 0/12 · Right 0/12',
    'Right 0/12 · Left 0/12',
    'You 0/4',
    'Right 0/4',
    'Them 3/6',
    'Them 0/12',
    '0/4',
    'You 0/12',
  ];

  test('the HUD\'s estimate is never under the real width of a text it sizes', () {
    for (final text in [clock, ...scores]) {
      expect(
        text.length * PuzzleCamera.glyphEm,
        greaterThanOrEqualTo(ems(text, ToyType.phone.clock)),
        reason: '"$text"',
      );
    }
  });

  test('and no more than 15 % over the real width of the widest texts, which set it', () {
    // The other side's count, "Them 3/6", is the widest text the HUD draws per
    // character, so it is what keeps the number from being any larger. Only it
    // and the clock are held to the cap: one number that covers "Them 3/6" is
    // 28 % over "Left 0/12 · Right 0/12" however it is chosen.
    final widest = [
      clock,
      ...scores,
    ].reduce((a, b) => perChar(a, ToyType.phone.clock) >= perChar(b, ToyType.phone.clock) ? a : b);
    expect(widest, 'Them 3/6', reason: 'the widest text per character');
    for (final text in [clock, widest]) {
      expect(PuzzleCamera.glyphEm, lessThanOrEqualTo(1.15 * perChar(text, ToyType.phone.clock)), reason: '"$text"');
    }
  });
}
