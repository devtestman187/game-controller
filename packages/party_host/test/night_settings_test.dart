import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_settings.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The prefs key the night's settings are saved under.
const _key = 'party_night_settings_v1';

/// A valid saved form of the defaults, for the tests that break one field of it.
Map<String, Object?> _validJson() => const NightSettings().toJson();

/// The saved preferences, empty, as a test starts with.
Future<SharedPreferences> _emptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// A container whose settings are kept on [prefs]; disposed when the test ends.
ProviderContainer _containerOver(SharedPreferences prefs) {
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('NightSettings', () {
    test('the defaults: three rounds, every game, easy to hard, Chaos off, lively cat, director picks', () {
      const settings = NightSettings();
      expect(settings.length, NightLength.three);
      expect(settings.pool, isEmpty);
      expect(settings.difficultyMin, Level.easy);
      expect(settings.difficultyMax, Level.hard);
      expect(settings.chaos, Chaos.off);
      expect(settings.cat, CatPreset.lively);
      expect(settings.timerScale, 1.0);
      expect(settings.picker, NightPicker.director);
      expect(settings.isKids, isFalse);
    });

    test('a changed night reads back equal after a JSON round trip, with the pool sorted', () {
      const changed = NightSettings(
        length: NightLength.five,
        pool: {'house', 'cat'},
        difficultyMin: Level.medium,
        chaos: Chaos.party,
        cat: CatPreset.wild,
        timerScale: 2.0,
        picker: NightPicker.vote,
      );
      expect(changed.toJson()['pool'], ['cat', 'house']);
      final back = NightSettings.tryFromJson(jsonDecode(jsonEncode(changed.toJson())));
      expect(back, changed);
    });

    test('Kids survives a JSON round trip and still reads as Kids', () {
      final back = NightSettings.tryFromJson(jsonDecode(jsonEncode(NightSettings.kids.toJson())));
      expect(back, NightSettings.kids);
      expect(back!.isKids, isTrue);
    });

    test('Kids is pinned: three rounds, easy to easy, Chaos little, a calm cat, timers at 1.5, director picks', () {
      const kids = NightSettings.kids;
      expect(kids.length, NightLength.three);
      expect(kids.pool, isEmpty);
      expect(kids.difficultyMin, Level.easy);
      expect(kids.difficultyMax, Level.easy);
      expect(kids.chaos, Chaos.little);
      expect(kids.cat, CatPreset.calm);
      expect(kids.timerScale, 1.5);
      expect(kids.picker, NightPicker.director);
      expect(kids.copyWith(timerScale: 1.0).isKids, isFalse);
    });

    test('garbage, a wrong type, an unknown name, min above max and a timer out of range give null', () {
      final bad = <Object?>[
        null,
        'x',
        [1, 2],
        {},
        {..._validJson(), 'length': 3},
        {..._validJson(), 'length': 'ten'},
        {..._validJson(), 'chaos': 'wild'},
        {..._validJson(), 'difficultyMin': 'hard', 'difficultyMax': 'easy'},
        {..._validJson(), 'timerScale': 5.0},
        {..._validJson(), 'timerScale': 0.5},
        {..._validJson(), 'timerScale': 'fast'},
        {..._validJson(), 'timerScale': double.nan},
        {..._validJson(), 'pool': 'house'},
        {
          ..._validJson(),
          'pool': [1],
        },
      ];
      for (final json in bad) {
        expect(NightSettings.tryFromJson(json), isNull, reason: '$json');
      }
    });

    test('update saves the settings, and a new container reads them back', () async {
      const changed = NightSettings(length: NightLength.five, picker: NightPicker.shuffle);
      final prefs = await _emptyPrefs();
      final first = _containerOver(prefs);
      first.read(nightSettingsProvider.notifier).update(changed);
      expect(first.read(nightSettingsProvider), changed);
      await pumpEventQueue();
      expect(prefs.getString(_key), isNotNull);

      final second = _containerOver(prefs);
      expect(second.read(nightSettingsProvider), changed);
    });

    test('useKids gives the Kids preset and saves it', () async {
      final prefs = await _emptyPrefs();
      final container = _containerOver(prefs);
      container.read(nightSettingsProvider.notifier).useKids();
      expect(container.read(nightSettingsProvider).isKids, isTrue);
      await pumpEventQueue();

      expect(_containerOver(prefs).read(nightSettingsProvider), NightSettings.kids);
    });

    test('a saved host picker stays host: only a night with no saved picker takes the director default', () async {
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode({..._validJson(), 'picker': NightPicker.host.name}),
      });
      final prefs = await SharedPreferences.getInstance();
      expect(_containerOver(prefs).read(nightSettingsProvider).picker, NightPicker.host);

      final withoutPicker = {..._validJson()}..remove('picker');
      SharedPreferences.setMockInitialValues({_key: jsonEncode(withoutPicker)});
      final older = await SharedPreferences.getInstance();
      expect(_containerOver(older).read(nightSettingsProvider).picker, NightPicker.director);
    });

    test('a broken saved string loads the defaults and is removed', () async {
      SharedPreferences.setMockInitialValues({_key: '{"length":'});
      final prefs = await SharedPreferences.getInstance();
      final container = _containerOver(prefs);
      expect(container.read(nightSettingsProvider), const NightSettings());
      await pumpEventQueue();
      expect(prefs.containsKey(_key), isFalse);
    });
  });
}
