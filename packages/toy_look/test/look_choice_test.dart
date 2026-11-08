import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// A local time on one winter day; the palette depends on the clock's hour, not
/// the date (design D1).
DateTime at(int hour, int minute) => DateTime(2026, 11, 8, hour, minute);

void main() {
  group('the Look setting read back from its saved name', () {
    test('an unknown or missing name is Auto', () {
      expect(LookChoice.fromName(null), LookChoice.auto);
      expect(LookChoice.fromName('dusk'), LookChoice.auto);
      expect(LookChoice.fromName(''), LookChoice.auto);
    });

    test('each choice is saved by its name and reads back as itself', () {
      expect(LookChoice.fromName('auto'), LookChoice.auto);
      expect(LookChoice.fromName('sunny'), LookChoice.sunny);
      expect(LookChoice.fromName('night'), LookChoice.night);
      for (final choice in LookChoice.values) {
        expect(LookChoice.fromName(choice.name), choice);
      }
    });
  });

  group('Auto picks the palette by the device\'s local time', () {
    test('Sunny starts at 07:00: 06:59 is Night, 07:00 is Sunny', () {
      expect(paletteFor(LookChoice.auto, at(6, 59)), ToyPalette.night);
      expect(paletteFor(LookChoice.auto, at(7, 0)), ToyPalette.sunny);
    });

    test('Sunny ends at 19:00: 18:59 is Sunny, 19:00 is Night', () {
      expect(paletteFor(LookChoice.auto, at(18, 59)), ToyPalette.sunny);
      expect(paletteFor(LookChoice.auto, at(19, 0)), ToyPalette.night);
    });

    test('Sunny and Night are the choice itself, whatever the time', () {
      for (final time in [at(0, 0), at(7, 0), at(12, 0), at(18, 59), at(23, 59)]) {
        expect(paletteFor(LookChoice.sunny, time), ToyPalette.sunny);
        expect(paletteFor(LookChoice.night, time), ToyPalette.night);
      }
    });
  });
}
