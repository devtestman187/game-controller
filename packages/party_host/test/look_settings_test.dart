import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A container over the prefs a device saved, as the app's `main()` makes one.
Future<ProviderContainer> containerWith(Map<String, Object> saved, {List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs), ...overrides]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a fresh device looks Auto, with effects on', () async {
    final container = await containerWith({});
    final settings = container.read(lookSettingsProvider);
    expect(settings.choice, LookChoice.auto);
    expect(settings.effects, isTrue);
  });

  test('a saved Night with effects off reads back', () async {
    final container = await containerWith({'look.choice': 'night', 'look.effects': false});
    final settings = container.read(lookSettingsProvider);
    expect(settings.choice, LookChoice.night);
    expect(settings.effects, isFalse);
  });

  test('an unknown saved name reads as Auto', () async {
    final container = await containerWith({'look.choice': 'sepia'});
    expect(container.read(lookSettingsProvider).choice, LookChoice.auto);
  });

  test('a change is saved under the look keys, and a new container reads it back', () async {
    final container = await containerWith({});
    final notifier = container.read(lookSettingsProvider.notifier);
    notifier.setChoice(LookChoice.night);
    notifier.setEffects(false);
    final prefs = container.read(prefsProvider);
    expect(prefs.getString('look.choice'), 'night');
    expect(prefs.getBool('look.effects'), isFalse);

    // The app's next launch: a container over the same prefs.
    final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(again.dispose);
    expect(again.read(lookSettingsProvider).choice, LookChoice.night);
    expect(again.read(lookSettingsProvider).effects, isFalse);
  });
}
