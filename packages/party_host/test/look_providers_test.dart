import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A container over a device's prefs, with the clock and the device's kind
/// set as the apps set them.
Future<ProviderContainer> _container({bool tv = false, DateTime? now, List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      toyTvProvider.overrideWithValue(tv),
      lookClockProvider.overrideWithValue(() => now ?? DateTime(2026, 11, 8, 12)),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the look is a phone look unless the device is the TV', () async {
    final phone = await _container();
    final look = phone.read(toyLookProvider);
    expect(look.type, ToyType.phone);
    expect(look.sizes, ToySizes.menu);
    expect(look.type.title.fontSize, 32);

    // The TV app overrides the flag: the TV's type and sizes, for reading
    // from three metres.
    final tv = await _container(tv: true);
    expect(tv.read(toyLookProvider).type, ToyType.tv);
    expect(tv.read(toyLookProvider).sizes, ToySizes.tv);
    expect(tv.read(toyLookProvider).type.title.fontSize, 56);
  });

  test('the palette is the Look setting\'s, worked out at midday and in the evening', () async {
    final day = await _container(now: DateTime(2026, 11, 8, 12));
    expect(day.read(toyLookProvider).palette, ToyPalette.sunny);
    expect(day.read(toyLookProvider).colors, ToyColors.sunny);

    final evening = await _container(now: DateTime(2026, 11, 8, 20));
    expect(evening.read(toyLookProvider).palette, ToyPalette.night);

    // A chosen palette doesn't look at the clock at all.
    evening.read(lookSettingsProvider.notifier).setChoice(LookChoice.sunny);
    expect(evening.read(toyLookProvider).palette, ToyPalette.sunny);
    expect(evening.read(toyLookProvider).colors, ToyColors.sunny);
  });

  test('the device\'s shaders reach the look, and effects off takes the shader away', () async {
    final container = await _container();
    final look = container.read(toyLookProvider);
    expect(look.effects, isTrue);
    // No shader loads under `flutter test` (the engine has no asset bundle to
    // compile it), so a device with effects on draws what it loaded.
    expect(look.shade, container.read(toyShadersProvider).shade);

    container.read(lookSettingsProvider.notifier).setEffects(false);
    final off = container.read(toyLookProvider);
    expect(off.effects, isFalse);
    expect(off.shade, isNull);
    // Every colour and shape stays (design D8).
    expect(off.colors, look.colors);
    expect(off.sizes, look.sizes);
    expect(off.type, look.type);
  });
}
