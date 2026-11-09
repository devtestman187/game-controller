import 'dart:convert';
import 'dart:io';

import 'package:controller/main.dart';
import 'package:controller/src/gyro.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/host_app.dart';
import 'support/pump_app.dart';

/// Every puzzle, read once for the file: hosting needs the picker's list, and
/// the read is real file work the test's clock never waits out (s9g).
late PuzzleLibrary _puzzles;

/// The app as `main()` mounts it (m13 §3a, M13 9 review): this phone's prefs,
/// the shaders it loaded, and the host layer's own providers
/// (host/host_overrides.dart). Only the platform is faked, as the harness fakes
/// it — no Look or sound provider is overridden here, which is what these tests
/// check.
Future<TestApp> pumpRealRoot(WidgetTester tester, {bool paired = false, Map<String, Object> saved = const {}}) async {
  tester.view.physicalSize = const Size(852, 393);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({if (paired) 'lastHost': jsonEncode(tv.toJson()), ...saved});
  final prefs = await SharedPreferences.getInstance();
  final app = TestApp(
    FakeClient(savedTokens: paired ? {'tv-1': 'token'} : {}),
    FakeDiscovery(),
    FakeHaptics(),
    prefs,
    FakeMotionSensors(),
  );
  final dir = Directory.systemTemp.createTempSync('thumb-party-prefs-');
  addTearDown(() => dir.deleteSync(recursive: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(app.prefs),
        party.toyShadersProvider.overrideWithValue(party.ToyShaders.none),
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        tvClientProvider.overrideWithValue(app.client),
        discoveryProvider.overrideWithValue(app.discovery),
        hapticsProvider.overrideWithValue(app.haptics),
        motionSensorsProvider.overrideWithValue(app.motion),
        isIOSProvider.overrideWithValue(false),
        isTabletProvider.overrideWithValue(false),
        clickSoundProvider.overrideWithValue(() {}),
        deviceStatusSourceProvider.overrideWithValue(FakeDeviceStatus()),
        party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
        party.puzzleLibraryProvider.overrideWith((ref) => _puzzles),
      ],
      child: const party.ToyStillSky(child: ControllerApp()),
    ),
  );
  await settle(tester);
  return app;
}

/// The app's one container.
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ControllerScreen).first));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _puzzles = await PuzzleLibrary.load();
  });

  testWidgets('joined, the real root reads and saves this phone\'s Look and sound', (tester) async {
    final app = await pumpRealRoot(tester, paired: true, saved: {'look.choice': 'night', 'sound.musicVolume': 30});
    expect(
      identical(_container(tester).read(party.lookPrefsProvider), app.prefs),
      isTrue,
      reason: 'the look and sound are kept in this phone\'s prefs, not the host\'s',
    );
    await openSettings(tester);
    final choice = tester.widget<SegmentedButton<party.LookChoice>>(find.byKey(const Key('lookChoice')));
    expect(choice.selected, {party.LookChoice.night}, reason: 'the Look saved on this phone is read');
    await tapVisible(
      tester,
      find.descendant(of: find.byKey(const Key('lookChoice')), matching: find.text(party.HostText.sunny)),
    );
    await settle(tester);
    expect(app.prefs.getString('look.choice'), 'sunny', reason: 'the choice is saved in this phone\'s prefs');

    await scrollTo(tester, find.byKey(const Key('musicVolume')));
    expect(
      tester.widget<Slider>(find.byKey(const Key('musicVolume'))).value,
      30,
      reason: 'the Music saved on this phone is read',
    );
    await tester.drag(find.byKey(const Key('musicVolume')), const Offset(80, 0));
    await settle(tester);
    expect(app.prefs.getInt('sound.musicVolume'), greaterThan(30), reason: 'the volume is saved in them too');
  });

  testWidgets('hosting, the real root reads and saves this phone\'s Look and sound', (tester) async {
    final app = await pumpRealRoot(tester, saved: {'sound.volume': 40});
    await enterHostMode(tester);
    final container = _container(tester);
    expect(
      identical(container.read(party.lookPrefsProvider), app.prefs),
      isTrue,
      reason: 'the host layer saves in this phone\'s prefs while it hosts (m13 §3a)',
    );
    expect(
      container.read(party.soundSettingsProvider).soundVolume,
      40,
      reason: 'the Sounds volume saved on this phone is read while hosting',
    );
    container.read(party.soundSettingsProvider.notifier).setMusicVolume(60);
    container.read(party.lookSettingsProvider.notifier).setChoice(party.LookChoice.night);
    await tester.pump();
    expect(app.prefs.getInt('sound.musicVolume'), 60);
    expect(app.prefs.getString('look.choice'), 'night');
    await tester.runAsync(hostOf(tester).dispose);
  });
}
