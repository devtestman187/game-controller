import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// How a variable font's weight is asked for: the axis as well as the weight,
/// because some platforms take the weight only from the axis (brief rule 5).
final _w600 = [const FontVariation('wght', 600)];
final _w700 = [const FontVariation('wght', 700)];

void main() {
  test('the TV sizes are the design\'s: 56, 28, 56 and 22', () {
    final tv = ToyType.tv;
    expect(tv.title.fontSize, 56);
    expect(tv.button.fontSize, 28);
    expect(tv.clock.fontSize, 56);
    expect(tv.body.fontSize, 22);
  });

  test('the phone sizes are the design\'s: 32, 18, 32 and 15', () {
    final phone = ToyType.phone;
    expect(phone.title.fontSize, 32);
    expect(phone.button.fontSize, 18);
    expect(phone.clock.fontSize, 32);
    expect(phone.body.fontSize, 15);
  });

  test('titles, buttons and the clock are Fredoka 600 in the package\'s own font', () {
    for (final type in [ToyType.tv, ToyType.phone]) {
      for (final style in [type.title, type.button, type.clock]) {
        expect(style.fontFamily, 'packages/toy_look/Fredoka');
        expect(style.fontWeight, FontWeight.w600);
        expect(style.fontVariations, _w600);
      }
    }
  });

  test('body text is Nunito 700 in the package\'s own font', () {
    for (final type in [ToyType.tv, ToyType.phone]) {
      expect(type.body.fontFamily, 'packages/toy_look/Nunito');
      expect(type.body.fontWeight, FontWeight.w700);
      expect(type.body.fontVariations, _w700);
    }
  });

  test('the type carries no colour: the theme and the widgets add it', () {
    for (final type in [ToyType.tv, ToyType.phone]) {
      for (final style in [type.title, type.button, type.clock, type.body]) {
        expect(style.color, isNull);
      }
    }
  });
}
