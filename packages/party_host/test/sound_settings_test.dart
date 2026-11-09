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

/// This device's sound settings (M13 design section 8): 80% and the music on
/// unless the device changed them, saved beside the look's, and applied to the
/// player wherever it lives.
void main() {
  test('a fresh device plays at 80%, with the music on', () async {
    final container = await containerWith({});
    final settings = container.read(soundSettingsProvider);
    expect(settings.volume, 80);
    expect(settings.music, isTrue);
  });

  test('saved sound settings read back', () async {
    final container = await containerWith({'sound.volume': 30, 'sound.music': false});
    expect(container.read(soundSettingsProvider).volume, 30);
    expect(container.read(soundSettingsProvider).music, isFalse);
  });

  test('a saved volume out of range is clamped', () async {
    final container = await containerWith({'sound.volume': 140});
    expect(container.read(soundSettingsProvider).volume, 100);
  });

  test('the volume is clamped both ways, and both settings save', () async {
    final container = await containerWith({});
    final notifier = container.read(soundSettingsProvider.notifier);
    notifier.setVolume(140);
    expect(container.read(soundSettingsProvider).volume, 100);
    notifier.setVolume(-5);
    expect(container.read(soundSettingsProvider).volume, 0);
    notifier.setVolume(30);
    notifier.setMusic(false);
    final prefs = container.read(prefsProvider);
    expect(prefs.getInt('sound.volume'), 30);
    expect(prefs.getBool('sound.music'), isFalse);

    // The app's next launch: a container over the same prefs.
    final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(again.dispose);
    expect(again.read(soundSettingsProvider).volume, 30);
    expect(again.read(soundSettingsProvider).music, isFalse);
  });

  test('the player plays at the volume the device set', () async {
    // The real player: it keeps what it is asked for even where no audio
    // device can start under a test.
    final container = await containerWith({});
    final player = container.read(soundPlayerProvider);
    expect(player.volume, 0.8, reason: 'the default 80% is set when the player is made');
    container.read(soundSettingsProvider.notifier).setVolume(30);
    expect(player.volume, 0.3);
  });

  test('a saved volume is applied when the app starts', () async {
    final container = await containerWith({'sound.volume': 30});
    expect(container.read(soundPlayerProvider).volume, 0.3);
  });
}
