import 'dart:convert';

import 'package:connection/connection.dart';
import 'package:controller/main.dart';
import 'package:controller/src/gyro.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final tv = HostAddress(addresses: ['192.168.1.50'], port: 45780, hostId: 'tv-1', name: 'Thumb Party TV (Android TV)');
final connected = ClientSnapshot(
  status: ClientStatus.connected,
  target: tv,
  hostName: 'Android TV',
  rttMs: 9,
  rttStats: const RttSummary(minMs: 5, avgMs: 22, maxMs: 130, samples: 30),
);

/// The app as a test sees it. Without a saved pairing it opens on the
/// Connect screen; with [paired] it stays on the controller.
class TestApp {
  TestApp(this.client, this.discovery, this.haptics, this.prefs, this.motion);

  final FakeClient client;
  final FakeDiscovery discovery;
  final FakeHaptics haptics;
  final SharedPreferences prefs;
  final FakeMotionSensors motion;
}

/// Mounts the app with every platform input faked. [stillSky] puts a
/// [party.ToyStillSky] above it, as every widget test that settles needs (the
/// sky drifts for as long as a menu is open); a test about the drift itself
/// passes false and settles by pumping instead.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  bool paired = false,
  bool isIOS = false,
  LogBuffer? log,
  FakeHaptics? haptics,
  FakeMotionSensors? motion,
  Map<String, Object> saved = const {},
  FakeDeviceStatus? device,
  bool tablet = false,
  Size screen = const Size(852, 393),
  FakeViewPadding padding = const FakeViewPadding(),
  void Function()? click,
  List<Override> extra = const [],
  bool stillSky = true,
  DateTime Function()? clock,
}) async {
  // A landscape phone (iPhone 15-ish) unless the test picks another screen.
  // [padding] is its safe area: a notch, the home indicator.
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({if (paired) 'lastHost': jsonEncode(tv.toJson()), ...saved});
  final prefs = await SharedPreferences.getInstance();
  final app = TestApp(
    FakeClient(savedTokens: paired ? {'tv-1': 'token'} : {}),
    FakeDiscovery(),
    haptics ?? FakeHaptics(),
    prefs,
    motion ?? FakeMotionSensors(),
  );
  await pumpFaked(
    tester,
    const ControllerApp(),
    app: app,
    isIOS: isIOS,
    tablet: tablet,
    log: log,
    device: device,
    click: click,
    extra: extra,
    stillSky: stillSky,
    clock: clock,
  );
  await settle(tester);
  return app;
}

/// Pumps a widget of its own with the app's providers faked as [pumpApp]
/// fakes them: for a test that gives a widget a child the app doesn't, such
/// as the game behind [ControlsLayer]. It doesn't settle. [stillSky] is
/// [pumpApp]'s, and [clock] is the device's clock Auto's palette reads.
Future<void> pumpFaked(
  WidgetTester tester,
  Widget child, {
  required TestApp app,
  bool isIOS = false,
  bool tablet = false,
  LogBuffer? log,
  FakeDeviceStatus? device,
  void Function()? click,
  List<Override> extra = const [],
  bool stillSky = true,
  DateTime Function()? clock,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(app.prefs),
      // The host layer's look settings are saved with this phone's other
      // settings, as the app's root scope does while it hosts (m13 §3a).
      party.lookPrefsProvider.overrideWith((ref) => ref.watch(prefsProvider)),
      // Auto's palette at midday, so no test turns Night after 19:00 (Claude's
      // 4a review: the TV's tests did). A test about the palette passes its
      // own clock, [clock], rather than overriding this one twice.
      party.lookClockProvider.overrideWithValue(clock ?? () => DateTime(2026, 11, 8, 12)),
      // The TV client: while this phone hosts, the screens use its own
      // player's client instead (m12 §3).
      tvClientProvider.overrideWithValue(app.client),
      discoveryProvider.overrideWithValue(app.discovery),
      hapticsProvider.overrideWithValue(app.haptics),
      motionSensorsProvider.overrideWithValue(app.motion),
      isIOSProvider.overrideWithValue(isIOS),
      isTabletProvider.overrideWithValue(tablet),
      clickSoundProvider.overrideWithValue(click ?? () {}),
      deviceStatusSourceProvider.overrideWithValue(device ?? FakeDeviceStatus()),
      if (log != null) logProvider.overrideWithValue(log),
      ...extra,
    ],
    child: stillSky ? party.ToyStillSky(child: child) : child,
  ),
);

/// pumpAndSettle never settles while a progress spinner turns, so pump
/// through page transitions instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A point [fraction] of the way across the widget behind [key].
Offset at(WidgetTester tester, Key key, Offset fraction) {
  final rect = tester.getRect(find.byKey(key));
  return rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy);
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await settle(tester);
}

Future<void> closeSettings(WidgetTester tester) async {
  await tester.pageBack();
  await settle(tester);
}

/// Scrolls the Settings (or Diagnostics) page until [finder] shows.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
