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

/// This device's sound settings (M13 design section 8; owner, Nov 9, 2026):
/// a Sounds volume (80%) and a Music volume (60%), and Mute, which silences
/// both and keeps them to come back to. Saved beside the look's, and applied to
/// the player wherever it lives.
void main() {
  test('a fresh device plays sounds at 80% and music at 60%, not muted', () async {
    final container = await containerWith({});
    final settings = container.read(soundSettingsProvider);
    expect(settings.soundVolume, 80);
    expect(settings.musicVolume, 60);
    expect(settings.muted, isFalse);
  });

  test('saved sound settings read back', () async {
    final container = await containerWith({'sound.volume': 30, 'sound.musicVolume': 20, 'sound.muted': true});
    final settings = container.read(soundSettingsProvider);
    expect(settings.soundVolume, 30);
    expect(settings.musicVolume, 20);
    expect(settings.muted, isTrue);
  });

  test('saved volumes out of range are clamped', () async {
    final container = await containerWith({'sound.volume': 140, 'sound.musicVolume': -5});
    expect(container.read(soundSettingsProvider).soundVolume, 100);
    expect(container.read(soundSettingsProvider).musicVolume, 0);
  });

  test('both volumes are clamped both ways, and every setting saves', () async {
    final container = await containerWith({});
    final notifier = container.read(soundSettingsProvider.notifier);
    notifier.setSoundVolume(140);
    expect(container.read(soundSettingsProvider).soundVolume, 100);
    notifier.setSoundVolume(-5);
    expect(container.read(soundSettingsProvider).soundVolume, 0);
    notifier.setMusicVolume(140);
    expect(container.read(soundSettingsProvider).musicVolume, 100);
    notifier.setSoundVolume(30);
    notifier.setMusicVolume(20);
    notifier.setMuted(true);
    final prefs = container.read(prefsProvider);
    expect(prefs.getInt('sound.volume'), 30);
    expect(prefs.getInt('sound.musicVolume'), 20);
    expect(prefs.getBool('sound.muted'), isTrue);

    // The app's next launch: a container over the same prefs.
    final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(again.dispose);
    expect(again.read(soundSettingsProvider), container.read(soundSettingsProvider));
  });

  test('the player plays the sounds and the music at the volumes the device set', () async {
    // The real player: it keeps what it is asked for even where no audio
    // device can start under a test.
    final container = await containerWith({});
    final player = container.read(soundPlayerProvider);
    expect(player.volume, 0.8, reason: 'the default 80% is set when the player is made');
    expect(player.musicVolume, 0.6, reason: "and the music's 60%");
    container.read(soundSettingsProvider.notifier).setSoundVolume(30);
    container.read(soundSettingsProvider.notifier).setMusicVolume(20);
    expect(player.volume, 0.3);
    expect(player.musicVolume, 0.2);
  });

  // Owner, Nov 9, 2026: "a mute switch should mute volume and sound".
  test('Mute silences the sounds and the music, and unmuting brings both back', () async {
    final container = await containerWith({});
    final player = container.read(soundPlayerProvider);
    final notifier = container.read(soundSettingsProvider.notifier);
    notifier.setMuted(true);
    expect(player.volume, 0);
    expect(player.musicVolume, 0);
    notifier.setSoundVolume(30);
    notifier.setMusicVolume(20);
    expect(player.volume, 0, reason: 'a change while muted stays silent');
    expect(player.musicVolume, 0);
    notifier.setMuted(false);
    expect(player.volume, 0.3);
    expect(player.musicVolume, 0.2);
  });

  test('saved settings are applied when the app starts, Mute included', () async {
    final loud = await containerWith({'sound.volume': 30, 'sound.musicVolume': 20});
    expect(loud.read(soundPlayerProvider).volume, 0.3);
    expect(loud.read(soundPlayerProvider).musicVolume, 0.2);
    final muted = await containerWith({'sound.volume': 30, 'sound.muted': true});
    expect(muted.read(soundSettingsProvider).soundVolume, 30, reason: 'muting keeps the volume to come back to');
    expect(muted.read(soundPlayerProvider).volume, 0);
    expect(muted.read(soundPlayerProvider).musicVolume, 0);
  });
}
